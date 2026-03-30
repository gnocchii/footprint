import SwiftUI
import Charts

struct CategoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var categoryUsages: [ActivityRecord.CategoryUsage] = []
    @State private var selectedDate = Date()

    var totalMinutes: Int {
        Int(categoryUsages.reduce(0) { $0 + $1.totalDuration } / 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if categoryUsages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No categorized activity yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Categories are assigned by AI after hourly summaries")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Total time header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("By Category")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(totalMinutes))
                                .font(.system(size: 28, weight: .bold))
                        }
                        .padding(.horizontal, 16)

                        // Stacked bar — Screen Time style
                        CategoryBar(categoryUsages: categoryUsages, totalMinutes: totalMinutes)
                            .frame(height: 28)
                            .padding(.horizontal, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        // Category list
                        VStack(spacing: 0) {
                            ForEach(categoryUsages, id: \.category) { usage in
                                ScreenTimeCategoryRow(usage: usage, totalMinutes: totalMinutes)
                                if usage.category != categoryUsages.last?.category {
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
        categoryUsages = (try? appState.databaseManager.dailyCategoryUsage(for: selectedDate)) ?? []
    }

    private func formatDuration(_ totalMinutes: Int) -> String {
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
        }
        return "\(totalMinutes)m"
    }
}

struct CategoryBar: View {
    let categoryUsages: [ActivityRecord.CategoryUsage]
    let totalMinutes: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(categoryUsages, id: \.category) { usage in
                    let minutes = usage.totalDuration / 60
                    let fraction = totalMinutes > 0 ? minutes / Double(totalMinutes) : 0
                    let cat = AppCategory(rawValue: usage.category) ?? .other
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cat.color)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ScreenTimeCategoryRow: View {
    let usage: ActivityRecord.CategoryUsage
    let totalMinutes: Int

    var minutes: Int { Int(usage.totalDuration / 60) }
    var percentage: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int(Double(minutes) / Double(totalMinutes) * 100)
    }

    var body: some View {
        HStack(spacing: 12) {
            let cat = AppCategory(rawValue: usage.category) ?? .other

            Circle()
                .fill(cat.color)
                .frame(width: 10, height: 10)

            Image(systemName: cat.icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(cat.color)

            Text(usage.category)
                .font(.callout)

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
        .padding(.vertical, 8)
    }

    private func formatDuration(_ totalMinutes: Int) -> String {
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
        }
        return "\(totalMinutes)m"
    }
}
