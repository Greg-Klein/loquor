import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                InfoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Push-to-talk", systemImage: "keyboard")
                            .font(.headline)

                        HStack(alignment: .firstTextBaseline) {
                            Text("Current shortcut")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(appState.hotkeyLabel())
                                .font(.body.weight(.semibold))
                        }

                        Button(appState.isCapturingHotkey ? "Press any key..." : "Change push-to-talk key") {
                            appState.requestHotkeyCapture()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isCapturingHotkey)
                    }
                }

                InfoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Audio Input", systemImage: "mic")
                            .font(.headline)

                        Picker("Microphone", selection: Binding(
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
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Button("Refresh microphones") {
                            Task { await appState.refreshDevices() }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                InfoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Output", systemImage: "doc.on.clipboard")
                            .font(.headline)

                        Toggle("Auto-paste into focused field", isOn: Binding(
                            get: { appState.pasteIntoActiveField },
                            set: { _ in appState.togglePaste() }
                        ))

                        if !appState.lastTranscript.isEmpty {
                            Divider()
                            Text("Last transcript")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(appState.lastTranscript)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    Color.primary.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                        }

                        Button(appState.showDiagnostics ? "Hide diagnostics" : "Show diagnostics") {
                            appState.toggleDiagnosticsVisibility()
                        }
                        .buttonStyle(.borderless)
                        .font(.footnote.weight(.semibold))
                    }
                }

                if !appState.hasAccessibilityPermission {
                    InfoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Permissions", systemImage: "lock.shield")
                                .font(.headline)

                            Text("Allow Accessibility so Loquor can insert text directly into the focused field.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button("Accessibility") {
                                appState.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if appState.showDiagnostics, let pasteDiagnostics = appState.pasteDiagnostics {
                    InfoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Paste Diagnostics", systemImage: "stethoscope")
                                .font(.headline)
                            Text(pasteDiagnostics)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                if appState.showDiagnostics, let backendError = appState.backendError {
                    InfoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Backend Error", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text(backendError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                HStack {
                    Button("Quit") {
                        appState.quitApplication()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(width: 390, height: 620)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.08),
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Loquor")
                    .font(.title2.weight(.semibold))
                Text("Local dictation for macOS with configurable push-to-talk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(appState.statusText)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.14), in: Capsule())
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        let status = appState.statusText.lowercased()
        if status.contains("error") || status.contains("failed") {
            return .red
        }
        if status.contains("recording") || status.contains("transcribing") {
            return .orange
        }
        return .accentColor
    }
}

private struct InfoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}
