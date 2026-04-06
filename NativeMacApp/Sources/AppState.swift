import AppKit
import ApplicationServices
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var devices: [AudioDevice] = []
    @Published var selectedDeviceID: Int?
    @Published var pushToTalkBinding: PushToTalkBinding
    @Published var pasteIntoActiveField: Bool
    @Published var launchAtLogin: Bool
    @Published var isPreloadingModel = false
    @Published var preloadProgressPercent: Int?
    @Published var statusText = "Starting..."
    @Published var lastTranscript = ""
    @Published var isCapturingHotkey = false
    @Published var backendError: String?
    @Published var pasteDiagnostics: String?
    @Published var showDiagnostics: Bool
    @Published var hasAccessibilityPermission: Bool
    @Published var loginItemError: String?

    private let backend = BackendClient()
    private let hotkeyMonitor = HotkeyMonitor()
    private let defaultsKey = "Loquor.Settings"
    private var settings: AppSettings
    private var isTranscribing = false
    private var hasStarted = false
    private var targetApplication: NSRunningApplication?

    init() {
        let defaults = UserDefaults.standard
        if
            let data = defaults.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            settings = decoded
        } else {
            settings = AppSettings()
        }

        selectedDeviceID = settings.selectedDeviceID
        pushToTalkBinding = settings.pushToTalkBinding
        pasteIntoActiveField = settings.pasteIntoActiveField
        launchAtLogin = settings.launchAtLogin
        showDiagnostics = settings.showDiagnostics
        hasAccessibilityPermission = AXIsProcessTrusted()

        hotkeyMonitor.onPress = { [weak self] in
            Task { await self?.beginRecording() }
        }
        hotkeyMonitor.onRelease = { [weak self] in
            Task { await self?.endRecording() }
        }
        hotkeyMonitor.onCapture = { [weak self] binding in
            self?.applyCapturedHotkey(binding: binding)
        }
        backend.onPreloadProgress = { [weak self] progress in
            Task { @MainActor in
                self?.statusText = progress.message
                self?.preloadProgressPercent = progress.percent
            }
        }
        hotkeyMonitor.updateHotkey(binding: pushToTalkBinding)
        hotkeyMonitor.start()
        Task {
            await startup()
        }
    }

    func startup() async {
        guard !hasStarted else { return }
        hasStarted = true
        refreshAccessibilityPermission()
        syncLaunchAtLoginPreference()
        do {
            isPreloadingModel = true
            preloadProgressPercent = nil
            try backend.start()
            _ = try await backend.ping()
            try await configureBackendWithFallback()
            devices = try await backend.listDevices()
            statusText = "Preparing model..."
            try await backend.preloadModel()
            isPreloadingModel = false
            preloadProgressPercent = nil
            backendError = nil
            statusText = "Ready"
        } catch {
            isPreloadingModel = false
            preloadProgressPercent = nil
            backendError = error.localizedDescription
            statusText = "Backend error"
        }
    }

    func refreshDevices() async {
        do {
            devices = try await backend.listDevices()
            statusText = "Microphone list refreshed"
        } catch {
            backendError = error.localizedDescription
            statusText = "Device refresh failed"
        }
    }

    func updateSelectedDevice(_ id: Int?) async {
        selectedDeviceID = id
        persist()
        do {
            try await configureBackendWithFallback(preferredDeviceID: id)
            backendError = nil
            statusText = "Microphone updated"
        } catch {
            backendError = error.localizedDescription
            statusText = "Microphone update failed"
        }
    }

    func togglePaste() {
        pasteIntoActiveField.toggle()
        persist()
        statusText = "Paste setting updated"
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try updateLaunchAtLogin(enabled)
            launchAtLogin = enabled
            settings.launchAtLogin = enabled
            persist()
            loginItemError = nil
            statusText = enabled ? "Launch at login enabled" : "Launch at login disabled"
        } catch {
            launchAtLogin = settings.launchAtLogin
            loginItemError = error.localizedDescription
            statusText = "Launch at login update failed"
        }
    }

    func toggleDiagnosticsVisibility() {
        showDiagnostics.toggle()
        persist()
    }

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestHotkeyCapture() {
        isCapturingHotkey = true
        statusText = "Press a key or mouse button for push-to-talk"
        hotkeyMonitor.captureNextKey()
    }

    func hotkeyLabel() -> String {
        HotkeyFormatter.label(for: pushToTalkBinding)
    }

    private func applyCapturedHotkey(binding: PushToTalkBinding) {
        isCapturingHotkey = false
        pushToTalkBinding = binding
        hotkeyMonitor.updateHotkey(binding: binding)
        persist()
        statusText = "Push-to-talk set to \(hotkeyLabel())"
    }

    private func beginRecording() async {
        guard !isTranscribing else { return }
        guard !isPreloadingModel else {
            statusText = "Preparing model..."
            return
        }
        captureTargetApplication()
        do {
            try await backend.beginRecording()
            backendError = nil
            statusText = "Recording..."
        } catch {
            backendError = error.localizedDescription
            statusText = "Could not start recording"
        }
    }

    private func endRecording() async {
        guard !isTranscribing else { return }
        isTranscribing = true
        statusText = "Transcribing..."
        defer { isTranscribing = false }

        do {
            let response = try await backend.endRecording()
            guard !response.empty else {
                statusText = "No speech detected"
                return
            }

            lastTranscript = response.text
            if pasteIntoActiveField {
                let clipboardSnapshot = ClipboardManager.snapshot()
                try? await Task.sleep(nanoseconds: 50_000_000)
                let result = ClipboardManager.activateAndInsert(response.text, into: targetApplication)
                if result.method == "cmd-v-fallback" {
                    try? await Task.sleep(nanoseconds: 180_000_000)
                }
                ClipboardManager.restore(clipboardSnapshot)
                pasteDiagnostics = result.diagnostics
                statusText = result.inserted ? "Transcript inserted" : "Transcript copied"
                return
            }
            ClipboardManager.copy(response.text)
            pasteDiagnostics = "Auto-paste disabled; transcript copied only."
            statusText = "Transcript copied"
        } catch {
            backendError = error.localizedDescription
            statusText = "Transcription failed"
        }
    }

    private func persist() {
        settings.selectedDeviceID = selectedDeviceID
        settings.pushToTalkBinding = pushToTalkBinding
        settings.pasteIntoActiveField = pasteIntoActiveField
        settings.launchAtLogin = launchAtLogin
        settings.showDiagnostics = showDiagnostics
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func configureBackendWithFallback(preferredDeviceID: Int? = nil) async throws {
        do {
            try await backend.configure(deviceID: preferredDeviceID ?? selectedDeviceID)
        } catch {
            if preferredDeviceID != nil || selectedDeviceID != nil {
                selectedDeviceID = nil
                persist()
                try await backend.configure(deviceID: nil)
            } else {
                throw error
            }
        }
    }

    func shutdown() {
        hotkeyMonitor.stop()
        backend.stop()
    }

    func openAccessibilitySettings() {
        refreshAccessibilityPermission()
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func quitApplication() {
        shutdown()
        NSApp.terminate(nil)
    }

    private func captureTargetApplication() {
        let currentAppPID = ProcessInfo.processInfo.processIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let frontmost, frontmost.processIdentifier != currentAppPID {
            targetApplication = frontmost
        }
    }

    private func openSystemSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func syncLaunchAtLoginPreference() {
        do {
            try updateLaunchAtLogin(settings.launchAtLogin)
            launchAtLogin = settings.launchAtLogin
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
            try SMAppService.mainApp.unregister()
        }
    }
}
