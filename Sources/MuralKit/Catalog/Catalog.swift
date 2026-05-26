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
