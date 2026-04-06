// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpeechToTextNative",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SpeechToTextNative", targets: ["SpeechToTextNative"]),
    ],
    targets: [
        .executableTarget(
            name: "SpeechToTextNative",
            path: "Sources"
        ),
    ]
)
