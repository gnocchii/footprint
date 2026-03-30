import Foundation
import GRDB

class DatabaseManager {
    let dbPool: DatabasePool

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Footprint", isDirectory: true)
        try! FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let dbPath = appDir.appendingPathComponent("footprint.sqlite").path
        dbPool = try! DatabasePool(path: dbPath)

        try! migrator.migrate(dbPool)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "activity_records") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("appName", .text).notNull()
                t.column("windowTitle", .text).notNull()
                t.column("bundleIdentifier", .text).notNull()
                t.column("duration", .double)
                t.column("category", .text)
            }

            try db.create(table: "screenshots") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("filePath", .text).notNull()
                t.column("ocrText", .text)
                t.column("processedByAI", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "hourly_summaries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("hour", .integer).notNull()
                t.column("summary", .text).notNull()
                t.column("topApps", .text).notNull()
                t.column("categories", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        return migrator
    }

    // MARK: - Activity Records

    func insertActivity(_ record: inout ActivityRecord) throws {
        try dbPool.write { db in
            try record.insert(db)
        }
    }

    func activitiesForHour(date: Date, hour: Int) throws -> [ActivityRecord] {
        try dbPool.read { db in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let startOfHour = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour)!

            return try ActivityRecord
                .filter(Column("timestamp") >= startOfHour && Column("timestamp") < endOfHour)
                .order(Column("timestamp"))
                .fetchAll(db)
        }
    }

    func dailyAppUsage(for date: Date) throws -> [ActivityRecord.AppUsage] {
        try dbPool.read { db in
            try ActivityRecord.dailyAppUsage(db: db, date: date)
        }
    }

    func dailyCategoryUsage(for date: Date) throws -> [ActivityRecord.CategoryUsage] {
        try dbPool.read { db in
            try ActivityRecord.dailyCategoryUsage(db: db, date: date)
        }
    }

    func updateCategories(for ids: [Int64], category: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE activity_records SET category = ? WHERE id IN (\(ids.map { "\($0)" }.joined(separator: ",")))",
                arguments: [category]
            )
        }
    }

    // MARK: - Screenshots

    func insertScreenshot(_ screenshot: inout Screenshot) throws {
        try dbPool.write { db in
            try screenshot.insert(db)
        }
    }

    func updateScreenshotOCR(id: Int64, ocrText: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE screenshots SET ocrText = ? WHERE id = ?",
                arguments: [ocrText, id]
            )
        }
    }

    func unprocessedScreenshots(for date: Date, hour: Int) throws -> [Screenshot] {
        try dbPool.read { db in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let startOfHour = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour)!

            return try Screenshot
                .filter(Column("timestamp") >= startOfHour && Column("timestamp") < endOfHour)
                .filter(Column("processedByAI") == false)
                .fetchAll(db)
        }
    }

    func markScreenshotsProcessed(ids: [Int64]) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE screenshots SET processedByAI = 1 WHERE id IN (\(ids.map { "\($0)" }.joined(separator: ",")))"
            )
        }
    }

    // MARK: - Hourly Summaries

    func insertSummary(_ summary: inout HourlySummary) throws {
        try dbPool.write { db in
            try summary.insert(db)
        }
    }

    func summariesForDay(date: Date) throws -> [HourlySummary] {
        let dateString = Self.dateFormatter.string(from: date)
        return try dbPool.read { db in
            try HourlySummary
                .filter(Column("date") == dateString)
                .order(Column("hour"))
                .fetchAll(db)
        }
    }

    func hasSummary(date: Date, hour: Int) throws -> Bool {
        let dateString = Self.dateFormatter.string(from: date)
        return try dbPool.read { db in
            try HourlySummary
                .filter(Column("date") == dateString && Column("hour") == hour)
                .fetchCount(db) > 0
        }
    }

    // MARK: - Observation (for live UI updates)

    func observeDailyAppUsage(date: Date, onChange: @escaping ([ActivityRecord.AppUsage]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try ActivityRecord.dailyAppUsage(db: db, date: date)
        }
        return observation.start(in: dbPool, onError: { _ in }, onChange: onChange)
    }

    func observeDailySummaries(date: Date, onChange: @escaping ([HourlySummary]) -> Void) -> AnyDatabaseCancellable {
        let dateString = Self.dateFormatter.string(from: date)
        let observation = ValueObservation.tracking { db in
            try HourlySummary
                .filter(Column("date") == dateString)
                .order(Column("hour"))
                .fetchAll(db)
        }
        return observation.start(in: dbPool, onError: { _ in }, onChange: onChange)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
