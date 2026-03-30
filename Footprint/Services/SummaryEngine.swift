import Foundation

class SummaryEngine {
    private let database: DatabaseManager
    private let cloudflare = CloudflareService()
    private var timer: Timer?

    private let summaryInterval: TimeInterval = 3600  // 1 hour

    init(database: DatabaseManager) {
        self.database = database
    }

    func start() {
        // Run summary for the previous hour on start
        Task { await summarizePreviousHour() }

        timer = Timer.scheduledTimer(withTimeInterval: summaryInterval, repeats: true) { [weak self] _ in
            Task { await self?.summarizePreviousHour() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func summarizePreviousHour() async {
        let now = Date()
        let calendar = Calendar.current
        let previousHour = calendar.component(.hour, from: calendar.date(byAdding: .hour, value: -1, to: now)!)
        let date = calendar.date(byAdding: .hour, value: -1, to: now)!
        let dateString = DatabaseManager.dateFormatter.string(from: date)

        // First sync any pending activities to Cloudflare
        await syncActivitiesToCloudflare(date: date, hour: previousHour)

        // Trigger Cloudflare workflow to summarize
        do {
            try await cloudflare.triggerSummarize(date: dateString, hour: previousHour)
            print("Cloudflare summarization triggered for \(dateString) hour \(previousHour)")
        } catch {
            print("Cloudflare summarization failed: \(error)")
        }
    }

    private func syncActivitiesToCloudflare(date: Date, hour: Int) async {
        do {
            let activities = try database.activitiesForHour(date: date, hour: hour)
            guard !activities.isEmpty else { return }
            try await cloudflare.syncActivities(activities)

            // Also sync OCR texts
            let screenshots = try database.unprocessedScreenshots(for: date, hour: hour)
            for screenshot in screenshots {
                if let ocrText = screenshot.ocrText, !ocrText.isEmpty {
                    try await cloudflare.syncScreenshot(timestamp: screenshot.timestamp, ocrText: ocrText)
                }
            }
        } catch {
            print("Activity sync to Cloudflare failed: \(error)")
        }
    }
}
