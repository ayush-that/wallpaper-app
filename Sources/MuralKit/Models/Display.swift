import AppKit

/// A snapshot of a connected display. The `uuid` is stable across hotplug;
/// `cgID` and `bounds` are snapshots and may be stale on reconfig.
/// Persistence layers should store `uuid` only and reconstruct via
/// `Display(screen:)` on load.
public struct Display: Equatable, Hashable, Sendable {
    public let uuid: String
    public let cgID: UInt32 // CGDirectDisplayID at snapshot time
    /// Display bounds at snapshot time. Stale after `didChangeScreenParameters`
    /// — re-look up via `Display(screen:)` rather than caching.
    public let bounds: CGRect

    public init?(screen: NSScreen) {
        guard let uuid = DisplayUUID.from(screen: screen),
              let cgID = DisplayUUID.cgDisplayID(for: screen)
        else { return nil }
        self.uuid = uuid
        self.cgID = cgID
        bounds = screen.frame
    }

    public static func == (lhs: Display, rhs: Display) -> Bool {
        lhs.uuid == rhs.uuid
    }

    public func hash(into h: inout Hasher) {
        h.combine(uuid)
    }
}
