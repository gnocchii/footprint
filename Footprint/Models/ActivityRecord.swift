import Foundation
import GRDB

struct ActivityRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var timestamp: Date
    var appName: String
    var windowTitle: String
    var bundleIdentifier: String
    var duration: TimeInterval?
    var category: String?

    static let databaseTableName = "activity_records"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // MARK: - Browser helpers

    static let browserBundleIds: Set<String> = [
        "com.brave.Browser", "com.google.Chrome", "com.apple.Safari",
        "org.mozilla.firefox", "com.microsoft.edgemac", "company.thebrowser.Browser",
    ]

    var isBrowser: Bool {
        Self.browserBundleIds.contains(bundleIdentifier)
    }

    /// Rules-based category — uses app + window title to determine category
    var resolvedCategory: AppCategory {
        AppCategory.categorize(app: appName, bundleId: bundleIdentifier, windowTitle: windowTitle)
    }

    /// Clean display name — site name for browsers, app name otherwise
    var displayName: String {
        if isBrowser {
            return extractSiteName(from: windowTitle) ?? appName
        }
        return appName
    }

    /// Clean page title without URL brackets
    var pageTitle: String {
        var title = windowTitle
        if let b = title.range(of: " [", options: .backwards) {
            title = String(title[..<b.lowerBound])
        }
        // Remove trailing " - SiteName" for browsers
        if isBrowser {
            let parts = title.split(separator: " - ")
            if parts.count >= 2 {
                return parts.dropLast().joined(separator: " - ")
            }
        }
        return title
    }

    private func extractSiteName(from title: String) -> String? {
        if let br = title.range(of: "[", options: .backwards),
           let end = title.range(of: "]", options: .backwards) {
            let url = String(title[br.upperBound..<end.lowerBound])
            if let domain = url.split(separator: "/").first {
                return prettifyDomain(String(domain))
            }
        }
        let parts = title.split(separator: " - ")
        if parts.count >= 2, let last = parts.last {
            let s = String(last).trimmingCharacters(in: .whitespaces)
            if s.count < 35 { return s }
        }
        return nil
    }

    private func prettifyDomain(_ domain: String) -> String {
        let d = domain.lowercased()
        if d.contains("github") { return "GitHub" }
        if d.contains("youtube") { return "YouTube" }
        if d.contains("slack") { return "Slack" }
        if d.contains("outlook") || d.contains("office365") { return "Outlook" }
        if d.contains("gmail") || d.contains("mail.google") { return "Gmail" }
        if d.contains("9anime") { return "9anime" }
        if d.contains("instagram") { return "Instagram" }
        if d.contains("twitter") || d.contains("x.com") { return "Twitter/X" }
        if d.contains("reddit") { return "Reddit" }
        if d.contains("amazon") { return "Amazon" }
        if d.contains("discord") { return "Discord" }
        if d.contains("cloudflare") { return "Cloudflare" }
        if d.contains("stackoverflow") { return "Stack Overflow" }
        let parts = domain.split(separator: ".")
        if let first = parts.first { return String(first).capitalized }
        return domain
    }
}

// MARK: - Queries

extension ActivityRecord {
    struct AppUsage {
        var name: String
        var bundleIdentifier: String
        var totalDuration: TimeInterval
        var category: AppCategory
    }

    struct HourGroup {
        var hour: Int
        var summary: String       // Gemini-powered summary sentence
        var activities: [ActivityItem]
        var totalDuration: TimeInterval
    }

    struct ActivityItem {
        var name: String          // Smart label like "watching Cinderella Story" or "coding Footprint"
        var category: AppCategory
        var totalDuration: TimeInterval
    }

    /// Get all finalized records for a day
    static func recordsForDay(db: Database, date: Date) throws -> [ActivityRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try ActivityRecord
            .filter(Column("timestamp") >= startOfDay && Column("timestamp") < endOfDay)
            .filter(Column("bundleIdentifier") != "com.apple.loginwindow")
            .filter(Column("duration") != nil)
            .order(Column("timestamp"))
            .fetchAll(db)
    }

    /// Build app usage from raw records with rules-based categorization
    static func buildAppUsage(from records: [ActivityRecord]) -> [AppUsage] {
        var map: [String: (bundleId: String, duration: TimeInterval, category: AppCategory)] = [:]

        for r in records {
            guard let dur = r.duration, dur >= 1 else { continue }
            let name = r.displayName
            let cat = r.resolvedCategory
            if var existing = map[name] {
                existing.duration += dur
                map[name] = existing
            } else {
                map[name] = (r.bundleIdentifier, dur, cat)
            }
        }

        return map.map { AppUsage(name: $0.key, bundleIdentifier: $0.value.bundleId, totalDuration: $0.value.duration, category: $0.value.category) }
            .filter { $0.totalDuration >= 60 }  // >= 1 minute
            .sorted { $0.totalDuration > $1.totalDuration }
    }

    /// Build hourly activity groups from raw records
    static func buildHourGroups(from records: [ActivityRecord]) -> [HourGroup] {
        let calendar = Calendar.current
        var hourMap: [Int: [ActivityRecord]] = [:]

        for r in records {
            let hour = calendar.component(.hour, from: r.timestamp)
            hourMap[hour, default: []].append(r)
        }

        var result: [HourGroup] = []
        for (hour, hourRecords) in hourMap {
            var actMap: [String: (cat: AppCategory, dur: TimeInterval)] = [:]
            for r in hourRecords {
                guard let dur = r.duration, dur >= 1 else { continue }
                let name = r.displayName
                let cat = r.resolvedCategory
                if var existing = actMap[name] {
                    existing.dur += dur
                    actMap[name] = existing
                } else {
                    actMap[name] = (cat, dur)
                }
            }

            var activities: [ActivityItem] = []
            for (name, val) in actMap {
                if val.dur >= 30 {
                    activities.append(ActivityItem(name: name, category: val.cat, totalDuration: val.dur))
                }
            }
            activities.sort { $0.totalDuration > $1.totalDuration }

            if !activities.isEmpty {
                let total = activities.reduce(0.0) { $0 + $1.totalDuration }
                result.append(HourGroup(hour: hour, summary: "", activities: activities, totalDuration: total))
            }
        }
        result.sort { $0.hour > $1.hour }
        return result
    }

    /// Build category groups using Gemini descriptions as labels where available
    static func buildCategoryGroups(
        from records: [ActivityRecord],
        geminiDescriptions: [(timestamp: Date, description: String)] = []
    ) -> [CatGroup] {
        // Build a lookup: for any timestamp, find the nearest Gemini description
        let sortedDescs = geminiDescriptions.sorted { $0.timestamp < $1.timestamp }

        func nearestGemini(for date: Date) -> String? {
            var best: (desc: String, distance: TimeInterval)?
            for gd in sortedDescs {
                let dist = abs(gd.timestamp.timeIntervalSince(date))
                if dist < 150 { // within 2.5 min
                    if best == nil || dist < best!.distance {
                        best = (gd.description, dist)
                    }
                }
            }
            return best?.desc
        }

        // category → label → duration
        var catMap: [AppCategory: [String: TimeInterval]] = [:]

        for r in records {
            guard let dur = r.duration, dur >= 1 else { continue }
            let cat = r.resolvedCategory

            // Use Gemini description if available, otherwise clean fallback
            let label: String
            if let gemini = nearestGemini(for: r.timestamp) {
                label = gemini
            } else {
                // Simple, clean fallback — just the app/site name, not raw page titles
                label = r.displayName
            }

            catMap[cat, default: [:]][label, default: 0] += dur
        }

        var result: [CatGroup] = []
        for (cat, items) in catMap {
            var entries: [CatSub] = []
            for (label, dur) in items {
                let mins = Int(dur / 60)
                if dur >= 60 {
                    entries.append(CatSub(
                        name: label,
                        entries: [CatEntry(label: label, minutes: mins)],
                        totalSeconds: dur
                    ))
                }
            }
            entries.sort { $0.totalSeconds > $1.totalSeconds }

            var totalSecs: TimeInterval = 0
            for e in entries { totalSecs += e.totalSeconds }
            if totalSecs >= 60 {
                result.append(CatGroup(name: cat.rawValue, subcategories: entries, totalSeconds: totalSecs, appCategory: cat))
            }
        }
        result.sort { $0.totalSeconds > $1.totalSeconds }
        return result
    }
}
