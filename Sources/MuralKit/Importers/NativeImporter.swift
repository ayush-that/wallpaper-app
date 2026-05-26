import CoreGraphics
import Foundation
import OSLog

public enum NativeImporterError: Error, Equatable {
    case unsupportedExtension(String)
}

/// Imports a raw asset file (video, gif, image, html, shader) into the
/// library: copies the file into a fresh per-wallpaper directory, generates a
/// thumbnail when possible, and writes the `wallpaper.json` metadata. The
/// source file is left untouched so importing from `~/Downloads` doesn't
/// surprise the user.
public struct NativeImporter: Sendable {
    private let log = Log.logger("NativeImporter")
    public let libraryRoot: URL

    public init(libraryRoot: URL) {
        self.libraryRoot = libraryRoot
    }

    public func importFile(at source: URL) throws -> Wallpaper {
        let ext = source.pathExtension.lowercased()
        let type = try Self.inferType(extension: ext)

        try LibraryRoot.ensureExists(root: libraryRoot)
        let id = UUID()
        let packageRoot = LibraryRoot.packageURL(root: libraryRoot, id: id)
        try FileManager.default.createDirectory(at: packageRoot, withIntermediateDirectories: true)

        let entryName = "asset.\(ext)"
        let entryDest = packageRoot.appendingPathComponent(entryName)
        try FileManager.default.copyItem(at: source, to: entryDest)

        let thumbDest = packageRoot.appendingPathComponent("thumbnail.png")
        let thumbSize = CGSize(width: 256, height: 144)
        switch type {
        case .video:
            try? ThumbnailRenderer.render(videoURL: entryDest, to: thumbDest, size: thumbSize)
        case .image, .gif:
            try? ThumbnailRenderer.render(imageURL: entryDest, to: thumbDest, size: thumbSize)
        case .shader:
            if let placeholder = Bundle.main.url(
                forResource: "shader-placeholder",
                withExtension: "png",
                subdirectory: "Resources/thumbnails"
            ) ?? Bundle.main.url(forResource: "shader-placeholder", withExtension: "png") {
                try? FileManager.default.copyItem(at: placeholder, to: thumbDest)
            }
        case .web, .urlPage, .appWindow:
            // No default thumbnail for these types — Phase 12 ships placeholders.
            break
        }

        let title = source.deletingPathExtension().lastPathComponent
        let wallpaper = Wallpaper(
            id: id,
            title: title,
            type: type,
            entryRelativePath: entryName,
            sourceImporter: .native
        )
        try WallpaperPackage(root: packageRoot).writeMetadata(wallpaper)
        log.info("imported \(wallpaper.id.uuidString, privacy: .public) type=\(type.rawValue, privacy: .public)")
        return wallpaper
    }

    /// Map a lowercased file extension to a `WallpaperType`. Throws
    /// `NativeImporterError.unsupportedExtension` for anything unknown.
    public static func inferType(extension ext: String) throws -> WallpaperType {
        switch ext {
        case "mp4", "mov", "m4v", "webm", "mkv", "avi", "ogv":
            return .video
        case "gif":
            return .gif
        case "png", "jpg", "jpeg", "heic", "webp", "bmp":
            return .image
        case "html", "htm":
            return .web
        case "glsl", "metal":
            return .shader
        default:
            throw NativeImporterError.unsupportedExtension(ext)
        }
    }
}
