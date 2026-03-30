import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var appState: AppState
    @State private var summaries: [HourlySummary] = []
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            // Date picker
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if summaries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No summaries yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Summaries are generated hourly")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(summaries) { summary in
                            HourlySummaryCard(summary: summary)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear { loadSummaries() }
        .onChange(of: selectedDate) { loadSummaries() }
    }

    private func loadSummaries() {
        summaries = (try? appState.databaseManager.summariesForDay(date: selectedDate)) ?? []
    }
}

struct HourlySummaryCard: View {
    let summary: HourlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hourLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                Spacer()
            }

            Text(summary.summary)
                .font(.callout)
                .lineLimit(3)

            // Top apps
            HStack(spacing: 8) {
                ForEach(summary.decodedTopApps.prefix(3), id: \.app) { appUsage in
                    HStack(spacing: 2) {
                        Text(appUsage.app)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text("\(appUsage.minutes)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .cornerRadius(4)
                }
            }
        }
        .padding(12)
        .background(.background)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var hourLabel: String {
        let startHour = summary.hour
        let endHour = (startHour + 1) % 24
        return "\(formatHour(startHour)) - \(formatHour(endHour))"
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }
}
