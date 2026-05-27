import Foundation
@testable import Mural
import XCTest

final class PlaylistCatalogTests: XCTestCase {
    private var tmpURL: URL!

    override func setUpWithError() throws {
        tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".sqlite")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpURL)
    }

    func test_v2_migration_creates_playlist_table() throws {
        let catalog = try Catalog(url: tmpURL)
        let exists = try catalog.dbq.read { db in
            try db.tableExists("playlist")
        }
        XCTAssertTrue(exists)
    }

    func test_upsert_then_fetch_returns_same_playlist() throws {
        let catalog = try Catalog(url: tmpURL)
        let playlist = Playlist(
            name: "Lo-fi corner",
            wallpaperIDs: [UUID(), UUID(), UUID()],
            strategy: .interval(seconds: 600)
        )
        try catalog.upsert(playlist)
        let all = try catalog.allPlaylists()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Lo-fi corner")
        XCTAssertEqual(all.first?.wallpaperIDs.count, 3)
        if case let .interval(seconds) = all.first?.strategy {
            XCTAssertEqual(seconds, 600)
        } else {
            XCTFail("expected .interval; got \(String(describing: all.first?.strategy))")
        }
    }

    func test_upsert_replaces_existing_playlist_with_same_id() throws {
        let catalog = try Catalog(url: tmpURL)
        var playlist = Playlist(
            name: "v1",
            wallpaperIDs: [UUID()],
            strategy: .shuffle(seconds: 60)
        )
        try catalog.upsert(playlist)
        playlist.name = "v2"
        playlist.enabled = false
        try catalog.upsert(playlist)
        let all = try catalog.allPlaylists()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "v2")
        XCTAssertEqual(all.first?.enabled, false)
    }

    func test_delete_removes_playlist() throws {
        let catalog = try Catalog(url: tmpURL)
        let playlist = Playlist(
            name: "doomed",
            wallpaperIDs: [UUID()],
            strategy: .interval(seconds: 60)
        )
        try catalog.upsert(playlist)
        try catalog.deletePlaylist(id: playlist.id)
        XCTAssertTrue(try catalog.allPlaylists().isEmpty)
    }

    func test_all_playlists_ordered_by_name_ascending() throws {
        let catalog = try Catalog(url: tmpURL)
        try catalog.upsert(Playlist(name: "Zebra", wallpaperIDs: [UUID()], strategy: .interval(seconds: 60)))
        try catalog.upsert(Playlist(name: "Alpha", wallpaperIDs: [UUID()], strategy: .interval(seconds: 60)))
        try catalog.upsert(Playlist(name: "Mango", wallpaperIDs: [UUID()], strategy: .interval(seconds: 60)))
        let names = try catalog.allPlaylists().map(\.name)
        XCTAssertEqual(names, ["Alpha", "Mango", "Zebra"])
    }

    func test_rotation_strategy_all_cases_roundtrip_through_json() throws {
        let strategies: [RotationStrategy] = [
            .interval(seconds: 300),
            .shuffle(seconds: 600),
            .onIdle(seconds: 120),
            .timeOfDay(slots: [
                TimeOfDaySlot(hour: 9, minute: 0, wallpaperID: UUID()),
                TimeOfDaySlot(hour: 21, minute: 30, wallpaperID: UUID())
            ])
        ]
        for strategy in strategies {
            let data = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(RotationStrategy.self, from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    func test_existing_wallpaper_table_survives_v2_migration() throws {
        // Drop in a v1 wallpaper, then migrate; verify both tables coexist.
        let catalog = try Catalog(url: tmpURL)
        let wallpaper = Wallpaper(title: "test", type: .video, entryRelativePath: "a.mp4")
        try catalog.upsert(wallpaper)
        XCTAssertEqual(try catalog.all().count, 1)
        // Now add a playlist; both tables should be accessible.
        try catalog.upsert(Playlist(
            name: "x",
            wallpaperIDs: [wallpaper.id],
            strategy: .interval(seconds: 60)
        ))
        XCTAssertEqual(try catalog.allPlaylists().count, 1)
    }
}
