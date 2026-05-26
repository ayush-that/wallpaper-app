import CoreGraphics
import Foundation
import OSLog

public enum PkgWallpaperImporterError: Error, Equatable {
    case missingProjectJson
    case unsupportedProjectType(String)
}

/// Imports a Wallpaper Engine-style `.pkg` archive into the library. The
/// archive is extracted into a fresh per-wallpaper directory, the manifest
/// (`project.json`) is parsed, and our own `wallpaper.json` is written. Only
/// `video` and `web` project types are supported in v1; `scene` and others are
/// rejected with `unsupportedProjectType` so the user gets a clear error.
public struct PkgWallpaperImporter {
    private let log = Log.logger("PkgWallpaperImporter")
    public let libraryRoot: URL

    public init(libraryRoot: URL) {
        self.libraryRoot = libraryRoot
    }

    public func importArchive(at pkgURL: URL) throws -> Wallpaper {
        try LibraryRoot.ensureExists(root: libraryRoot)
        let id = UUID()
        let packageRoot = LibraryRoot.packageURL(root: libraryRoot, id: id)
        try FileManager.default.createDirectory(at: packageRoot, withIntermediateDirectories: true)

        // Extract every entry from the .pkg into packageRoot.
        let archive = try PkgArchive(url: pkgURL)
        try archive.extractAll(to: packageRoot)

        // Parse project.json.
        let projectURL = packageRoot.appendingPathComponent("project.json")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw PkgWallpaperImporterError.missingProjectJson
        }
        let project = try JSONDecoder().decode(PkgProject.self, from: Data(contentsOf: projectURL))

        let type: WallpaperType
        switch project.type.lowercased() {
        case "video": type = .video
        case "web": type = .web
        default:
            throw PkgWallpaperImporterError.unsupportedProjectType(project.type)
        }

        // Synthesise thumbnail from the entry asset where possible. Failures
        // are non-fatal: a missing thumbnail is preferable to a failed import.
        let thumbName = "thumbnail.png"
        let thumbDest = packageRoot.appendingPathComponent(thumbName)
        let entryURL = packageRoot.appendingPathComponent(project.file)
        let thumbSize = CGSize(width: 256, height: 144)
        switch type {
        case .video:
            try? ThumbnailRenderer.render(videoURL: entryURL, to: thumbDest, size: thumbSize)
        case .image, .gif:
            try? ThumbnailRenderer.render(imageURL: entryURL, to: thumbDest, size: thumbSize)
        case .web, .shader, .urlPage, .appWindow:
            break
        }

        let title = project.title?.isEmpty == false
            ? project.title!
            : pkgURL.deletingPathExtension().lastPathComponent

        let wallpaper = Wallpaper(
            id: id,
            title: title,
            type: type,
            entryRelativePath: project.file,
            thumbnailRelativePath: thumbName,
            sourceImporter: .wallpaperEngine
        )
        try WallpaperPackage(root: packageRoot).writeMetadata(wallpaper)
        log.info("imported \(wallpaper.id.uuidString, privacy: .public) type=\(type.rawValue, privacy: .public)")
        return wallpaper
    }
}
