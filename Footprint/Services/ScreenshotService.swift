import Foundation
import ScreenCaptureKit
import AppKit

class ScreenshotService {
    private let database: DatabaseManager
    private let ocrService = OCRService()
    let geminiService = GeminiService()
    private var captureTimer: Timer?
    private var geminiTimer: Timer?
    private var summaryTimer: Timer?

    private let captureInterval: TimeInterval = 20.0    // Capture every 20s
    private let geminiInterval: TimeInterval = 120.0   // Gemini vision every 2 min
    private let summaryInterval: TimeInterval = 600.0  // Summarize block every 10 min
    private let screenshotsDir: URL

    // Buffer of recent captures for batching to Gemini
    private var recentCaptures: [(timestamp: Date, data: Data)] = []
    private let maxBuffered = 6

    // Buffer of recent Gemini descriptions for 10-min summary
    private var pendingDescriptions: [String] = []

    init(database: DatabaseManager) {
        self.database = database

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.screenshotsDir = appSupport
            .appendingPathComponent("Footprint", isDirectory: true)
            .appendingPathComponent("Screenshots", isDirectory: true)

        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
    }

    func start() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            guard let self = self, !self.isIdle() else { return }
            Task { await self.capture() }
        }

        geminiTimer = Timer.scheduledTimer(withTimeInterval: geminiInterval, repeats: true) { [weak self] _ in
            guard let self = self, !self.isIdle() else { return }
            Task { await self.analyzeBatch() }
        }

        // Summarize every 10 min
        summaryTimer = Timer.scheduledTimer(withTimeInterval: summaryInterval, repeats: true) { [weak self] _ in
            guard let self = self, !self.isIdle() else { return }
            Task { await self.summarizeBlock() }
        }
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        geminiTimer?.invalidate()
        geminiTimer = nil
        summaryTimer?.invalidate()
        summaryTimer = nil
    }

    private func isIdle() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        if let locked = session?["CGSSessionScreenIsLocked"] as? Bool, locked { return true }
        if let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           frontApp == "com.apple.screensaver" || frontApp == "com.apple.loginwindow" { return true }
        return false
    }

    /// Capture screenshot, run OCR, and buffer for Gemini
    private func capture() async {
        guard let (filePath, imageData) = await captureScreen() else { return }

        // Store screenshot + OCR
        var screenshot = Screenshot(
            timestamp: Date(),
            filePath: filePath.path,
            ocrText: nil,
            processedByAI: false
        )
        try? database.insertScreenshot(&screenshot)

        if let screenshotId = screenshot.id {
            Task {
                if let ocrText = ocrService.extractText(from: filePath) {
                    try? database.updateScreenshotOCR(id: screenshotId, ocrText: ocrText)
                }
            }
        }

        // Buffer for Gemini batch
        recentCaptures.append((timestamp: Date(), data: imageData))
        if recentCaptures.count > maxBuffered {
            recentCaptures.removeFirst(recentCaptures.count - maxBuffered)
        }

        // Clean up file — we have the data in memory for Gemini
        try? FileManager.default.removeItem(at: filePath)
    }

    /// Send batched screenshots to Gemini (every 2 min)
    private func analyzeBatch() async {
        guard !recentCaptures.isEmpty else { return }

        let batch = recentCaptures
        recentCaptures.removeAll()

        // Get context
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "Unknown"
        let bundleId = frontApp?.bundleIdentifier ?? ""
        let recentActivity = (try? database.recentActivitySummary(minutes: 5)) ?? ""

        let context = GeminiService.ScreenContext(
            focusedApp: appName,
            focusedBundleId: bundleId,
            recentActivity: recentActivity
        )

        // Send all screenshots in one call
        let imageDataList = batch.map { $0.data }

        if let description = await geminiService.analyzeScreenshots(imageDataList: imageDataList, context: context) {
            print("Gemini (\(batch.count) frames): \(description)")

            // Store raw description
            var screenshot = Screenshot(
                timestamp: Date(),
                filePath: "",
                ocrText: "[GEMINI] \(description)",
                processedByAI: true
            )
            try? database.insertScreenshot(&screenshot)

            // Buffer for 10-min summary
            pendingDescriptions.append(description)
        }
    }

    /// Every 10 min: summarize pending descriptions into one clean sentence
    private func summarizeBlock() async {
        guard !pendingDescriptions.isEmpty else { return }

        let descs = pendingDescriptions
        pendingDescriptions.removeAll()

        let recentActivity = (try? database.recentActivitySummary(minutes: 10)) ?? ""

        if let summary = await geminiService.summarizeBlock(descriptions: descs, windowSwitches: recentActivity) {
            print("Summary: \(summary)")

            // Store as a [SUMMARY] entry
            var screenshot = Screenshot(
                timestamp: Date(),
                filePath: "",
                ocrText: "[SUMMARY] \(summary)",
                processedByAI: true
            )
            try? database.insertScreenshot(&screenshot)
        }
    }

    private func captureScreen() async -> (URL, Data)? {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else { return nil }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width) / 3
            config.height = Int(display.height) / 3
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let filename = Self.filenameFormatter.string(from: Date()) + ".png"
            let filePath = screenshotsDir.appendingPathComponent(filename)

            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }

            try pngData.write(to: filePath)
            return (filePath, pngData)
        } catch {
            return nil
        }
    }

    func cleanupOldScreenshots(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: screenshotsDir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let created = attrs.creationDate, created < cutoff else { continue }
            try? fm.removeItem(at: file)
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()
}
