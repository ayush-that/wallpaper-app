import Foundation

/// What rendering pipeline a wallpaper uses. Raw values are the on-disk
/// strings and are part of the persistence contract — never rename.
public enum WallpaperType: String, Codable, CaseIterable, Sendable {
    case image
    case gif
    case video
    case web
    case shader
    case urlPage = "url"
    case appWindow = "app"
}

/// Where this wallpaper came from. Raw values are on-disk strings.
public enum WallpaperImporterSource: String, Codable, Sendable {
    case native
    case lively
    case wallpaperEngine
}
