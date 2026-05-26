import CoreGraphics
import Foundation
import OSLog
import ZIPFoundation

public enum ZipWallpaperImporterError: Error, Equatable {
    case missingManifest
    case extractFailed(String)
}

/// Imports a third-party animated-wallpaper `.zip` bundle into the library.
/// The bundle contains a `LivelyInfo.json` manifest at the root plus the entry
/// asset, optional thumbnail, and optional preview gif. We unzip into a fresh
/// per-wallpaper directory, normalise the thumbnail filename, generate one
/// from the entry asset if missing, and write our own `wallpaper.json`. The
/// original manifest and asset filenames are left intact so re-exporting the
/// bundle remains lossless.
public struct ZipWallpaperImporter {
    private let log = Log.logger("ZipWallpaperImporter")
    public let libraryRoot: URL

    public init(libraryRoot: URL) {
        self.libraryRoot = libraryRoot
    }

    public func importArchive(at zipURL: URL) throws -> Wallpaper {
        try LibraryRoot.ensureExists(root: libraryRoot)
        let id = UUID()
        let packageRoot = LibraryRoot.packageURL(root: libraryRoot, id: id)
        try FileManager.default.createDirectory(at: packageRoot, withIntermediateDirectories: true)

        do {
            try FileManager.default.unzipItem(at: zipURL, to: packageRoot)
        } catch {
            throw ZipWallpaperImporterError.extractFailed(error.localizedDescription)
        }

        // The archive often nests its payload one folder deep; flatten so the
        // manifest is reliably at packageRoot/LivelyInfo.json.
        flattenSingleTopLevelFolder(in: packageRoot)

        let manifestURL = packageRoot.appendingPathComponent("LivelyInfo.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ZipWallpaperImporterError.missingManifest
        }
        let manifest = try JSONDecoder().decode(ZipBundleManifest.self, from: Data(contentsOf: manifestURL))
        let type = Self.mapType(manifest.type)
        let title = manifest.title.isEmpty ? zipURL.deletingPathExtension().lastPathComponent : manifest.title

        // Thumbnail handling: if the manifest names one, rename it on disk to
        // the canonical "thumbnail.png" so package layout stays uniform. If
        // still missing, try to synthesise from the entry asset.
        let thumbName = "thumbnail.png"
        let thumbDest = packageRoot.appendingPathComponent(thumbName)
        if let provided = manifest.thumbnail,
           !provided.isEmpty,
           provided != thumbName,
           FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(provided).path)
        {
            try? FileManager.default.moveItem(
                at: packageRoot.appendingPathComponent(provided),
                to: thumbDest
            )
        }
        if !FileManager.default.fileExists(atPath: thumbDest.path) {
            let entryURL = packageRoot.appendingPathComponent(manifest.fileName)
            let thumbSize = CGSize(width: 256, height: 144)
            switch type {
            case .video:
                try? ThumbnailRenderer.render(videoURL: entryURL, to: thumbDest, size: thumbSize)
            case .image, .gif:
                try? ThumbnailRenderer.render(imageURL: entryURL, to: thumbDest, size: thumbSize)
            case .web, .shader, .urlPage, .appWindow:
                break
            }
        }

        let wallpaper = Wallpaper(
            id: id,
            title: title,
            author: manifest.author ?? "",
            type: type,
            entryRelativePath: manifest.fileName,
            thumbnailRelativePath: thumbName,
            previewRelativePath: manifest.preview,
            tags: manifest.tags ?? [],
            license: manifest.license,
            sourceImporter: .lively
        )
        try WallpaperPackage(root: packageRoot).writeMetadata(wallpaper)
        log.info("imported \(wallpaper.id.uuidString, privacy: .public) type=\(type.rawValue, privacy: .public)")
        return wallpaper
    }

    /// Map the integer `Type` field to our `WallpaperType`. Codes come from
    /// the upstream bundle format spec; unknown values fall back to `.image`.
    public static func mapType(_ raw: Int) -> WallpaperType {
        switch raw {
        case 0: .image
        case 1: .video
        case 2, 5: .web
        case 3: .gif
        case 4, 6: .urlPage
        case 7, 8, 9, 10, 11: .appWindow
        case 12: .image
        default: .image
        }
    }

    /// If the zip extracted into a single nested folder, move its contents up
    /// one level so the manifest is at packageRoot.
    private func flattenSingleTopLevelFolder(in root: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]),
              contents.count == 1,
              (try? contents[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { return }
        let inner = contents[0]
        guard let inside = try? fm.contentsOfDirectory(at: inner, includingPropertiesForKeys: nil) else { return }
        for item in inside {
            try? fm.moveItem(at: item, to: root.appendingPathComponent(item.lastPathComponent))
        }
        try? fm.removeItem(at: inner)
    }
}
