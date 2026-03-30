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

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
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

    init() {
        self.databaseManager = DatabaseManager()
        self.windowTracker = WindowTracker(database: databaseManager)
        self.screenshotService = ScreenshotService(database: databaseManager)
        self.summaryEngine = SummaryEngine(database: databaseManager)

        startTracking()
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
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }
}
