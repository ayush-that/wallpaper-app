import AppKit
import Foundation

public enum RendererFactoryError: Error, Equatable {
    case unsupportedType(WallpaperType)
}

/// Maps a `Wallpaper` to the concrete renderer that should draw it. Resolves
/// the entry asset against the package root and constructs the right renderer
/// for the wallpaper's `type`. Types whose real renderers ship in later phases
/// (web, shader, gif, urlPage, appWindow) currently return a dark-grey
/// `SolidColorRenderer` placeholder so the library remains a usable chooser.
public enum RendererFactory {
    @MainActor
    public static func makeRenderer(
        for wallpaper: Wallpaper,
        package: WallpaperPackage,
        scaleMode: ScaleMode
    ) throws -> WallpaperRenderer {
        let entry = package.root.appendingPathComponent(wallpaper.entryRelativePath)
        switch wallpaper.type {
        case .video:
            return try VideoRenderer(asset: VideoAsset(url: entry), scaleMode: scaleMode)
        case .image:
            return ImageRenderer(url: entry, scaleMode: scaleMode)
        case .gif, .web, .shader, .urlPage, .appWindow:
            // Placeholder until later phases ship real renderers.
            return SolidColorRenderer(color: NSColor(deviceWhite: 0.1, alpha: 1))
        }
    }
}
