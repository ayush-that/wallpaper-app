import Foundation

/// Codable manifest for the third-party animated-wallpaper bundle format
/// (a.k.a. `LivelyInfo.json`). The JSON wire format uses Capitalised keys
/// produced by the upstream Lively Wallpaper ecosystem; we map them to
/// idiomatic Swift property names via `CodingKeys`. The wire format must
/// not change — renaming the JSON keys would break compatibility with
/// bundles users may want to import.
public struct ZipBundleManifest: Decodable, Sendable {
    public let appVersion: String?
    public let title: String
    public let thumbnail: String?
    public let preview: String?
    public let desc: String?
    public let author: String?
    public let license: String?
    public let type: Int
    public let fileName: String
    public let tags: [String]?

    private enum CodingKeys: String, CodingKey {
        case appVersion = "AppVersion"
        case title = "Title"
        case thumbnail = "Thumbnail"
        case preview = "Preview"
        case desc = "Desc"
        case author = "Author"
        case license = "License"
        case type = "Type"
        case fileName = "FileName"
        case tags = "Tags"
    }
}
