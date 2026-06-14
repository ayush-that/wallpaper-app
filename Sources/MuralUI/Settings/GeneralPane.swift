import SwiftUI

public struct GeneralPane: View {
    @ObservedObject public var settings: ObservableSettings
    @ObservedObject public var updateManager: UpdateManager

    public init(settings: ObservableSettings, updateManager: UpdateManager) {
        self.settings = settings
        self.updateManager = updateManager
    }

    public var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }
            Section("Pause when") {
                Toggle("A fullscreen app is on the display", isOn: $settings.pauseOnFullscreen)
                Toggle("Running on battery", isOn: $settings.pauseOnBattery)
                Toggle("Low Power Mode is on", isOn: $settings.pauseOnLowPowerMode)
            }
            Section("Audio") {
                Toggle("Mute wallpaper audio", isOn: $settings.muteWallpaperAudio)
                Toggle("Audio-reactive wallpapers", isOn: $settings.audioReactive)
                Text("Lets web wallpapers react to system audio. Requires Screen "
                    + "Recording permission and resets each time you quit Mural.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updateManager.automaticallyChecksForUpdates)
                Button("Check Now…") { updateManager.checkNow() }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}
