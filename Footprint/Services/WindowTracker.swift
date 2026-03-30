import AppKit
import Foundation

class WindowTracker {
    private let database: DatabaseManager
    private var timer: Timer?
    private var lastRecord: (bundleId: String, title: String, timestamp: Date)?

    private let pollInterval: TimeInterval = 3.0

    init(database: DatabaseManager) {
        self.database = database
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Fire immediately
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        finalizeLast()
    }

    private func poll() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier ?? "unknown"
        let windowTitle = getWindowTitle(for: frontApp) ?? appName
        let now = Date()

        // Finalize previous record's duration if the app/window changed
        if let last = lastRecord, last.bundleId != bundleId || last.title != windowTitle {
            finalizeLast()
        }

        // If this is a new window focus, insert a new record
        if lastRecord == nil || lastRecord!.bundleId != bundleId || lastRecord!.title != windowTitle {
            var record = ActivityRecord(
                timestamp: now,
                appName: appName,
                windowTitle: windowTitle,
                bundleIdentifier: bundleId,
                duration: nil,
                category: nil
            )
            try? database.insertActivity(&record)
            lastRecord = (bundleId: bundleId, title: windowTitle, timestamp: now)
        }
    }

    private func finalizeLast() {
        guard let last = lastRecord else { return }
        let duration = Date().timeIntervalSince(last.timestamp)
        // Update the last record's duration in the database
        try? database.dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE activity_records SET duration = ?
                    WHERE timestamp = ? AND bundleIdentifier = ? AND duration IS NULL
                    ORDER BY id DESC LIMIT 1
                    """,
                arguments: [duration, last.timestamp, last.bundleId]
            )
        }
        lastRecord = nil
    }

    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success else { return nil }

        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success, let titleString = title as? String else { return nil }

        return titleString
    }
}
