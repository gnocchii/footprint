import Foundation

class SummaryEngine {
    private let database: DatabaseManager
    private var timer: Timer?

    init(database: DatabaseManager) {
        self.database = database
    }

    func start() {
        // Generate summaries for recent unsummarized hours on launch
        Task { await summarizeRecentHours() }

        // Run every hour
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { await self?.summarizePreviousHour() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Summarize the previous hour
    func summarizePreviousHour() async {
        let now = Date()
        let calendar = Calendar.current
        let prevDate = calendar.date(byAdding: .hour, value: -1, to: now)!
        let hour = calendar.component(.hour, from: prevDate)
        await generateSummary(date: prevDate, hour: hour)
    }

    /// On launch, check last 6 hours for missing summaries
    private func summarizeRecentHours() async {
        let now = Date()
        let calendar = Calendar.current

        for hoursAgo in 1...6 {
            guard let date = calendar.date(byAdding: .hour, value: -hoursAgo, to: now) else { continue }
            let hour = calendar.component(.hour, from: date)

            do {
                guard !(try database.hasSummary(date: date, hour: hour)) else { continue }
                let activities = try database.activitiesForHour(date: date, hour: hour)
                guard !activities.isEmpty else { continue }
                await generateSummary(date: date, hour: hour)
            } catch {}
        }
    }

    private func generateSummary(date: Date, hour: Int) async {
        do {
            guard !(try database.hasSummary(date: date, hour: hour)) else { return }

            let activities = try database.activitiesForHour(date: date, hour: hour)
            guard !activities.isEmpty else { return }

            // Build activity log text
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"

            let activityLog = activities.compactMap { record -> String? in
                guard let dur = record.duration, dur >= 1 else { return nil }
                let time = formatter.string(from: record.timestamp)
                let mins = Int(dur / 60)
                let name = record.displayName
                return "\(time) - \(name) (\(record.windowTitle)) \(mins)m"
            }.joined(separator: "\n")

            // Get Gemini descriptions from this hour
            let screenshots = try database.unprocessedScreenshots(for: date, hour: hour)
            let geminiDescs = screenshots
                .compactMap { $0.ocrText }
                .filter { $0.hasPrefix("[GEMINI]") }
                .map { String($0.dropFirst(9)) }
                .joined(separator: "\n")

            // Build top apps string
            var appDurations: [String: TimeInterval] = [:]
            for a in activities {
                let dur: TimeInterval = a.duration ?? 0
                appDurations[a.displayName, default: 0] += dur
            }
            let sorted = appDurations.sorted { $0.value > $1.value }
            var topParts: [String] = []
            for item in sorted.prefix(5) {
                topParts.append("\(item.key) (\(Int(item.value / 60))m)")
            }
            let topApps = topParts.joined(separator: ", ")

            let summary: String
            if !geminiDescs.isEmpty {
                summary = "Used: \(topApps). Context: \(geminiDescs.prefix(500))"
            } else {
                summary = topApps
            }

            var hourlySummary = HourlySummary(
                date: DatabaseManager.dateFormatter.string(from: date),
                hour: hour,
                summary: summary,
                topApps: "[]",
                categories: "{}",
                createdAt: Date()
            )
            try database.insertSummary(&hourlySummary)
            print("Summary generated for hour \(hour): \(summary.prefix(100))")
        } catch {
            print("Summary generation failed: \(error)")
        }
    }
}
