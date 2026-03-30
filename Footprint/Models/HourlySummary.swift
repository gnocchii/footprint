import Foundation
import GRDB

struct HourlySummary: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var date: String          // "2026-03-15"
    var hour: Int             // 0-23
    var summary: String
    var topApps: String       // JSON array
    var categories: String    // JSON dict
    var createdAt: Date

    static let databaseTableName = "hourly_summaries"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // Decoded helpers
    struct AppMinutes: Codable {
        var app: String
        var minutes: Int
    }

    var decodedTopApps: [AppMinutes] {
        guard let data = topApps.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AppMinutes].self, from: data)) ?? []
    }

    var decodedCategories: [String: Int] {
        guard let data = categories.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }
}
