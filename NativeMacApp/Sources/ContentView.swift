import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(Color.white.opacity(0.14))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    InfoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Push-to-talk", systemImage: appState.pushToTalkBinding.kind == .mouse ? "computermouse" : "keyboard")
                                .font(.headline)

                            HStack(alignment: .firstTextBaseline) {
                                Text("Current shortcut")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(appState.hotkeyLabel())
                                    .font(.body.weight(.semibold))
                            }

                            Text("Set a keyboard shortcut or press a mouse button.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(appState.isCapturingHotkey ? "Press any key or mouse button..." : "Change push-to-talk key") {
                                appState.requestHotkeyCapture()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appState.isCapturingHotkey || appState.isPreloadingModel)

                            if appState.isPreloadingModel {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let percent = appState.preloadProgressPercent {
                                        ProgressView(value: Double(percent), total: 100)
                                            .controlSize(.small)
                                        Text("Downloading or loading Parakeet: \(percent)%")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        HStack(spacing: 10) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Downloading or loading Parakeet. This can take a moment on first launch.")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
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

                            Toggle("Start Loquor at login", isOn: Binding(
                                get: { appState.launchAtLogin },
                                set: { appState.setLaunchAtLogin($0) }
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

                    if appState.showDiagnostics, let loginItemError = appState.loginItemError {
                        InfoCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Login Item Error", systemImage: "person.crop.circle.badge.exclamationmark")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                Text(loginItemError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(Color.white.opacity(0.14))

            footer
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Loquor")
                        .font(.title2.weight(.semibold))
                    Text("Local dictation for macOS with configurable push-to-talk.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appState.isPreloadingModel {
                    HStack(spacing: 8) {
                        if let percent = appState.preloadProgressPercent {
                            ProgressView(value: Double(percent), total: 100)
                                .frame(width: 54)
                                .controlSize(.small)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(appState.statusText)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusColor)
                } else {
                    Text(appState.statusText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Button("Quit") {
                appState.quitApplication()
            }
            .buttonStyle(.bordered)

            Spacer()

            Link("By Gregory Klein", destination: URL(string: "https://github.com/Greg-Klein")!)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: -6)
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
