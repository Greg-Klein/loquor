import Foundation

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
    var pushToTalkKeyCode: UInt16 = 56
    var pushToTalkModifiersRawValue: UInt = 0
    var pasteIntoActiveField: Bool = true
    var showDiagnostics: Bool = false
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
