import Foundation

/// Pure-function helpers for resolving Mural's library directory and the
/// canonical paths within it. Stateless; no I/O on its own apart from
/// `ensureExists(root:)`.
public enum LibraryRoot {
    /// Canonical library location for production: ~/Library/Application Support/Mural/library/
    public static func defaultURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mural/library", isDirectory: true)
    }

    /// Directory holding one wallpaper's metadata + assets, named by UUID.
    public static func packageURL(root: URL, id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Catalog DB lives as a sibling of the library directory so it survives
    /// the library being wiped (and vice versa).
    public static func catalogURL(root: URL) -> URL {
        root.deletingLastPathComponent().appendingPathComponent("catalog.sqlite")
    }

    /// Create the library directory (and parents) if missing. Safe to call repeatedly.
    public static func ensureExists(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
}
