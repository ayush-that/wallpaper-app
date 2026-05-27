import Foundation

/// Stable identifier for a particular set of attached displays. Two displays
/// in the same configuration (regardless of NSScreen ordering) produce the
/// same hash; adding or removing a display produces a different hash so
/// per-display property overrides can be scoped to the user's setup.
public struct DisplayArrangementHash: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(displayUUIDs: [String]) {
        rawValue = displayUUIDs.sorted().joined(separator: "+")
    }
}
