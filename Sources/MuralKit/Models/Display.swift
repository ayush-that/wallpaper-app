import AppKit

public struct Display: Equatable, Hashable, Codable, Sendable {
    public let uuid: String
    public let cgID: UInt32 // CGDirectDisplayID at snapshot time
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
