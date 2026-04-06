import AppKit

@MainActor
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCapture: ((PushToTalkBinding) -> Void)?

    private let keyboardEventMask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
    private let mouseEventMask: NSEvent.EventTypeMask = [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
    ]
    private var binding = PushToTalkBinding()
    private var isPressed = false
    private var isCapturing = false
    private var globalKeyboardMonitor: Any?
    private var localKeyboardMonitor: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    func start() {
        stop()
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: keyboardEventMask,
            handler: { [weak self] event in
                self?.handle(event)
            }
        )
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(
            matching: keyboardEventMask
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
        updateMouseMonitors()
    }

    func stop() {
        if let globalKeyboardMonitor {
            NSEvent.removeMonitor(globalKeyboardMonitor)
        }
        if let localKeyboardMonitor {
            NSEvent.removeMonitor(localKeyboardMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        globalKeyboardMonitor = nil
        localKeyboardMonitor = nil
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    func updateHotkey(binding: PushToTalkBinding) {
        self.binding = binding
        self.isPressed = false
        updateMouseMonitors()
    }

    func captureNextKey() {
        isCapturing = true
        updateMouseMonitors()
    }

    private func handle(_ event: NSEvent) {
        if isCapturing {
            capture(event)
            return
        }

        if binding.kind == .mouse {
            handleMouse(event)
            return
        }

        if event.type == .flagsChanged {
            handleFlagsChanged(event)
            return
        }

        if event.keyCode != binding.keyCode {
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
        guard event.keyCode == binding.keyCode else { return }
        let active = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let expected = binding.modifiers.intersection(NSEvent.ModifierFlags.deviceIndependentFlagsMask)

        if expected.isEmpty {
            if active.contains(flagForKeyCode(binding.keyCode)) && !isPressed {
                isPressed = true
                onPress?()
            } else if !active.contains(flagForKeyCode(binding.keyCode)) && isPressed {
                isPressed = false
                onRelease?()
            }
            return
        }

        let shouldBePressed = active.isSuperset(of: expected) && active.contains(flagForKeyCode(binding.keyCode))
        if shouldBePressed && !isPressed {
            isPressed = true
            onPress?()
        } else if !shouldBePressed && isPressed {
            isPressed = false
            onRelease?()
        }
    }

    private func handleMouse(_ event: NSEvent) {
        guard let eventButton = mouseButton(for: event), eventButton == binding.mouseButton else { return }

        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if !isPressed {
                isPressed = true
                onPress?()
            }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if isPressed {
                isPressed = false
                onRelease?()
            }
        default:
            break
        }
    }

    private func capture(_ event: NSEvent) {
        switch event.type {
        case .keyDown, .flagsChanged:
            isCapturing = false
            updateMouseMonitors()
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            onCapture?(
                PushToTalkBinding(
                    kind: .keyboard,
                    keyCode: event.keyCode,
                    modifiersRawValue: modifiers.subtracting(flagForKeyCode(event.keyCode)).rawValue,
                    mouseButton: nil
                )
            )
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard let button = mouseButton(for: event) else { return }
            isCapturing = false
            updateMouseMonitors()
            onCapture?(
                PushToTalkBinding(
                    kind: .mouse,
                    keyCode: 0,
                    modifiersRawValue: 0,
                    mouseButton: button
                )
            )
        default:
            return
        }
    }

    private func updateMouseMonitors() {
        let shouldMonitorMouseGlobally = binding.kind == .mouse || isCapturing
        let shouldMonitorMouseLocally = isCapturing

        if shouldMonitorMouseGlobally {
            if globalMouseMonitor == nil {
                globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                    matching: mouseEventMask,
                    handler: { [weak self] event in
                        self?.handle(event)
                    }
                )
            }
        } else if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if shouldMonitorMouseLocally {
            if localMouseMonitor == nil {
                localMouseMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: mouseEventMask
                ) { [weak self] event in
                    self?.handle(event)
                    return event
                }
            }
        } else if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func modifiersMatch(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection(.deviceIndependentFlagsMask).isSuperset(of: binding.modifiers)
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

    private func mouseButton(for event: NSEvent) -> Int? {
        switch event.type {
        case .leftMouseDown, .leftMouseUp:
            return 0
        case .rightMouseDown, .rightMouseUp:
            return 1
        case .otherMouseDown, .otherMouseUp:
            return Int(event.buttonNumber)
        default:
            return nil
        }
    }
}
