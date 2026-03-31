import AppKit
import Foundation

class GeminiService {
    private let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    private let model = "gemini-2.5-flash"
    private let maxCallsPerDay = 720
    private let minInterval: TimeInterval = 60

    private var callCount = 0
    private var lastCallTime: Date = .distantPast
    private var dayStart: Date = Calendar.current.startOfDay(for: Date())
    private var recentDescriptions: [String] = []  // rolling context
    private let maxRecentDescriptions = 3

    struct ScreenContext {
        var focusedApp: String
        var focusedBundleId: String
        var recentActivity: String   // last 5 min of app switches
    }

    /// Analyze a batch of screenshots (taken over ~2 min) with window context
    func analyzeScreenshots(imageDataList: [Data], context: ScreenContext) async -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        if today != dayStart { callCount = 0; dayStart = today }
        guard callCount < maxCallsPerDay else { return nil }
        guard Date().timeIntervalSince(lastCallTime) >= minInterval else { return nil }

        let contextHistory = recentDescriptions.isEmpty ? "none" : recentDescriptions.joined(separator: " → ")

        let prompt = """
You are a screen time tracker. You see \(imageDataList.count) screenshots taken 30s apart.

FOCUSED APP: \(context.focusedApp)
APP SWITCHES (last 5 min):
\(context.recentActivity)
CONTEXT FROM PREVIOUS ANALYSES: \(contextHistory)

Your job: describe what the user is ACTIVELY doing in under 15 words.

FORMAT:
- Single activity: "watching Yuri on Ice"
- Multitasking (media on one side + work on other): "doing CS240 homework while watching Bojack Horseman"
- If you can identify a course/project name from the screen (e.g., CS240, STAT512, ECON251, Footprint), USE IT
- Never say app names like "Brave Browser" or "kitty" — say what they're DOING: "coding Footprint", "watching lecture", "browsing Reddit"
- If media is paused or a page is idle, don't count it as active
- Build on previous context: if earlier you saw C code and now you see Brightspace with "CS240", connect them → "doing CS240 homework"
- If nothing changed since previous analysis, reply "same"
"""

        // Build parts array: all images + the prompt text
        var parts: [[String: Any]] = []
        for imageData in imageDataList {
            let base64 = imageData.base64EncodedString()
            parts.append(["inlineData": ["mimeType": "image/png", "data": base64]])
        }
        parts.append(["text": prompt])

        let body: [String: Any] = [
            "contents": [["parts": parts]]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // Longer timeout for multi-image

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            lastCallTime = Date()
            callCount += 1

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else { return nil }
            if http.statusCode == 429 { print("Gemini: rate limited"); return nil }
            guard http.statusCode == 200 else { print("Gemini: HTTP \(http.statusCode)"); return nil }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let responseParts = content?["parts"] as? [[String: Any]]
            let text = responseParts?.first?["text"] as? String

            guard let desc = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  desc.lowercased() != "same" else {
                return nil
            }

            recentDescriptions.append(desc)
            if recentDescriptions.count > maxRecentDescriptions {
                recentDescriptions.removeFirst()
            }
            return desc
        } catch {
            print("Gemini batch error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Chat — answer a question about the user's activity
    func chat(question: String, activityContext: String, chatHistory: [(role: String, content: String)]) async -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        if today != dayStart { callCount = 0; dayStart = today }
        guard callCount < maxCallsPerDay else { return nil }
        guard Date().timeIntervalSince(lastCallTime) >= minInterval else { return nil }

        var parts: [[String: Any]] = []

        // Build conversation
        let systemPrompt = """
You are Footprint, an AI that knows everything about the user's computer activity. Answer their questions using the data below. Be concise, specific, and friendly. Reference actual apps, sites, shows, projects, and times.

TODAY'S ACTIVITY DATA:
\(activityContext)
"""
        parts.append(["text": systemPrompt])

        for msg in chatHistory.suffix(10) {
            parts.append(["text": "\(msg.role == "user" ? "User" : "Footprint"): \(msg.content)"])
        }
        parts.append(["text": "User: \(question)"])
        parts.append(["text": "Footprint:"])

        let body: [String: Any] = [
            "contents": [["parts": parts]]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            lastCallTime = Date()
            callCount += 1

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let responseParts = content?["parts"] as? [[String: Any]]
            let text = responseParts?.first?["text"] as? String
            return text?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Summarize a block of recent activity descriptions into one sentence
    func summarizeBlock(descriptions: [String], windowSwitches: String, force: Bool = false) async -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        if today != dayStart { callCount = 0; dayStart = today }
        guard callCount < maxCallsPerDay else { return nil }
        if !force {
            guard Date().timeIntervalSince(lastCallTime) >= minInterval else { return nil }
        }

        let descText = descriptions.joined(separator: "\n")

        let prompt = """
Summarize what the user did in the last 10 minutes in ONE natural sentence.

Screen observations (every 2 min):
\(descText)

App switches:
\(windowSwitches)

Rules:
- Write like: "Coded Footprint for 8 minutes, briefly checked Messages with Ryan"
- Or: "Watched Bojack Horseman while occasionally checking Slack"
- Mention specific content: show names, project names, course numbers, people
- Don't mention time switching or app names — describe ACTIVITIES
- Keep it to 1 sentence, max 25 words
"""

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            lastCallTime = Date()
            callCount += 1

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            let text = parts?.first?["text"] as? String
            return text?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
