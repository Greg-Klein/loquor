import AppKit

enum HotkeyFormatter {
    static func label(for binding: PushToTalkBinding) -> String {
        switch binding.kind {
        case .keyboard:
            return label(for: binding.keyCode, modifiers: binding.modifiers)
        case .mouse:
            return mouseLabel(for: binding.mouseButton ?? 2)
        }
    }

    static func label(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let modifierLabels = labels(for: modifiers)
        let key = keyLabel(for: keyCode)
        return (modifierLabels + [key]).joined(separator: " + ")
    }

    static func labels(for modifiers: NSEvent.ModifierFlags) -> [String] {
        var labels: [String] = []
        if modifiers.contains(.command) { labels.append("Command") }
        if modifiers.contains(.control) { labels.append("Control") }
        if modifiers.contains(.option) { labels.append("Option") }
        if modifiers.contains(.shift) { labels.append("Shift") }
        return labels
    }

    static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 55, 54: return "Command"
        case 56, 60: return "Shift"
        case 58, 61: return "Option"
        case 59, 62: return "Control"
        default:
            if let scalar = KeyCodeMap.printableCharacter(for: keyCode) {
                return scalar
            }
            return "Key \(keyCode)"
        }
    }

    static func mouseLabel(for button: Int) -> String {
        switch button {
        case 0: return "Left Mouse Button"
        case 1: return "Right Mouse Button"
        case 2: return "Middle Mouse Button"
        default: return "Mouse Button \(button + 1)"
        }
    }
}

private enum KeyCodeMap {
    static func printableCharacter(for keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`"
        ]
        return map[keyCode]
    }
}
