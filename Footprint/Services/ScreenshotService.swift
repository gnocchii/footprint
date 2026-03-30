import Foundation
import ScreenCaptureKit
import AppKit

class ScreenshotService {
    private let database: DatabaseManager
    private let ocrService = OCRService()
    private var timer: Timer?

    private let captureInterval: TimeInterval = 30.0
    private let screenshotsDir: URL

    init(database: DatabaseManager) {
        self.database = database

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.screenshotsDir = appSupport
            .appendingPathComponent("Footprint", isDirectory: true)
            .appendingPathComponent("Screenshots", isDirectory: true)

        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            Task { await self?.capture() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func capture() async {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else { return }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width) / 2    // Half resolution to save space
            config.height = Int(display.height) / 2
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let filename = Self.filenameFormatter.string(from: Date()) + ".png"
            let filePath = screenshotsDir.appendingPathComponent(filename)

            // Convert CGImage to PNG data and save
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

            try pngData.write(to: filePath)

            // Insert screenshot record
            var screenshot = Screenshot(
                timestamp: Date(),
                filePath: filePath.path,
                ocrText: nil,
                processedByAI: false
            )
            try database.insertScreenshot(&screenshot)

            // Run OCR asynchronously
            if let screenshotId = screenshot.id {
                Task {
                    if let ocrText = ocrService.extractText(from: filePath) {
                        try? database.updateScreenshotOCR(id: screenshotId, ocrText: ocrText)
                    }
                }
            }
        } catch {
            print("Screenshot capture failed: \(error)")
        }
    }

    /// Clean up screenshots older than the retention period
    func cleanupOldScreenshots(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(at: screenshotsDir, includingPropertiesForKeys: [.creationDateKey]) else { return }

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let created = attrs.creationDate,
                  created < cutoff else { continue }
            try? fm.removeItem(at: file)
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()
}
