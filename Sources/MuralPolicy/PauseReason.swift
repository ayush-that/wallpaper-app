import Foundation

/// Why a display's wallpaper is currently paused. Multiple reasons can be
/// active simultaneously (e.g. on-battery AND foreground-app-rule). A renderer
/// is paused if ANY reason is active and resumed only when ALL reasons clear.
///
/// Watcher modules (FullscreenWatcher, PowerWatcher, ForegroundAppWatcher,
/// RemoteSessionWatcher, PerformanceGovernor) push/pop reasons into
/// `PauseCoordinator`. The coordinator handles the actual renderer transitions.
public struct PauseReason: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let fullscreenOccluded = PauseReason(rawValue: 1 << 0)
    public static let onBattery = PauseReason(rawValue: 1 << 1)
    public static let lowPowerMode = PauseReason(rawValue: 1 << 2)
    public static let foregroundAppRule = PauseReason(rawValue: 1 << 3)
    public static let userPaused = PauseReason(rawValue: 1 << 4)
    public static let displayAsleep = PauseReason(rawValue: 1 << 5)
    public static let remoteSession = PauseReason(rawValue: 1 << 6)
    public static let thermalPressure = PauseReason(rawValue: 1 << 7)
}
