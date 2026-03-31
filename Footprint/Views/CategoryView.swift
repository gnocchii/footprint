import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDate: Date
    @State private var groups: [CatGroup] = []
    @State private var expandedCategories: Set<String> = []

    var totalMinutes: Int {
        groups.reduce(0) { $0 + $1.totalMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
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
                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Breakdown")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(fmtDur(totalMinutes))
                                .font(.system(size: 28, weight: .bold))
                        }
                        .padding(.horizontal, 16)

                        // Bar
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                ForEach(groups) { g in
                                    let frac = totalMinutes > 0 ? Double(g.totalMinutes) / Double(totalMinutes) : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(g.appCategory.color)
                                        .frame(width: max(4, geo.size.width * frac))
                                }
                            }
                        }
                        .frame(height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 16)

                        // Category list
                        VStack(spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { i, group in
                                categoryRow(group)
                                if i < groups.count - 1 {
                                    Divider().padding(.horizontal, 16).padding(.vertical, 2)
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

    @ViewBuilder
    private func categoryRow(_ group: CatGroup) -> some View {
        let isExpanded = expandedCategories.contains(group.name)
        let pct = totalMinutes > 0 ? Int(Double(group.totalMinutes) / Double(totalMinutes) * 100) : 0

        Button(action: { toggle(&expandedCategories, group.name) }) {
            HStack(spacing: 10) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: 10)
                Image(systemName: group.appCategory.icon)
                    .font(.system(size: 14)).foregroundStyle(group.appCategory.color).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(pct)% of screen time")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(fmtDur(group.totalMinutes))
                    .font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 6).contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isExpanded {
            ForEach(group.subcategories) { sub in
                HStack(spacing: 8) {
                    Spacer().frame(width: 42)
                    Circle()
                        .fill(group.appCategory.color.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(sub.name)
                        .font(.system(size: 12))
                    Spacer()
                    Text(fmtDur(sub.totalMinutes))
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 3)
            }
        }
    }

    private func loadData() {
        let records = (try? appState.databaseManager.dbPool.read { db in
            try ActivityRecord.recordsForDay(db: db, date: selectedDate)
        }) ?? []
        let geminiDescs = (try? appState.databaseManager.geminiDescriptions(for: selectedDate)) ?? []
        groups = ActivityRecord.buildCategoryGroups(from: records, geminiDescriptions: geminiDescs)
        if expandedCategories.isEmpty, let first = groups.first {
            expandedCategories.insert(first.name)
        }
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func fmtDur(_ minutes: Int) -> String {
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}

// MARK: - Shared data models

struct CatEntry: Identifiable {
    let id = UUID()
    let label: String
    let minutes: Int
}

struct CatSub: Identifiable {
    let id = UUID()
    let name: String
    let entries: [CatEntry]
    let totalSeconds: TimeInterval
    var totalMinutes: Int { Int(totalSeconds / 60) }
}

struct CatGroup: Identifiable {
    let id = UUID()
    let name: String
    let subcategories: [CatSub]
    let totalSeconds: TimeInterval
    let appCategory: AppCategory
    var totalMinutes: Int { Int(totalSeconds / 60) }
}
