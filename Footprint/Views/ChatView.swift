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
                    .foregroundStyle(inputText.isEmpty ? .secondary : .blue)
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

        Task {
            do {
                let response = try await appState.cloudflareService.sendChatMessage(trimmed)
                let aiMessage = ChatMessage(role: "assistant", content: response.response, timestamp: Date())
                await MainActor.run {
                    messages.append(aiMessage)
                    isLoading = false
                }
            } catch {
                let errorMessage = ChatMessage(role: "assistant", content: "Sorry, I couldn't process that: \(error.localizedDescription)", timestamp: Date())
                await MainActor.run {
                    messages.append(errorMessage)
                    isLoading = false
                }
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
