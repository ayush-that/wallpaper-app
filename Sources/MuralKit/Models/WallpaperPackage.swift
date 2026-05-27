import Foundation

public enum WallpaperPackageError: Error, Equatable {
    case metadataMissing(URL)
    case metadataUnreadable(URL)
}

/// The on-disk layout of a single wallpaper. Each instance points at a directory
/// containing a `wallpaper.json` plus the entry asset, thumbnail, and optional
/// preview gif. Importers write packages; renderers and the SwiftUI library read them.
public struct WallpaperPackage: Sendable {
    public let root: URL
    private static let metadataName = "wallpaper.json"

    public init(root: URL) {
        self.root = root
    }

    public var metadataURL: URL {
        root.appendingPathComponent(Self.metadataName)
    }

    public func writeMetadata(_ wallpaper: Wallpaper) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(wallpaper)
        try data.write(to: metadataURL, options: .atomic)
    }

    public func readMetadata() throws -> Wallpaper {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw WallpaperPackageError.metadataMissing(metadataURL)
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            return try JSONDecoder().decode(Wallpaper.self, from: data)
        } catch {
            throw WallpaperPackageError.metadataUnreadable(metadataURL)
        }
    }

    /// Returns the URL of the entry asset (resolved against `root` using
    /// `Wallpaper.entryRelativePath`). Reads metadata each call — callers that
    /// hot-loop should cache.
    public func entryURL() throws -> URL {
        let metadata = try readMetadata()
        return root.appendingPathComponent(metadata.entryRelativePath)
    }

    public func thumbnailURL() throws -> URL {
        let metadata = try readMetadata()
        return root.appendingPathComponent(metadata.thumbnailRelativePath)
    }

    public func previewURL() throws -> URL? {
        let metadata = try readMetadata()
        guard let rel = metadata.previewRelativePath else { return nil }
        return root.appendingPathComponent(rel)
    }
}

public extension WallpaperPackage {
    /// URL of the optional `LivelyProperties.json` next to `wallpaper.json`.
    /// Returns the URL regardless of whether the file exists.
    var propertiesURL: URL {
        root.appendingPathComponent("LivelyProperties.json")
    }

    /// Decode the wallpaper's customization controls. Returns nil when the
    /// file is absent (most wallpapers don't ship one). Throws on parse errors.
    func readProperties() throws -> [PropertyControl]? {
        let url = propertiesURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try LivelyPropertiesCodec.decode(data)
    }
}
