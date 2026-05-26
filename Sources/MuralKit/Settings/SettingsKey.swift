import Foundation

public struct SettingsKey<Value: Codable & Sendable>: Sendable {
    public let name: String
    public let `default`: Value

    public init(name: String, default value: Value) {
        self.name = name
        self.default = value
    }
}

public extension SettingsKey where Value == Bool {
    static let launchAtLogin = SettingsKey<Bool>(name: "launchAtLogin", default: false)
    static let pauseOnBattery = SettingsKey<Bool>(name: "pauseOnBattery", default: true)
    static let pauseOnFullscreen = SettingsKey<Bool>(name: "pauseOnFullscreen", default: true)
    static let pauseOnLowPowerMode = SettingsKey<Bool>(name: "pauseOnLowPowerMode", default: true)
    static let muteWallpaperAudio = SettingsKey<Bool>(name: "muteWallpaperAudio", default: true)
}
