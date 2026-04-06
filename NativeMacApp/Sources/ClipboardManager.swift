import AppKit
import ApplicationServices

enum ClipboardManager {
    struct Snapshot {
        let items: [[String: Data]]
    }

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func snapshot() -> Snapshot {
        let items = NSPasteboard.general.pasteboardItems?.compactMap { item -> [String: Data]? in
            var snapshotItem: [String: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                snapshotItem[type.rawValue] = data
            }
            return snapshotItem
        } ?? []
        return Snapshot(items: items)
    }

    static func restore(_ snapshot: Snapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        let restoredItems = snapshot.items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }

    static func activateAndInsert(_ text: String, into app: NSRunningApplication?) -> PasteResult {
        guard AXIsProcessTrusted() else {
            return PasteResult(
                inserted: false,
                method: "clipboard-only",
                diagnostics: "Accessibility permission is not granted to this app."
            )
        }

        if let app {
            app.activate(options: [.activateIgnoringOtherApps])
            Thread.sleep(forTimeInterval: 0.12)
        }
        let accessibilityAttempt = insertViaAccessibility(text, into: app)
        if accessibilityAttempt.inserted {
            return accessibilityAttempt
        }
        copy(text)
        pasteViaCommandV()
        return PasteResult(
            inserted: false,
            method: "cmd-v-fallback",
            diagnostics: accessibilityAttempt.diagnostics
        )
    }

    private static func pasteViaCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        commandDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }

    private static func insertViaAccessibility(_ text: String, into app: NSRunningApplication?) -> PasteResult {
        let focusedElementLookup = focusedElement(in: app)
        guard let focusedElement = focusedElementLookup.element else {
            return PasteResult(
                inserted: false,
                method: "accessibility",
                diagnostics: focusedElementLookup.diagnostics
            )
        }

        let replaceAttempt = replaceSelectedText(text, in: focusedElement)
        if replaceAttempt.success {
            return PasteResult(
                inserted: true,
                method: "accessibility-selected-range",
                diagnostics: replaceAttempt.diagnostics
            )
        }

        let setValueAttempt = setElementValue(text, element: focusedElement)
        if setValueAttempt.success {
            return PasteResult(
                inserted: true,
                method: "accessibility-set-value",
                diagnostics: setValueAttempt.diagnostics
            )
        }

        return PasteResult(
            inserted: false,
            method: "accessibility",
            diagnostics: [focusedElementLookup.diagnostics, replaceAttempt.diagnostics, setValueAttempt.diagnostics]
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
        )
    }

    private static func replaceSelectedText(_ text: String, in element: AXUIElement) -> (success: Bool, diagnostics: String) {
        guard
            let currentValue = copyStringAttribute(element: element, attribute: kAXValueAttribute as CFString),
            let selectedRangeValue = copyRangeAttribute(
                element: element,
                attribute: kAXSelectedTextRangeAttribute as CFString
            )
        else {
            return (false, "Focused element does not expose both AXValue and AXSelectedTextRange.")
        }

        let nsString = currentValue as NSString
        guard selectedRangeValue.location != NSNotFound else {
            return (false, "Focused element has no valid selected text range.")
        }

        let updatedValue = nsString.replacingCharacters(in: selectedRangeValue, with: text)
        let setValueAttempt = setElementValue(updatedValue, element: element)
        guard setValueAttempt.success else {
            return (false, "Could not replace selected text. \(setValueAttempt.diagnostics)")
        }

        let caretLocation = selectedRangeValue.location + (text as NSString).length
        let caretResult = setSelectedRange(
            NSRange(location: caretLocation, length: 0),
            element: element
        )
        if caretResult.success {
            return (true, "Replaced selected text and updated caret.")
        }
        return (true, "Replaced selected text, but could not update caret. \(caretResult.diagnostics)")
    }

    private static func setElementValue(_ text: String, element: AXUIElement) -> (success: Bool, diagnostics: String) {
        let settable = isAttributeSettable(element: element, attribute: kAXValueAttribute as CFString)
        guard settable.settable else {
            return (false, "AXValue is not settable. \(settable.diagnostics)")
        }
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return (
            result == .success,
            "Setting AXValue returned \(describe(result))."
        )
    }

    private static func setSelectedRange(_ range: NSRange, element: AXUIElement) -> (success: Bool, diagnostics: String) {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let axValue = AXValueCreate(.cfRange, &cfRange) else {
            return (false, "Could not create AXValue for selected range.")
        }
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            axValue
        )
        return (result == .success, "Setting AXSelectedTextRange returned \(describe(result)).")
    }

    private static func copyElementAttribute(element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyStringAttribute(element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return value as? String
    }

    private static func copyRangeAttribute(element: AXUIElement, attribute: CFString) -> NSRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }
        var cfRange = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &cfRange) else {
            return nil
        }
        return NSRange(location: cfRange.location, length: cfRange.length)
    }

    private static func focusedElement(in app: NSRunningApplication?) -> (element: AXUIElement?, diagnostics: String) {
        let systemWide = AXUIElementCreateSystemWide()
        if let element = copyElementAttribute(element: systemWide, attribute: kAXFocusedUIElementAttribute as CFString) {
            return (element, "Found focused UI element via system-wide accessibility.")
        }

        guard let app else {
            return (nil, "No target application captured and system-wide focused element lookup failed.")
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let element = copyElementAttribute(element: appElement, attribute: kAXFocusedUIElementAttribute as CFString) {
            return (element, "Found focused UI element via target application accessibility.")
        }

        return (nil, "Could not find focused UI element via system-wide or application-scoped accessibility.")
    }

    private static func isAttributeSettable(element: AXUIElement, attribute: CFString) -> (settable: Bool, diagnostics: String) {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        guard result == .success else {
            return (false, "AXUIElementIsAttributeSettable returned \(describe(result)).")
        }
        return (settable.boolValue, "Attribute settable check returned \(settable.boolValue).")
    }

    private static func describe(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown(\(error.rawValue))"
        }
    }
}
