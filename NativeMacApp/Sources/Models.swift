import AppKit
import Foundation

enum PushToTalkTriggerKind: String, Codable {
    case keyboard
    case mouse
}

struct PushToTalkBinding: Codable, Hashable {
    var kind: PushToTalkTriggerKind = .keyboard
    var keyCode: UInt16 = 56
    var modifiersRawValue: UInt = 0
    var mouseButton: Int?

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    init(
        kind: PushToTalkTriggerKind = .keyboard,
        keyCode: UInt16 = 56,
        modifiersRawValue: UInt = 0,
        mouseButton: Int? = nil
    ) {
        self.kind = kind
        self.keyCode = keyCode
        self.modifiersRawValue = modifiersRawValue
        self.mouseButton = mouseButton
    }
}

struct AudioDevice: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let channels: Int
    let default_samplerate: Int
}

struct BackendEnvelope<T: Decodable>: Decodable {
    let id: String?
    let ok: Bool
    let error: String?
    let traceback: String?
    let payload: T

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("id"))
        ok = try container.decode(Bool.self, forKey: DynamicCodingKey("ok"))
        error = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("error"))
        traceback = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("traceback"))
        payload = try T(from: decoder)
    }
}

struct PingResponse: Decodable {
    let state: BackendStateResponse
}

struct BackendStateResponse: Codable {
    let model: String
    let sample_rate: Int
    let input_device: Int?
}

struct DevicesResponse: Decodable {
    let devices: [AudioDevice]
}

struct ConfigureResponse: Decodable {
    let state: BackendStateResponse
}

struct EndRecordingResponse: Decodable {
    let text: String
    let empty: Bool
}

struct AppSettings: Codable {
    var selectedDeviceID: Int?
    var pushToTalkBinding: PushToTalkBinding = .init()
    var pasteIntoActiveField: Bool = true
    var showDiagnostics: Bool = false
    var launchAtLogin: Bool = true

    enum CodingKeys: String, CodingKey {
        case selectedDeviceID
        case pushToTalkBinding
        case pushToTalkKeyCode
        case pushToTalkModifiersRawValue
        case pasteIntoActiveField
        case showDiagnostics
        case launchAtLogin
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedDeviceID = try container.decodeIfPresent(Int.self, forKey: .selectedDeviceID)
        pasteIntoActiveField = try container.decodeIfPresent(Bool.self, forKey: .pasteIntoActiveField) ?? true
        showDiagnostics = try container.decodeIfPresent(Bool.self, forKey: .showDiagnostics) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true

        if let binding = try container.decodeIfPresent(PushToTalkBinding.self, forKey: .pushToTalkBinding) {
            pushToTalkBinding = binding
        } else {
            let legacyKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .pushToTalkKeyCode) ?? 56
            let legacyModifiers = try container.decodeIfPresent(UInt.self, forKey: .pushToTalkModifiersRawValue) ?? 0
            pushToTalkBinding = PushToTalkBinding(
                kind: .keyboard,
                keyCode: legacyKeyCode,
                modifiersRawValue: legacyModifiers,
                mouseButton: nil
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedDeviceID, forKey: .selectedDeviceID)
        try container.encode(pushToTalkBinding, forKey: .pushToTalkBinding)
        try container.encode(pasteIntoActiveField, forKey: .pasteIntoActiveField)
        try container.encode(showDiagnostics, forKey: .showDiagnostics)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
    }
}

struct PasteResult {
    let inserted: Bool
    let method: String
    let diagnostics: String
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
