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
            guard let self = self, !self.isIdle() else { return }
            self.poll()
        }
        poll()
    }

    private func isIdle() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        if let locked = session?["CGSSessionScreenIsLocked"] as? Bool, locked { return true }
        if let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.ignoredBundleIds.contains(frontApp) { return true }
        return false
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        finalizeLast()
    }

    // Apps to ignore — not real user activity
    private static let ignoredBundleIds: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.screensaver",
    ]

    private func poll() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier ?? "unknown"

        // Skip login window, screensaver, etc.
        guard !Self.ignoredBundleIds.contains(bundleId) else { return }

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

    // Bundle IDs for browsers — we extract more detail from these
    private static let browserBundleIds: Set<String> = [
        "com.brave.Browser",
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",  // Arc
    ]

    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success else { return nil }

        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &title)
        guard titleResult == .success, let titleString = title as? String else { return nil }

        // For browsers, also try to get the URL from the address bar
        let bundleId = app.bundleIdentifier ?? ""
        if Self.browserBundleIds.contains(bundleId) {
            if let url = getBrowserURL(appRef: appRef) {
                return "\(titleString) [\(url)]"
            }
        }

        return titleString
    }

    /// Attempt to read the URL from a browser's address bar via Accessibility
    private func getBrowserURL(appRef: AXUIElement) -> String? {
        // Try to find the address bar AXTextField / AXComboBox
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else { return nil }

        // Look for the toolbar group that contains the URL
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else { return nil }

        return findURLInChildren(childArray, depth: 0)
    }

    private func findURLInChildren(_ elements: [AXUIElement], depth: Int) -> String? {
        guard depth < 6 else { return nil } // Don't go too deep

        for element in elements {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            let roleStr = role as? String ?? ""

            // Address bars are typically AXTextField or AXComboBox
            if roleStr == "AXTextField" || roleStr == "AXComboBox" {
                var roleDesc: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDesc)

                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
                   let urlString = value as? String,
                   (urlString.contains(".") || urlString.contains("://")) {
                    // Clean up the URL for readability
                    return urlString
                        .replacingOccurrences(of: "https://", with: "")
                        .replacingOccurrences(of: "http://", with: "")
                        .replacingOccurrences(of: "www.", with: "")
                }
            }

            // Recurse into children
            var subChildren: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &subChildren) == .success,
               let subArray = subChildren as? [AXUIElement] {
                if let found = findURLInChildren(subArray, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }
}
