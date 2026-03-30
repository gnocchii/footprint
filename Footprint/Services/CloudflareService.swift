import Foundation

class CloudflareService {
    var baseURL: String {
        UserDefaults.standard.string(forKey: "cloudflare_base_url") ?? ""
    }

    var apiKey: String {
        UserDefaults.standard.string(forKey: "cloudflare_api_key") ?? ""
    }

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    // MARK: - Activity Ingestion

    func syncActivities(_ records: [ActivityRecord]) async throws {
        guard isConfigured else { return }

        let payload: [[String: Any]] = records.map { record in
            [
                "timestamp": ISO8601DateFormatter().string(from: record.timestamp),
                "appName": record.appName,
                "windowTitle": record.windowTitle,
                "bundleId": record.bundleIdentifier,
                "duration": record.duration ?? 0,
                "category": record.category ?? "Other"
            ]
        }

        let body: [String: Any] = ["records": payload]
        try await post(path: "/api/activity", body: body)
    }

    // MARK: - Screenshot / OCR Ingestion

    func syncScreenshot(timestamp: Date, ocrText: String) async throws {
        guard isConfigured else { return }

        let body: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "ocrText": ocrText
        ]
        try await post(path: "/api/screenshot", body: body)
    }

    // MARK: - Summaries

    struct SummaryResponse: Decodable {
        var date: String
        var summaries: [Summary]

        struct Summary: Decodable {
            var id: Int
            var date: String
            var hour: Int
            var summary: String
            var top_apps: [TopApp]
            var categories: [String: String]
        }

        struct TopApp: Decodable {
            var app: String
            var minutes: Int
        }
    }

    func fetchSummaries(date: String) async throws -> SummaryResponse {
        guard isConfigured else { throw CloudflareError.notConfigured }
        return try await get(path: "/api/summaries?date=\(date)")
    }

    // MARK: - Stats

    struct StatsResponse: Decodable {
        var date: String
        var appUsage: [AppUsageItem]
        var categoryUsage: [CategoryUsageItem]

        struct AppUsageItem: Decodable {
            var app_name: String
            var category: String
            var total_duration: Double
        }

        struct CategoryUsageItem: Decodable {
            var category: String
            var total_duration: Double
        }
    }

    func fetchStats(date: String) async throws -> StatsResponse {
        guard isConfigured else { throw CloudflareError.notConfigured }
        return try await get(path: "/api/stats?date=\(date)")
    }

    // MARK: - Chat

    struct ChatResponse: Decodable {
        var response: String
        var date: String
    }

    func sendChatMessage(_ message: String, date: String? = nil) async throws -> ChatResponse {
        guard isConfigured else { throw CloudflareError.notConfigured }

        var body: [String: Any] = ["message": message]
        if let date = date {
            body["date"] = date
        }
        return try await post(path: "/api/chat", body: body)
    }

    // MARK: - Trigger Summarization

    func triggerSummarize(date: String, hour: Int) async throws {
        guard isConfigured else { return }

        let body: [String: Any] = ["date": date, "hour": hour]
        let _: [String: Any] = try await post(path: "/api/summarize", body: body)
    }

    // MARK: - Networking Helpers

    @discardableResult
    private func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CloudflareError.apiError("HTTP \(statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    private func post(path: String, body: [String: Any]) async throws {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CloudflareError.apiError("HTTP \(statusCode)")
        }
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CloudflareError.apiError("HTTP \(statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    enum CloudflareError: LocalizedError {
        case notConfigured
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Cloudflare not configured. Add your Worker URL in Settings."
            case .apiError(let msg): return "Cloudflare API error: \(msg)"
            }
        }
    }
}
