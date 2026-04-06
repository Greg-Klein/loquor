import SwiftUI

@main
struct SpeechToTextNativeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Loquor", systemImage: "waveform.and.mic") {
            ContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        WindowGroup("Loquor", id: "settings-window") {
            SettingsView()
                .environmentObject(appState)
        }
        .defaultSize(width: 520, height: 380)
    }
}
