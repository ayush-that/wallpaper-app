import Foundation

/// How a playlist advances from one wallpaper to the next.
public enum RotationStrategy: Codable, Equatable, Sendable {
    /// Advance through wallpapers in order, returning to the start after the last.
    /// `seconds` is the dwell time on each wallpaper.
    case interval(seconds: TimeInterval)

    /// Same as `.interval` but each cycle visits all wallpapers in a fresh
    /// random order before re-shuffling.
    case shuffle(seconds: TimeInterval)

    /// Advance only after the user has been idle for `seconds` (no keyboard /
    /// mouse activity). Useful for "screensaver while AFK" behavior.
    case onIdle(seconds: TimeInterval)

    /// Pick a wallpaper based on time of day. The scheduler chooses the slot
    /// whose `(hour, minute)` is closest to now.
    case timeOfDay(slots: [TimeOfDaySlot])

    /// Minimum dwell time in seconds. For `.timeOfDay` returns 60 (poll every minute).
    public var minIntervalSeconds: TimeInterval {
        switch self {
        case let .interval(seconds), let .shuffle(seconds), let .onIdle(seconds):
            seconds
        case .timeOfDay:
            60
        }
    }
}

public struct TimeOfDaySlot: Codable, Equatable, Sendable, Hashable {
    public var hour: Int // 0..23
    public var minute: Int // 0..59
    public var wallpaperID: UUID

    public init(hour: Int, minute: Int, wallpaperID: UUID) {
        self.hour = hour
        self.minute = minute
        self.wallpaperID = wallpaperID
    }
}
