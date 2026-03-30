import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("cloudflare_base_url") private var cfBaseURL = ""
    @AppStorage("cloudflare_api_key") private var cfApiKey = ""
    @State private var showingKey = false

    var body: some View {
        Form {
            Section("Cloudflare Worker") {
                TextField("Worker URL", text: $cfBaseURL)
                    .textFieldStyle(.roundedBorder)

                Text("e.g. https://cf-ai-footprint.your-account.workers.dev")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    if showingKey {
                        TextField("API Key (optional)", text: $cfApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key (optional)", text: $cfApiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showingKey.toggle() }) {
                        Image(systemName: showingKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                // Connection status
                HStack {
                    Image(systemName: cfBaseURL.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(cfBaseURL.isEmpty ? .red : .green)
                    Text(cfBaseURL.isEmpty ? "Not configured" : "Configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Permissions") {
                HStack {
                    Label {
                        Text("Accessibility")
                    } icon: {
                        Image(systemName: Permissions.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(Permissions.hasAccessibilityPermission ? .green : .red)
                    }
                    Spacer()
                    if !Permissions.hasAccessibilityPermission {
                        Button("Grant") {
                            Permissions.requestAccessibilityPermission()
                        }
                    }
                }

                HStack {
                    Label("Screen Recording", systemImage: "record.circle")
                    Spacer()
                    Button("Open Settings") {
                        Permissions.openScreenRecordingSettings()
                    }
                }
            }

            Section("Tracking") {
                LabeledContent("Window poll interval") {
                    Text("Every \(Int(TrackingConstants.windowPollInterval))s")
                }
                LabeledContent("Screenshot interval") {
                    Text("Every \(Int(TrackingConstants.screenshotInterval))s")
                }
                LabeledContent("Summary generation") {
                    Text("Every hour (via Cloudflare)")
                }
                LabeledContent("Screenshot retention") {
                    Text("\(TrackingConstants.screenshotRetentionDays) days")
                }
            }

            Section("Data") {
                Button("Clean Up Old Screenshots") {
                    appState.screenshotService.cleanupOldScreenshots()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 450)
    }
}
