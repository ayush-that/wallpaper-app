import Foundation
import GRDB

/// SQLite row for one wallpaper. We store the full JSON-encoded `Wallpaper`
/// in a `json` column so we can add new optional fields to the model without
/// schema migrations. The other columns are indexed lookups.
struct WallpaperRecord: Codable, FetchableRecord, MutablePersistableRecord {
    var id: String
    var title: String
    var author: String
    var type: String
    var json: String
    var createdAt: Date

    static let databaseTableName = "wallpaper"

    init(_ wallpaper: Wallpaper) throws {
        id = wallpaper.id.uuidString
        title = wallpaper.title
        author = wallpaper.author
        type = wallpaper.type.rawValue
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(wallpaper)
        json = String(data: data, encoding: .utf8) ?? "{}"
        createdAt = wallpaper.createdAt
    }

    func toModel() throws -> Wallpaper {
        try JSONDecoder().decode(Wallpaper.self, from: Data(json.utf8))
    }
}
