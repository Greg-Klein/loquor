import AppKit

@MainActor
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    private var keyCode: UInt16 = 56
    private var modifierFlags: NSEvent.ModifierFlags = []
    private var isPressed = false
    private var isCapturing = false
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged],
            handler: { [weak self] event in
                self?.handle(event)
            }
        )
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    func updateHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection(.deviceIndependentFlagsMask)
        self.isPressed = false
    }

    func captureNextKey() {
        isCapturing = true
    }

    private func handle(_ event: NSEvent) {
        if isCapturing {
            capture(event)
            return
        }

        if event.type == .flagsChanged {
            handleFlagsChanged(event)
            return
        }

        if event.keyCode != keyCode {
            return
        }

        switch event.type {
        case .keyDown:
            if !isPressed && modifiersMatch(event.modifierFlags) {
                isPressed = true
                onPress?()
            }
        case .keyUp:
            if isPressed {
                isPressed = false
                onRelease?()
            }
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        let active = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let expected = modifierFlags.intersection(.deviceIndependentFlagsMask)

        if expected.isEmpty {
            if active.contains(flagForKeyCode(keyCode)) && !isPressed {
                isPressed = true
                onPress?()
            } else if !active.contains(flagForKeyCode(keyCode)) && isPressed {
                isPressed = false
                onRelease?()
            }
            return
        }

        let shouldBePressed = active.isSuperset(of: expected) && active.contains(flagForKeyCode(keyCode))
        if shouldBePressed && !isPressed {
            isPressed = true
            onPress?()
        } else if !shouldBePressed && isPressed {
            isPressed = false
            onRelease?()
        }
    }

    private func capture(_ event: NSEvent) {
        guard event.type == .keyDown || event.type == .flagsChanged else { return }
        isCapturing = false
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        onCapture?(event.keyCode, modifiers.subtracting(flagForKeyCode(event.keyCode)))
    }

    private func modifiersMatch(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection(.deviceIndependentFlagsMask).isSuperset(of: modifierFlags)
    }

    private func flagForKeyCode(_ keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 56, 60:
            return .shift
        case 59, 62:
            return .control
        case 58, 61:
            return .option
        case 55, 54:
            return .command
        default:
            return []
        }
    }
}
