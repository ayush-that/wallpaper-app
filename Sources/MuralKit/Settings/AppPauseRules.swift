import Foundation

/// A rule for pausing wallpapers when a specific app is in the foreground.
/// Bundle IDs are matched verbatim (case-sensitive, like AppKit reports them).
public struct AppPauseRule: Codable, Equatable, Hashable, Sendable {
    public var bundleID: String
    public var pauseAll: Bool // pause every display when this app is frontmost

    public init(bundleID: String, pauseAll: Bool = true) {
        self.bundleID = bundleID
        self.pauseAll = pauseAll
    }
}

/// Persistable collection of `AppPauseRule`s. Stored under `SettingsKey.appPauseRules`.
public struct AppPauseRules: Codable, Equatable, Sendable {
    public var rules: [AppPauseRule]

    public init(rules: [AppPauseRule] = []) {
        self.rules = rules
    }

    /// Returns the matching rule for the given bundle ID, or nil if no rule
    /// applies. nil-safe — calling with a `nil` bundleID is a no-op.
    public func match(bundleID: String?) -> AppPauseRule? {
        guard let bundleID else { return nil }
        return rules.first(where: { $0.bundleID == bundleID })
    }
}

public extension SettingsKey where Value == AppPauseRules {
    /// Default rules — common "I'm probably in a meeting / presentation" apps.
    /// Users can customise via Settings UI (Phase 11).
    static let appPauseRules = SettingsKey<AppPauseRules>(
        name: "appPauseRules",
        default: AppPauseRules(rules: [
            AppPauseRule(bundleID: "com.apple.QuickTimePlayerX"),
            AppPauseRule(bundleID: "com.apple.iWork.Keynote"),
            AppPauseRule(bundleID: "us.zoom.xos"),
            AppPauseRule(bundleID: "com.microsoft.teams2"),
            AppPauseRule(bundleID: "com.tinyspeck.slackmacgap"), // Slack
            AppPauseRule(bundleID: "com.hnc.Discord")
        ])
    )
}
