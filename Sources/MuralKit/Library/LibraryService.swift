import Foundation
import OSLog

/// The one object UI talks to. Composes `Importer` + `Catalog` + the filesystem
/// so the library view can `importFile`, `allWallpapers`, `package(for:)`, and
/// `remove(id:)`. Pinned to the main actor so concurrent access is impossible.
@MainActor
public final class LibraryService {
    private let log = Log.logger("LibraryService")
    public let libraryRoot: URL
    public let catalog: Catalog
    private let importer: Importer

    public init(libraryRoot: URL, catalog: Catalog) {
        self.libraryRoot = libraryRoot
        self.catalog = catalog
        importer = Importer(libraryRoot: libraryRoot)
    }

    @discardableResult
    public func importFile(at url: URL) throws -> Wallpaper {
        let wallpaper = try importer.import(url: url)
        try catalog.upsert(wallpaper)
        log.info("Imported \(wallpaper.id.uuidString, privacy: .public) (\(wallpaper.title, privacy: .public))")
        return wallpaper
    }

    public func allWallpapers() throws -> [Wallpaper] {
        try catalog.all()
    }

    /// Path-only — does not read the on-disk metadata. The package may not exist
    /// (e.g. after a partial remove); callers that need to read should wrap with try.
    public func package(for id: UUID) -> WallpaperPackage {
        WallpaperPackage(root: LibraryRoot.packageURL(root: libraryRoot, id: id))
    }

    public func remove(id: UUID) throws {
        try catalog.delete(id: id)
        let dir = LibraryRoot.packageURL(root: libraryRoot, id: id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }
}
