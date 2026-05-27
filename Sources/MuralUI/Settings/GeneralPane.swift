import SwiftUI

public struct GeneralPane: View {
    @ObservedObject public var settings: ObservableSettings

    public init(settings: ObservableSettings) {
        self.settings = settings
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
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}
