import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .timeline

    enum Tab: String, CaseIterable {
        case timeline = "Timeline"
        case apps = "Apps"
        case categories = "Categories"
        case chat = "Chat"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — Screen Time style
            HStack {
                Image(systemName: "shoeprints.fill")
                    .foregroundStyle(.blue)
                Text("Footprint")
                    .font(.headline)
                Spacer()

                Button(action: { appState.toggleTracking() }) {
                    Image(systemName: appState.isTracking ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundStyle(appState.isTracking ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(appState.isTracking ? "Pause tracking" : "Resume tracking")

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Content
            Group {
                switch selectedTab {
                case .timeline:
                    TimelineView()
                case .apps:
                    DailyBreakdownView()
                case .categories:
                    CategoryView()
                case .chat:
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Circle()
                    .fill(appState.isTracking ? .green : .secondary)
                    .frame(width: 6, height: 6)
                Text(appState.isTracking ? "Tracking" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 400, height: 520)
    }
}
