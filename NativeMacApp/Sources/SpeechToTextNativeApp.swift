import AppKit
import SwiftUI

@main
struct SpeechToTextNativeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            MenuBarIconView()
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

private struct MenuBarIconView: View {
    var body: some View {
        if let icon = appIcon {
            Image(nsImage: icon)
                .renderingMode(.original)
        } else {
            Image(systemName: "waveform.and.mic")
        }
    }

    private var appIcon: NSImage? {
        guard let image = NSApp.applicationIconImage, image.isValid else { return nil }
        let icon = image.copy() as? NSImage
        icon?.size = NSSize(width: 18, height: 18)
        return icon
    }
}
