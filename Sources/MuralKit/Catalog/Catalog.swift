import Foundation
import GRDB
import OSLog

/// SQLite-backed wallpaper catalog. Thread-safe via GRDB's `DatabaseQueue`.
/// The `dbq` is exposed so tests can introspect; production callers should
/// stick to the typed `upsert/fetch/all/delete` API.
public final class Catalog {
    private let log = Log.logger("Catalog")
    public let dbq: DatabaseQueue
    public let url: URL

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        dbq = try DatabaseQueue(path: url.path)
        var migrator = DatabaseMigrator()
        Migrations.register(&migrator)
        try migrator.migrate(dbq)
    }

    public func upsert(_ wallpaper: Wallpaper) throws {
        var record = try WallpaperRecord(wallpaper)
        try dbq.write { db in
            try record.save(db)
        }
    }

    public func fetch(id: UUID) throws -> Wallpaper? {
        try dbq.read { db in
            guard let record = try WallpaperRecord.fetchOne(db, key: id.uuidString) else {
                return nil
            }
            return try record.toModel()
        }
    }

    public func all() throws -> [Wallpaper] {
        try dbq.read { db in
            let records = try WallpaperRecord
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return try records.map { try $0.toModel() }
        }
    }

    public func delete(id: UUID) throws {
        _ = try dbq.write { db in
            try WallpaperRecord.deleteOne(db, key: id.uuidString)
        }
    }
}

public extension Catalog {
    func upsert(_ playlist: Playlist) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(playlist)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        try dbq.write { db in
            try db.execute(
                sql: """
                INSERT INTO playlist(id, name, json, enabled) VALUES(?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    json = excluded.json,
                    enabled = excluded.enabled
                """,
                arguments: [
                    playlist.id.uuidString,
                    playlist.name,
                    json,
                    playlist.enabled
                ]
            )
        }
    }

    func allPlaylists() throws -> [Playlist] {
        try dbq.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT json FROM playlist ORDER BY name"
            )
            return try rows.compactMap { row -> Playlist? in
                guard let json: String = row["json"] else { return nil }
                return try JSONDecoder().decode(Playlist.self, from: Data(json.utf8))
            }
        }
    }

    func deletePlaylist(id: UUID) throws {
        _ = try dbq.write { db in
            try db.execute(
                sql: "DELETE FROM playlist WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }
}
