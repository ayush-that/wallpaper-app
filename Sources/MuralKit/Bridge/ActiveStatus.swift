import Foundation

/// Per-display snapshot of which wallpaper is active, written atomically to
/// `~/Library/Application Support/Mural/active.json` whenever the
/// `WallpaperEngine` changes a renderer's wallpaper. Separate processes
/// (screensaver bundle, future Spotlight integration) read this file to
/// mirror the user's chosen wallpaper.
public struct ActiveStatus: Codable, Equatable, Sendable {
    public struct PerDisplay: Codable, Equatable, Sendable {
        public let displayUUID: String
        public let wallpaperID: UUID

        public init(displayUUID: String, wallpaperID: UUID) {
            self.displayUUID = displayUUID
            self.wallpaperID = wallpaperID
        }
    }

    public var displays: [PerDisplay]
    public var libraryRoot: String
    public var updatedAt: Date

    public init(displays: [PerDisplay], libraryRoot: String, updatedAt: Date = Date()) {
        self.displays = displays
        self.libraryRoot = libraryRoot
        self.updatedAt = updatedAt
    }

    public static let filename = "active.json"

    public static func defaultURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mural/\(filename)")
    }

    /// Atomic write: readers see either the old or new contents, never partial.
    public static func write(_ status: ActiveStatus, to url: URL = defaultURL()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(status)
        try data.write(to: url, options: .atomic)
    }

    /// Returns nil if the file doesn't exist; throws on parse errors.
    public static func read(from url: URL = defaultURL()) throws -> ActiveStatus? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ActiveStatus.self, from: Data(contentsOf: url))
    }
}
