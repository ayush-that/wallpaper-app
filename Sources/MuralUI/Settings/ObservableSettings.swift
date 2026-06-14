import Combine
import Foundation
import OSLog

@MainActor
public final class ObservableSettings: ObservableObject {
    private let log = Log.logger("Settings")
    private let store: SettingsStore
    private let propagateToLoginItem: Bool

    @Published public var launchAtLogin: Bool {
        didSet {
            store.set(.launchAtLogin, launchAtLogin)
            if propagateToLoginItem {
                LoginItemController.shared.setEnabled(launchAtLogin)
            }
        }
    }

    @Published public var pauseOnFullscreen: Bool {
        didSet { store.set(.pauseOnFullscreen, pauseOnFullscreen) }
    }

    @Published public var pauseOnBattery: Bool {
        didSet { store.set(.pauseOnBattery, pauseOnBattery) }
    }

    @Published public var pauseOnLowPowerMode: Bool {
        didSet { store.set(.pauseOnLowPowerMode, pauseOnLowPowerMode) }
    }

    @Published public var muteWallpaperAudio: Bool {
        didSet { store.set(.muteWallpaperAudio, muteWallpaperAudio) }
    }

    /// Whether system-audio capture is currently running for audio-reactive
    /// wallpapers. Intentionally session state, not persisted: starting capture
    /// hits a TCC-gated ScreenCaptureKit API that, in Debug builds, re-prompts
    /// for Screen Recording on every rebuild (the cdhash changes), so we never
    /// auto-start at launch. It defaults to off each session and the user opts
    /// in via the Settings toggle, which drives `onAudioReactiveChange`.
    @Published public var audioReactive: Bool = false {
        didSet {
            guard audioReactive != oldValue else { return }
            onAudioReactiveChange(audioReactive)
        }
    }

    /// Invoked when `audioReactive` flips. `AppDelegate` wires this to the
    /// orchestrator's `enableAudio()` / `disableAudio()`. The callback may set
    /// `audioReactive` back to `false` if capture fails to start (e.g. the
    /// Screen Recording permission was declined) so the toggle reflects reality.
    public var onAudioReactiveChange: (Bool) -> Void = { _ in }

    /// `propagateToLoginItem` exists so tests can opt out of the real
    /// `SMAppService.register()` side effect that would otherwise install the
    /// test runner as a login item. Production code uses the default `true`.
    public init(store: SettingsStore = SettingsStore(), propagateToLoginItem: Bool = true) {
        self.store = store
        self.propagateToLoginItem = propagateToLoginItem
        // Seed from disk. Reading published properties before they have been
        // assigned would trip stored-property initialisation ordering; just
        // load each value into a local and assign in one swoop.
        let initialLaunchAtLogin = store.get(.launchAtLogin)
        let initialPauseOnFullscreen = store.get(.pauseOnFullscreen)
        let initialPauseOnBattery = store.get(.pauseOnBattery)
        let initialPauseOnLowPowerMode = store.get(.pauseOnLowPowerMode)
        let initialMuteWallpaperAudio = store.get(.muteWallpaperAudio)
        launchAtLogin = initialLaunchAtLogin
        pauseOnFullscreen = initialPauseOnFullscreen
        pauseOnBattery = initialPauseOnBattery
        pauseOnLowPowerMode = initialPauseOnLowPowerMode
        muteWallpaperAudio = initialMuteWallpaperAudio
    }
}
