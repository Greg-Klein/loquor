import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var devices: [AudioDevice] = []
    @Published var selectedDeviceID: Int?
    @Published var pushToTalkKeyCode: UInt16
    @Published var pushToTalkModifiers: NSEvent.ModifierFlags
    @Published var pasteIntoActiveField: Bool
    @Published var statusText = "Starting..."
    @Published var lastTranscript = ""
    @Published var isCapturingHotkey = false
    @Published var backendError: String?
    @Published var pasteDiagnostics: String?
    @Published var showDiagnostics: Bool
    @Published var hasAccessibilityPermission: Bool

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
        pushToTalkKeyCode = settings.pushToTalkKeyCode
        pushToTalkModifiers = NSEvent.ModifierFlags(rawValue: settings.pushToTalkModifiersRawValue)
        pasteIntoActiveField = settings.pasteIntoActiveField
        showDiagnostics = settings.showDiagnostics
        hasAccessibilityPermission = AXIsProcessTrusted()

        hotkeyMonitor.onPress = { [weak self] in
            Task { await self?.beginRecording() }
        }
        hotkeyMonitor.onRelease = { [weak self] in
            Task { await self?.endRecording() }
        }
        hotkeyMonitor.onCapture = { [weak self] keyCode, modifiers in
            self?.applyCapturedHotkey(keyCode: keyCode, modifiers: modifiers)
        }
        hotkeyMonitor.updateHotkey(keyCode: pushToTalkKeyCode, modifiers: pushToTalkModifiers)
        hotkeyMonitor.start()
        Task {
            await startup()
        }
    }

    func startup() async {
        guard !hasStarted else { return }
        hasStarted = true
        refreshAccessibilityPermission()
        do {
            try backend.start()
            _ = try await backend.ping()
            try await configureBackendWithFallback()
            devices = try await backend.listDevices()
            backendError = nil
            statusText = "Ready"
        } catch {
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

    func toggleDiagnosticsVisibility() {
        showDiagnostics.toggle()
        persist()
    }

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestHotkeyCapture() {
        isCapturingHotkey = true
        statusText = "Press a key for push-to-talk"
        hotkeyMonitor.captureNextKey()
    }

    func hotkeyLabel() -> String {
        HotkeyFormatter.label(for: pushToTalkKeyCode, modifiers: pushToTalkModifiers)
    }

    private func applyCapturedHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        isCapturingHotkey = false
        pushToTalkKeyCode = keyCode
        pushToTalkModifiers = modifiers
        hotkeyMonitor.updateHotkey(keyCode: keyCode, modifiers: modifiers)
        persist()
        statusText = "Push-to-talk set to \(hotkeyLabel())"
    }

    private func beginRecording() async {
        guard !isTranscribing else { return }
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
        settings.pushToTalkKeyCode = pushToTalkKeyCode
        settings.pushToTalkModifiersRawValue = pushToTalkModifiers.rawValue
        settings.pasteIntoActiveField = pasteIntoActiveField
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
}
