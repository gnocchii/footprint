import SwiftUI

enum AppCategory: String, CaseIterable {
    case productivity = "Productivity"
    case entertainment = "Entertainment"
    case social = "Social"
    case learning = "Learning"
    case communication = "Communication"
    case utilities = "Utilities"
    case other = "Other"
    case uncategorized = "Uncategorized"

    var color: Color {
        switch self {
        case .productivity: return .blue
        case .entertainment: return .purple
        case .social: return .pink
        case .learning: return .green
        case .communication: return .orange
        case .utilities: return .gray
        case .other: return .secondary
        case .uncategorized: return .secondary.opacity(0.5)
        }
    }

    var icon: String {
        switch self {
        case .productivity: return "hammer.fill"
        case .entertainment: return "play.circle.fill"
        case .social: return "person.2.fill"
        case .learning: return "book.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .utilities: return "gearshape.fill"
        case .other: return "square.grid.2x2.fill"
        case .uncategorized: return "questionmark.circle.fill"
        }
    }
}

enum TrackingConstants {
    static let windowPollInterval: TimeInterval = 3
    static let screenshotInterval: TimeInterval = 30
    static let summaryInterval: TimeInterval = 3600
    static let screenshotRetentionDays = 7
}
