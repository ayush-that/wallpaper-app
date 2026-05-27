import Foundation
@testable import Mural
import XCTest

@MainActor
final class PlaylistsViewModelTests: XCTestCase {
    private var catalogURL: URL!
    private var catalog: Catalog!
    private var vm: PlaylistsViewModel!

    override func setUp() async throws {
        catalogURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".sqlite")
        catalog = try Catalog(url: catalogURL)
        vm = PlaylistsViewModel(catalog: catalog)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: catalogURL)
    }

    func test_initial_state_is_empty() {
        XCTAssertTrue(vm.playlists.isEmpty)
        XCTAssertNil(vm.lastError)
    }

    func test_save_inserts_then_refreshes() {
        let playlist = Playlist(
            name: "Calm",
            wallpaperIDs: [UUID()],
            strategy: .interval(seconds: 600)
        )
        vm.save(playlist)
        XCTAssertEqual(vm.playlists.count, 1)
        XCTAssertEqual(vm.playlists.first?.name, "Calm")
    }

    func test_save_updates_existing_playlist() {
        var playlist = Playlist(
            name: "v1",
            wallpaperIDs: [UUID()],
            strategy: .interval(seconds: 60)
        )
        vm.save(playlist)
        playlist.name = "v2"
        vm.save(playlist)
        XCTAssertEqual(vm.playlists.count, 1)
        XCTAssertEqual(vm.playlists.first?.name, "v2")
    }

    func test_remove_deletes_playlist() {
        let playlist = Playlist(
            name: "doomed",
            wallpaperIDs: [UUID()],
            strategy: .interval(seconds: 60)
        )
        vm.save(playlist)
        vm.remove(id: playlist.id)
        XCTAssertTrue(vm.playlists.isEmpty)
    }

    func test_toggle_flips_enabled_state() throws {
        let playlist = Playlist(
            name: "x",
            wallpaperIDs: [UUID()],
            strategy: .interval(seconds: 60),
            enabled: true
        )
        vm.save(playlist)
        try vm.toggle(XCTUnwrap(vm.playlists.first))
        XCTAssertEqual(vm.playlists.first?.enabled, false)
        try vm.toggle(XCTUnwrap(vm.playlists.first))
        XCTAssertEqual(vm.playlists.first?.enabled, true)
    }

    func test_refresh_picks_up_external_writes() throws {
        // Write through the catalog directly, bypass the VM, then refresh.
        let playlist = Playlist(
            name: "external",
            wallpaperIDs: [UUID()],
            strategy: .shuffle(seconds: 60)
        )
        try catalog.upsert(playlist)
        XCTAssertTrue(vm.playlists.isEmpty, "VM hasn't refreshed yet")
        vm.refresh()
        XCTAssertEqual(vm.playlists.count, 1)
    }
}
