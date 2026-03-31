import SwiftUI

struct DailyBreakdownView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDate: Date
    @State private var appUsages: [ActivityRecord.AppUsage] = []

    var totalMinutes: Int {
        Int(appUsages.reduce(0) { $0 + $1.totalDuration } / 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            if appUsages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "macbook")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Screen Time")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(fmtDur(totalMinutes))
                                .font(.system(size: 28, weight: .bold))
                        }
                        .padding(.horizontal, 16)

                        // Bar
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                ForEach(appUsages.prefix(10), id: \.name) { usage in
                                    let frac = totalMinutes > 0 ? (usage.totalDuration / 60) / Double(totalMinutes) : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(usage.category.color)
                                        .frame(width: max(4, geo.size.width * frac))
                                }
                            }
                        }
                        .frame(height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 16)

                        Divider().padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            ForEach(Array(appUsages.enumerated()), id: \.element.name) { i, usage in
                                let mins = Int(usage.totalDuration / 60)
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(usage.category.color)
                                        .frame(width: 4, height: 30)
                                    Image(systemName: iconForName(usage.name))
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Text(usage.name)
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text(fmtDur(mins))
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 5)

                                if i < appUsages.count - 1 {
                                    Divider().padding(.leading, 50)
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
        let records = (try? appState.databaseManager.dbPool.read { db in
            try ActivityRecord.recordsForDay(db: db, date: selectedDate)
        }) ?? []
        appUsages = ActivityRecord.buildAppUsage(from: records)
    }

    private func fmtDur(_ minutes: Int) -> String {
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    private func iconForName(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("xcode"): return "hammer.fill"
        case let n where n.contains("terminal") || n.contains("iterm") || n.contains("kitty") || n.contains("warp"): return "terminal.fill"
        case let n where n.contains("code") || n.contains("windsurf") || n.contains("cursor"): return "chevron.left.forwardslash.chevron.right"
        case let n where n.contains("message"): return "message.fill"
        case let n where n.contains("slack"): return "number.square.fill"
        case let n where n.contains("discord"): return "bubble.left.and.bubble.right.fill"
        case let n where n.contains("outlook") || n.contains("gmail") || n.contains("mail"): return "envelope.fill"
        case let n where n.contains("music") || n.contains("spotify"): return "music.note"
        case let n where n.contains("finder"): return "folder.fill"
        case let n where n.contains("zoom") || n.contains("facetime"): return "video.fill"
        case let n where n.contains("github"): return "chevron.left.forwardslash.chevron.right"
        case let n where n.contains("youtube"): return "play.rectangle.fill"
        case let n where n.contains("9anime") || n.contains("crunchyroll"): return "sparkles.tv"
        case let n where n.contains("notion"): return "doc.text.fill"
        default: return "globe"
        }
    }
}
