import Foundation

/// A user-defined rotation of wallpapers. Persisted in the SQLite catalog
/// alongside individual `Wallpaper` records. The scheduler observes one
/// enabled playlist at a time (multi-playlist arbitration is a Phase 11
/// settings polish).
public struct Playlist: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var wallpaperIDs: [UUID]
    public var strategy: RotationStrategy
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        wallpaperIDs: [UUID],
        strategy: RotationStrategy,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.wallpaperIDs = wallpaperIDs
        self.strategy = strategy
        self.enabled = enabled
    }
}
