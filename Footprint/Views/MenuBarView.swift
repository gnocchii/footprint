import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .apps
    @State private var selectedDate = Date()

    enum Tab: String, CaseIterable {
        case apps = "Apps"
        case categories = "Categories"
        case timeline = "Timeline"
        case chat = "Chat"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Footprint")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: {
                    Task { await appState.refreshNow() }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Refresh analysis")

                Button(action: { appState.toggleTracking() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(appState.isTracking ? .green : .orange)
                            .frame(width: 7, height: 7)
                        Text(appState.isTracking ? "Tracking" : "Paused")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Error banners
            if !appState.issues.isEmpty {
                VStack(spacing: 4) {
                    ForEach(appState.issues, id: \.self) { issue in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text(issue)
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Spacer()
                            if issue.contains("Accessibility") {
                                Button("Fix") { Permissions.openAccessibilitySettings() }
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Global date picker with arrows
            HStack(spacing: 12) {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()

                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(Calendar.current.isDateInToday(selectedDate))

                Spacer()

                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Content — pass selectedDate to all tabs
            Group {
                switch selectedTab {
                case .apps:
                    DailyBreakdownView(selectedDate: $selectedDate)
                case .categories:
                    CategoryView(selectedDate: $selectedDate)
                case .timeline:
                    TimelineView(selectedDate: $selectedDate)
                case .chat:
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button("Quit Footprint") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .frame(width: 400, height: 520)
    }

    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
}
