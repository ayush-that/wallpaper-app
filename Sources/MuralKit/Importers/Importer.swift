import Foundation

/// Routes an arbitrary user-provided file into the right type-specific importer.
/// Callers (drag-drop handlers, library UI, CLI) should always go through here
/// rather than instantiating individual importers.
public struct Importer: Sendable {
    public let libraryRoot: URL

    public init(libraryRoot: URL) {
        self.libraryRoot = libraryRoot
    }

    public func `import`(url: URL) throws -> Wallpaper {
        switch url.pathExtension.lowercased() {
        case "zip":
            try ZipWallpaperImporter(libraryRoot: libraryRoot).importArchive(at: url)
        case "pkg":
            try PkgWallpaperImporter(libraryRoot: libraryRoot).importArchive(at: url)
        default:
            try NativeImporter(libraryRoot: libraryRoot).importFile(at: url)
        }
    }
}
