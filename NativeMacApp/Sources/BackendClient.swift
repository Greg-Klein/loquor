import Foundation

enum BackendError: Error, LocalizedError {
    case pythonNotFound(String)
    case backendExited
    case malformedResponse
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python backend not found at \(path)"
        case .backendExited:
            return "The Python backend exited unexpectedly."
        case .malformedResponse:
            return "Malformed response from Python backend."
        case .backendFailure(let message):
            return message
        }
    }
}

final class BackendClient: @unchecked Sendable {
    private let decoder = JSONDecoder()
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private var buffer = Data()
    private var errorBuffer = Data()
    private var lastErrorOutput = ""
    private var continuations: [String: CheckedContinuation<Data, Error>] = [:]
    private let queue = DispatchQueue(label: "SpeechToTextNative.Backend")

    func start() throws {
        let runtime = Self.runtimeConfiguration()
        let pythonPath = runtime.pythonPath
        guard FileManager.default.fileExists(atPath: pythonPath.path) else {
            throw BackendError.pythonNotFound(pythonPath.path)
        }

        process.executableURL = pythonPath
        process.arguments = runtime.arguments
        process.currentDirectoryURL = runtime.workingDirectory
        process.environment = runtime.environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] _ in
            self?.failAll(BackendError.backendExited)
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data: data)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consumeError(data: data)
        }

        try process.run()
    }

    func stop() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
    }

    func ping() async throws -> BackendStateResponse {
        try await send(command: "ping", body: [:], as: PingResponse.self).state
    }

    func listDevices() async throws -> [AudioDevice] {
        try await send(command: "list_devices", body: [:], as: DevicesResponse.self).devices
    }

    func configure(deviceID: Int?) async throws {
        let _: ConfigureResponse = try await send(
            command: "configure",
            body: [
                "input_device": deviceID as Any,
                "sample_rate": 16_000,
                "model": "mlx-community/parakeet-tdt-0.6b-v3",
            ],
            as: ConfigureResponse.self
        )
    }

    func beginRecording() async throws {
        struct Empty: Decodable {}
        let _: Empty = try await send(command: "begin_recording", body: [:], as: Empty.self)
    }

    func endRecording() async throws -> EndRecordingResponse {
        try await send(command: "end_recording", body: [:], as: EndRecordingResponse.self)
    }

    private func send<T: Decodable>(command: String, body: [String: Any], as _: T.Type) async throws -> T {
        let id = UUID().uuidString
        let request = ["id": id, "command": command].merging(body) { _, new in new }
        let payload = try JSONSerialization.data(withJSONObject: request, options: [])

        let responseData: Data = try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.continuations[id] = continuation
                self.inputPipe.fileHandleForWriting.write(payload)
                self.inputPipe.fileHandleForWriting.write(Data([0x0A]))
            }
        }

        return try responseData.decode(type: T.self, using: decoder)
    }

    private func consume(data: Data) {
        queue.async {
            self.buffer.append(data)
            while let newline = self.buffer.firstIndex(of: 0x0A) {
                let line = self.buffer[..<newline]
                self.buffer.removeSubrange(...newline)
                guard !line.isEmpty else { continue }
                self.resolveLine(Data(line))
            }
        }
    }

    private func consumeError(data: Data) {
        queue.async {
            self.errorBuffer.append(data)
            if let text = String(data: self.errorBuffer, encoding: .utf8) {
                self.lastErrorOutput = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.errorBuffer.removeAll(keepingCapacity: true)
            }
        }
    }

    private func resolveLine(_ data: Data) {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = root["id"] as? String,
            let continuation = continuations.removeValue(forKey: id)
        else {
            return
        }

        if let ok = root["ok"] as? Bool, ok == false {
            let message = (root["error"] as? String) ?? "Unknown backend error"
            let traceback = (root["traceback"] as? String) ?? ""
            let stderr = lastErrorOutput
            let details = [message, traceback, stderr].filter { !$0.isEmpty }.joined(separator: "\n\n")
            continuation.resume(throwing: BackendError.backendFailure(details))
            return
        }

        continuation.resume(returning: data)
    }

    private func failAll(_ error: Error) {
        queue.async {
            let current = self.continuations
            self.continuations.removeAll()
            for (_, continuation) in current {
                if let backendError = error as? BackendError, case .backendExited = backendError, !self.lastErrorOutput.isEmpty {
                    continuation.resume(throwing: BackendError.backendFailure(self.lastErrorOutput))
                } else {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runtimeConfiguration() -> RuntimeConfiguration {
        let bundleResources = Bundle.main.resourceURL
        if let bundleResources {
            let bundledPython = bundleResources.appending(path: "python/bin/python")
            let bundledBackendRoot = bundleResources.appending(path: "backend")
            if FileManager.default.fileExists(atPath: bundledPython.path) {
                var environment = ProcessInfo.processInfo.environment
                let backendSrc = bundledBackendRoot.appending(path: "src").path
                environment["PYTHONPATH"] = backendSrc
                return RuntimeConfiguration(
                    pythonPath: bundledPython,
                    arguments: ["-m", "speech_to_text.backend_service"],
                    workingDirectory: bundledBackendRoot,
                    environment: environment
                )
            }
        }

        let repoRoot = repoRoot()
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = repoRoot.appending(path: "src").path
        return RuntimeConfiguration(
            pythonPath: repoRoot.appending(path: ".venv/bin/python"),
            arguments: ["-m", "speech_to_text.backend_service"],
            workingDirectory: repoRoot,
            environment: environment
        )
    }

    private static func repoRoot() -> URL {
        let cwd = URL(filePath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwd.appending(path: "pyproject.toml").path) {
            return cwd
        }
        return URL(fileURLWithPath: "/Users/gregoryklein/workspace/speech-to-text")
    }
}

private struct RuntimeConfiguration {
    let pythonPath: URL
    let arguments: [String]
    let workingDirectory: URL
    let environment: [String: String]
}

private extension Data {
    func decode<T: Decodable>(type: T.Type, using decoder: JSONDecoder) throws -> T {
        let envelope = try decoder.decode(BackendEnvelope<T>.self, from: self)
        if envelope.ok {
            return envelope.payload
        }
        throw BackendError.backendFailure(envelope.error ?? "Unknown backend error")
    }
}
