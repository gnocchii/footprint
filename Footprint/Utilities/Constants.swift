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

    /// Rules-based categorization from app name + window title
    static func categorize(app: String, bundleId: String, windowTitle: String) -> AppCategory {
        let a = app.lowercased()
        let t = windowTitle.lowercased()
        let b = bundleId.lowercased()

        // Communication
        if a.contains("message") || a.contains("facetime") || a.contains("zoom")
            || a.contains("teams") || b.contains("zoom.us") { return .communication }
        if t.contains("outlook") || t.contains("gmail") || t.contains("mail") { return .communication }
        if a.contains("mail") { return .communication }
        if t.contains("slack") { return .communication }

        // Social
        if a.contains("discord") { return .social }
        if a.contains("find my") { return .social }
        if t.contains("instagram") || t.contains("twitter") || t.contains("x.com")
            || t.contains("reddit") || t.contains("tiktok") || t.contains("facebook") { return .social }

        // Entertainment
        if a.contains("music") || a.contains("spotify") || a.contains("podcasts") { return .entertainment }
        if t.contains("youtube") || t.contains("netflix") || t.contains("hulu")
            || t.contains("9anime") || t.contains("crunchyroll") || t.contains("twitch")
            || t.contains("anime") || t.contains("disneyplus") || t.contains("hbomax") { return .entertainment }

        // Learning
        if t.contains("coursera") || t.contains("khan academy") || t.contains("edx")
            || t.contains("iclicker") || t.contains("brightspace") || t.contains("canvas")
            || t.contains("piazza") || t.contains("gradescope") || t.contains("chegg") { return .learning }

        // Productivity
        if a.contains("xcode") || a.contains("windsurf") || a.contains("cursor")
            || a.contains("code") { return .productivity }
        if a.contains("terminal") || a.contains("iterm") || a.contains("kitty")
            || a.contains("warp") { return .productivity }
        if t.contains("github") || t.contains("gitlab") || t.contains("stackoverflow")
            || t.contains("stack overflow") { return .productivity }
        if a.contains("notion") || a.contains("obsidian") || a.contains("bear") { return .productivity }
        if t.contains("figma") || t.contains("sketch") { return .productivity }
        if t.contains("cloudflare") || t.contains("vercel") || t.contains("netlify")
            || t.contains("aws") || t.contains("azure") { return .productivity }
        if t.contains("docs.google") || t.contains("sheets.google") || t.contains("slides.google") { return .productivity }
        if t.contains("linear") || t.contains("jira") || t.contains("asana") { return .productivity }
        if t.contains("duo security") || t.contains("okta") { return .productivity }

        // Utilities
        if a.contains("finder") || a.contains("system") || a.contains("activity monitor")
            || a.contains("preview") || a.contains("calculator") { return .utilities }

        // Browsers with no specific match — check if it looks like shopping etc
        if t.contains("amazon") || t.contains("ebay") || t.contains("shopping") { return .other }

        return .uncategorized
    }
}

enum TrackingConstants {
    static let windowPollInterval: TimeInterval = 3
    static let screenshotInterval: TimeInterval = 30
    static let summaryInterval: TimeInterval = 3600
    static let screenshotRetentionDays = 7
}

enum CloudflareConstants {
    static let baseURL = "https://cf-ai-footprint.meoies.workers.dev"
    static let apiKey = ""
}
