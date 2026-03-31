import SwiftUI

@main
struct FootprintApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Footprint", systemImage: "shoeprints.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
class AppState: ObservableObject {
    let databaseManager: DatabaseManager
    let windowTracker: WindowTracker
    let screenshotService: ScreenshotService
    let summaryEngine: SummaryEngine
    let cloudflareService = CloudflareService()

    @Published var isTracking = true
    @Published var issues: [String] = []

    init() {
        self.databaseManager = DatabaseManager()
        self.windowTracker = WindowTracker(database: databaseManager)
        self.screenshotService = ScreenshotService(database: databaseManager)
        self.summaryEngine = SummaryEngine(database: databaseManager)

        startTracking()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkHealth()
        }
    }

    func startTracking() {
        windowTracker.start()
        screenshotService.start()
        summaryEngine.start()
        isTracking = true
    }

    func stopTracking() {
        windowTracker.stop()
        screenshotService.stop()
        summaryEngine.stop()
        isTracking = false
    }

    func toggleTracking() {
        if isTracking { stopTracking() } else { startTracking() }
    }

    func refreshNow() async {
        // Trigger a summary from whatever Gemini descriptions we have
        let descs = (try? databaseManager.geminiDescriptions(for: Date())) ?? []
        let recentDescs = descs.suffix(5).map { $0.description }
        guard !recentDescs.isEmpty else { return }

        let recentActivity = (try? databaseManager.recentActivitySummary(minutes: 10)) ?? ""

        if let summary = await screenshotService.geminiService.summarizeBlock(
            descriptions: recentDescs,
            windowSwitches: recentActivity,
            force: true
        ) {
            var screenshot = Screenshot(
                timestamp: Date(),
                filePath: "",
                ocrText: "[SUMMARY] \(summary)",
                processedByAI: true
            )
            try? databaseManager.insertScreenshot(&screenshot)
            print("Manual refresh: \(summary)")
        }
    }

    func checkHealth() {
        // Don't nag about permissions — user handles it in System Settings
        issues = []
    }
}
