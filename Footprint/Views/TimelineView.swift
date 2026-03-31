import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDate: Date
    @State private var hourGroups: [ActivityRecord.HourGroup] = []

    var body: some View {
        VStack(spacing: 0) {
            if hourGroups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hourGroups, id: \.hour) { group in
                            hourSection(group)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear { loadData() }
        .onChange(of: selectedDate) { loadData() }
    }

    @ViewBuilder
    private func hourSection(_ group: ActivityRecord.HourGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatHourRange(group.hour))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(fmtDur(Int(group.totalDuration / 60)))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Gemini summary if available
            if !group.summary.isEmpty {
                Text(group.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(2)
                    .padding(.bottom, 2)
            }

            VStack(spacing: 2) {
                ForEach(group.activities, id: \.name) { activity in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(activity.category.color)
                            .frame(width: 6, height: 6)
                        Text(activity.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text(fmtDur(Int(activity.totalDuration / 60)))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

        Divider().padding(.leading, 16)
    }

    private func loadData() {
        let records = (try? appState.databaseManager.dbPool.read { db in
            try ActivityRecord.recordsForDay(db: db, date: selectedDate)
        }) ?? []

        // Get 10-min summaries for this day
        let summaries = (try? appState.databaseManager.activitySummaries(for: selectedDate)) ?? []

        // Group summaries by hour
        let calendar = Calendar.current
        var summsByHour: [Int: [String]] = [:]
        for s in summaries {
            let hour = calendar.component(.hour, from: s.timestamp)
            summsByHour[hour, default: []].append(s.summary)
        }

        // Build hour groups and attach summaries
        var groups = ActivityRecord.buildHourGroups(from: records)
        for i in 0..<groups.count {
            if let hourSumms = summsByHour[groups[i].hour], !hourSumms.isEmpty {
                groups[i].summary = hourSumms.joined(separator: ". ")
            }
        }
        hourGroups = groups
    }

    private func formatHourRange(_ hour: Int) -> String {
        let start = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let end = (hour + 1) % 24
        let endDisplay = end == 0 ? 12 : (end > 12 ? end - 12 : end)
        let startP = hour >= 12 ? "PM" : "AM"
        let endP = (hour + 1) % 24 >= 12 && (hour + 1) % 24 != 0 ? "PM" : "AM"
        return "\(start) \(startP) – \(endDisplay) \(endP)"
    }

    private func fmtDur(_ minutes: Int) -> String {
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}
