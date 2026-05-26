import Foundation
import GRDB
@testable import Mural
import XCTest

final class CatalogTests: XCTestCase {
    private var tmpURL: URL!

    override func setUpWithError() throws {
        tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".sqlite")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpURL)
    }

    func test_migration_creates_wallpaper_table() throws {
        let catalog = try Catalog(url: tmpURL)
        let exists = try catalog.dbq.read { db in
            try db.tableExists("wallpaper")
        }
        XCTAssertTrue(exists)
    }

    func test_insert_then_fetch_by_id() throws {
        let catalog = try Catalog(url: tmpURL)
        let wallpaper = Wallpaper(title: "Rain", type: .video, entryRelativePath: "a.mp4")
        try catalog.upsert(wallpaper)
        let fetched = try catalog.fetch(id: wallpaper.id)
        XCTAssertEqual(fetched?.title, "Rain")
        XCTAssertEqual(fetched?.id, wallpaper.id)
        XCTAssertEqual(fetched?.type, .video)
    }

    func test_fetch_unknown_id_returns_nil() throws {
        let catalog = try Catalog(url: tmpURL)
        let fetched = try catalog.fetch(id: UUID())
        XCTAssertNil(fetched)
    }

    func test_upsert_replaces_existing_row() throws {
        let catalog = try Catalog(url: tmpURL)
        var wallpaper = Wallpaper(title: "v1", type: .image, entryRelativePath: "x.png")
        try catalog.upsert(wallpaper)
        wallpaper.title = "v2"
        try catalog.upsert(wallpaper)
        let fetched = try catalog.fetch(id: wallpaper.id)
        XCTAssertEqual(fetched?.title, "v2")
        XCTAssertEqual(try catalog.all().count, 1)
    }

    func test_all_returns_records_sorted_by_createdAt_descending() throws {
        let catalog = try Catalog(url: tmpURL)
        let earlier = Wallpaper(
            title: "earlier",
            type: .image,
            entryRelativePath: "a",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let later = Wallpaper(
            title: "later",
            type: .image,
            entryRelativePath: "b",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        try catalog.upsert(earlier)
        try catalog.upsert(later)
        let all = try catalog.all()
        XCTAssertEqual(all.map(\.title), ["later", "earlier"])
    }

    func test_delete_removes_row() throws {
        let catalog = try Catalog(url: tmpURL)
        let wallpaper = Wallpaper(title: "x", type: .image, entryRelativePath: "x")
        try catalog.upsert(wallpaper)
        try catalog.delete(id: wallpaper.id)
        XCTAssertNil(try catalog.fetch(id: wallpaper.id))
        XCTAssertEqual(try catalog.all().count, 0)
    }

    func test_round_trip_preserves_all_fields() throws {
        let catalog = try Catalog(url: tmpURL)
        let original = Wallpaper(
            title: "Full",
            author: "Anon",
            type: .web,
            entryRelativePath: "index.html",
            thumbnailRelativePath: "thumb.png",
            previewRelativePath: "preview.gif",
            tags: ["a", "b"],
            license: "MIT",
            sourceImporter: .native
        )
        try catalog.upsert(original)
        let fetched = try XCTUnwrap(try catalog.fetch(id: original.id))
        XCTAssertEqual(fetched, original)
    }

    func test_migrations_are_idempotent_on_reopen() throws {
        _ = try Catalog(url: tmpURL)
        _ = try Catalog(url: tmpURL)
        // Just verify no throws on second open.
    }
}
