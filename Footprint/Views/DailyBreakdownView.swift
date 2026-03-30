import SwiftUI
import Charts

struct DailyBreakdownView: View {
    @EnvironmentObject var appState: AppState
    @State private var appUsages: [ActivityRecord.AppUsage] = []
    @State private var selectedDate = Date()

    var totalMinutes: Int {
        Int(appUsages.reduce(0) { $0 + $1.totalDuration } / 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if appUsages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No activity recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Total time header — Screen Time style
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Screen Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(totalMinutes))
                                .font(.system(size: 28, weight: .bold))
                        }
                        .padding(.horizontal, 16)

                        // Stacked horizontal bar — Screen Time style
                        ScreenTimeBar(appUsages: Array(appUsages.prefix(8)), totalMinutes: totalMinutes)
                            .frame(height: 28)
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // App list
                        VStack(spacing: 0) {
                            ForEach(appUsages, id: \.appName) { usage in
                                ScreenTimeAppRow(usage: usage, totalMinutes: totalMinutes)
                                if usage.appName != appUsages.last?.appName {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear { loadData() }
        .onChange(of: selectedDate) { loadData() }
    }

    private func loadData() {
        appUsages = (try? appState.databaseManager.dailyAppUsage(for: selectedDate)) ?? []
    }

    private func formatDuration(_ totalMinutes: Int) -> String {
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
        }
        return "\(totalMinutes)m"
    }
}

// Screen Time-style stacked horizontal bar
struct ScreenTimeBar: View {
    let appUsages: [ActivityRecord.AppUsage]
    let totalMinutes: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(appUsages, id: \.appName) { usage in
                    let minutes = usage.totalDuration / 60
                    let fraction = totalMinutes > 0 ? minutes / Double(totalMinutes) : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForCategory(usage.category))
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func colorForCategory(_ category: String?) -> Color {
        guard let cat = category, let appCat = AppCategory(rawValue: cat) else {
            return .blue
        }
        return appCat.color
    }
}

struct ScreenTimeAppRow: View {
    let usage: ActivityRecord.AppUsage
    let totalMinutes: Int

    var minutes: Int { Int(usage.totalDuration / 60) }
    var percentage: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int(Double(minutes) / Double(totalMinutes) * 100)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator dot
            Circle()
                .fill(colorForCategory(usage.category))
                .frame(width: 10, height: 10)

            Image(systemName: iconForApp(usage.appName))
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(usage.appName)
                    .font(.callout)
                if let category = usage.category {
                    Text(category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(formatDuration(minutes))
                    .font(.callout)
                    .monospacedDigit()
                Text("\(percentage)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func colorForCategory(_ category: String?) -> Color {
        guard let cat = category, let appCat = AppCategory(rawValue: cat) else {
            return .blue
        }
        return appCat.color
    }

    private func formatDuration(_ totalMinutes: Int) -> String {
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
        }
        return "\(totalMinutes)m"
    }

    private func iconForApp(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("safari") || n.contains("chrome") || n.contains("firefox"):
            return "globe"
        case let n where n.contains("xcode"):
            return "hammer"
        case let n where n.contains("terminal"):
            return "terminal"
        case let n where n.contains("message") || n.contains("slack") || n.contains("discord"):
            return "bubble.left"
        case let n where n.contains("mail"):
            return "envelope"
        case let n where n.contains("music") || n.contains("spotify"):
            return "music.note"
        default:
            return "app"
        }
    }
}
