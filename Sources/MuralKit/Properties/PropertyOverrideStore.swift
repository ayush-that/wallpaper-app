import Foundation
import OSLog

/// Persists per-display property overrides for each wallpaper. Files are
/// JSON dictionaries keyed by control name. Read/write is atomic so partial
/// writes never corrupt the store. The root directory defaults to
/// `~/Library/Application Support/Mural/properties/`; tests inject a tmpdir.
public final class PropertyOverrideStore {
    /// A flat map from control name to its current value, owned by exactly
    /// one (wallpaper, display, arrangement) tuple.
    public typealias Overrides = [String: WebBridgePropertyValue]

    private let log = Log.logger("PropertyOverrideStore")
    public let root: URL

    public init(
        root: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mural/properties")
    ) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// Returns the on-disk URL for a particular slice. Does NOT touch disk.
    public func url(
        wallpaperID: UUID,
        displayUUID: String,
        arrangement: DisplayArrangementHash
    ) -> URL {
        root
            .appendingPathComponent(wallpaperID.uuidString)
            .appendingPathComponent(arrangement.rawValue)
            .appendingPathComponent("\(displayUUID).json")
    }

    /// Read overrides for a slice. Missing files → empty dict, never throws.
    /// Corrupted files → empty dict + logged warning.
    public func read(
        wallpaperID: UUID,
        displayUUID: String,
        arrangement: DisplayArrangementHash
    ) -> Overrides {
        let location = url(
            wallpaperID: wallpaperID,
            displayUUID: displayUUID,
            arrangement: arrangement
        )
        guard let data = try? Data(contentsOf: location) else { return [:] }
        do {
            return try JSONDecoder().decode(Overrides.self, from: data)
        } catch {
            log.warning(
                "Corrupted overrides at \(location.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return [:]
        }
    }

    /// Atomic write — readers either see the previous content or the new
    /// content, never a partial JSON document.
    public func write(
        _ overrides: Overrides,
        wallpaperID: UUID,
        displayUUID: String,
        arrangement: DisplayArrangementHash
    ) throws {
        let location = url(
            wallpaperID: wallpaperID,
            displayUUID: displayUUID,
            arrangement: arrangement
        )
        try FileManager.default.createDirectory(
            at: location.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(overrides)
        try data.write(to: location, options: .atomic)
    }

    /// Convenience: set a single property without round-tripping the whole map
    /// manually. Read-modify-write under the hood.
    public func set(
        _ value: WebBridgePropertyValue,
        for controlName: String,
        wallpaperID: UUID,
        displayUUID: String,
        arrangement: DisplayArrangementHash
    ) throws {
        var current = read(
            wallpaperID: wallpaperID,
            displayUUID: displayUUID,
            arrangement: arrangement
        )
        current[controlName] = value
        try write(
            current,
            wallpaperID: wallpaperID,
            displayUUID: displayUUID,
            arrangement: arrangement
        )
    }
}
