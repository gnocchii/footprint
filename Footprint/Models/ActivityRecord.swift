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
}

extension ActivityRecord {
    /// Aggregate app usage for a given day
    struct AppUsage: Decodable, FetchableRecord {
        var appName: String
        var bundleIdentifier: String
        var totalDuration: TimeInterval
        var category: String?
    }

    static func dailyAppUsage(db: Database, date: Date) throws -> [AppUsage] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try AppUsage.fetchAll(db, sql: """
            SELECT appName, bundleIdentifier, category,
                   COALESCE(SUM(duration), 0) as totalDuration
            FROM activity_records
            WHERE timestamp >= ? AND timestamp < ?
            GROUP BY bundleIdentifier
            ORDER BY totalDuration DESC
            """, arguments: [startOfDay, endOfDay])
    }

    /// Category breakdown for a given day
    struct CategoryUsage: Decodable, FetchableRecord {
        var category: String
        var totalDuration: TimeInterval
    }

    static func dailyCategoryUsage(db: Database, date: Date) throws -> [CategoryUsage] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try CategoryUsage.fetchAll(db, sql: """
            SELECT COALESCE(category, 'Uncategorized') as category,
                   COALESCE(SUM(duration), 0) as totalDuration
            FROM activity_records
            WHERE timestamp >= ? AND timestamp < ?
            GROUP BY category
            ORDER BY totalDuration DESC
            """, arguments: [startOfDay, endOfDay])
    }
}
