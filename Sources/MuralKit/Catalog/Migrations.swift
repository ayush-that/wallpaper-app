import GRDB

enum Migrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_wallpaper_table") { db in
            try db.create(table: "wallpaper") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("author", .text).notNull().defaults(to: "")
                t.column("type", .text).notNull()
                t.column("json", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(
                index: "wallpaper_createdAt_idx",
                on: "wallpaper",
                columns: ["createdAt"]
            )
        }

        migrator.registerMigration("v2_playlist_table") { db in
            try db.create(table: "playlist") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("json", .text).notNull() // full Playlist Codable blob
                t.column("enabled", .boolean).notNull()
            }
        }
    }
}
