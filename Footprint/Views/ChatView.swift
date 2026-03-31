import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        let content: String
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            Divider()
            inputBar
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Ask about your activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                suggestionButton("What did I do today?")
                suggestionButton("How productive was I this week?")
                suggestionButton("Which app did I use most?")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func suggestionButton(_ text: String) -> some View {
        Button(action: { sendMessage(text) }) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .id("loading")
                    }
                }
                .padding(12)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your activity...", text: $inputText)
                .textFieldStyle(.plain)
                .onSubmit { sendMessage(inputText) }

            Button(action: { sendMessage(inputText) }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: "user", content: trimmed, timestamp: Date())
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        // Grab data on main thread, then do async work
        let records = (try? appState.databaseManager.dbPool.read { dbConn in
            try ActivityRecord.recordsForDay(db: dbConn, date: Date())
        }) ?? []
        let geminiDescs = (try? appState.databaseManager.geminiDescriptions(for: Date())) ?? []
        let summaries = (try? appState.databaseManager.activitySummaries(for: Date())) ?? []
        let gemini = appState.screenshotService.geminiService

        Task {

            // Build context string
            var context = ""

            if !summaries.isEmpty {
                context += "Activity summaries:\n"
                for s in summaries {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "h:mm a"
                    context += "- \(fmt.string(from: s.timestamp)): \(s.summary)\n"
                }
                context += "\n"
            }

            if !geminiDescs.isEmpty {
                context += "Screen observations:\n"
                for g in geminiDescs.suffix(15) {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "h:mm a"
                    context += "- \(fmt.string(from: g.timestamp)): \(g.description)\n"
                }
                context += "\n"
            }

            // App usage summary
            let usage = ActivityRecord.buildAppUsage(from: records)
            if !usage.isEmpty {
                context += "App usage today:\n"
                for u in usage.prefix(10) {
                    let mins = Int(u.totalDuration / 60)
                    context += "- \(u.name): \(mins)m (\(u.category.rawValue))\n"
                }
            }

            let history = messages.map { (role: $0.role, content: $0.content) }

            let response = await gemini.chat(
                question: trimmed,
                activityContext: context,
                chatHistory: history
            )

            await MainActor.run {
                let content = response ?? "Sorry, couldn't get a response right now."
                messages.append(ChatMessage(role: "assistant", content: content, timestamp: Date()))
                isLoading = false
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatView.ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(message.content)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.blue : Color(.controlBackgroundColor))
                .foregroundStyle(isUser ? .white : .primary)
                .cornerRadius(16)

            if !isUser { Spacer(minLength: 40) }
        }
    }
}
