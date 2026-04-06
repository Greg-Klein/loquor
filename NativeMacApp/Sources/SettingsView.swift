import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Loquor Settings")
                        .font(.largeTitle.weight(.semibold))
                    Text("Tune the shortcut, microphone, permissions and output behavior.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SettingsCard(title: "Push-to-talk", systemImage: "keyboard") {
                    LabeledContent("Current shortcut", value: appState.hotkeyLabel())
                    Button(appState.isCapturingHotkey ? "Press any key..." : "Change shortcut") {
                        appState.requestHotkeyCapture()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isCapturingHotkey)
                }

                SettingsCard(title: "Microphone", systemImage: "mic") {
                    Picker("Input", selection: Binding(
                        get: { appState.selectedDeviceID ?? -1 },
                        set: { newValue in
                            Task { await appState.updateSelectedDevice(newValue == -1 ? nil : newValue) }
                        }
                    )) {
                        Text("Default system input").tag(-1)
                        ForEach(appState.devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Refresh microphones") {
                        Task { await appState.refreshDevices() }
                    }
                    .buttonStyle(.bordered)
                }

                SettingsCard(title: "Output", systemImage: "doc.on.clipboard") {
                    Toggle("Paste automatically into focused field", isOn: Binding(
                        get: { appState.pasteIntoActiveField },
                        set: { _ in appState.togglePaste() }
                    ))

                    Toggle("Show diagnostics panels", isOn: Binding(
                        get: { appState.showDiagnostics },
                        set: { _ in appState.toggleDiagnosticsVisibility() }
                    ))

                    if !appState.hasAccessibilityPermission {
                        Button("Accessibility Settings") {
                            appState.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingsCard(title: "Status", systemImage: "waveform.path.ecg") {
                    Text(appState.statusText)
                        .font(.body.weight(.semibold))
                    if appState.showDiagnostics, let pasteDiagnostics = appState.pasteDiagnostics {
                        Text(pasteDiagnostics)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    if appState.showDiagnostics, let backendError = appState.backendError {
                        Text(backendError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !appState.lastTranscript.isEmpty {
                    SettingsCard(title: "Last Transcript", systemImage: "text.quote") {
                        Text(appState.lastTranscript)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: 560)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            await appState.startup()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshAccessibilityPermission()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}
