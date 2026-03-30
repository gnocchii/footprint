import Foundation
import GRDB

struct Screenshot: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var timestamp: Date
    var filePath: String
    var ocrText: String?
    var processedByAI: Bool

    static let databaseTableName = "screenshots"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let timestamp = Column(CodingKeys.timestamp)
        static let processedByAI = Column(CodingKeys.processedByAI)
    }
}
