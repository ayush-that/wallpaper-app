import AppKit
import Foundation
@testable import Mural
import XCTest

@MainActor
final class WallpaperOrchestratorPlaylistTests: XCTestCase {
    private var root: URL!
    private var library: LibraryService!
    private var displayManager: DisplayManager!
    private var engine: WallpaperEngine!
    private var orchestrator: WallpaperOrchestrator!

    override func setUp() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "no displays attached")
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let catalog = try Catalog(url: root.appendingPathComponent("catalog.sqlite"))
        library = LibraryService(libraryRoot: root.appendingPathComponent("library"), catalog: catalog)
        displayManager = DisplayManager()
        displayManager.start()
        engine = WallpaperEngine(displayManager: displayManager)
        orchestrator = WallpaperOrchestrator(engine: engine, library: library)
    }

    override func tearDown() async throws {
        orchestrator?.stopPlaylist()
        displayManager?.shutdown()
        try? FileManager.default.removeItem(at: root)
    }

    private func fixtureMP4() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    func test_start_playlist_applies_first_wallpaper_synchronously() throws {
        let imported = try library.importFile(at: fixtureMP4())
        let playlist = Playlist(
            name: "single",
            wallpaperIDs: [imported.id],
            strategy: .interval(seconds: 60)
        )
        orchestrator.startPlaylist(playlist)
        XCTAssertEqual(engine.activeRendererUUIDs.count, displayManager.hosts.count)
    }

    func test_stop_playlist_does_not_clear_current_wallpaper() throws {
        let imported = try library.importFile(at: fixtureMP4())
        let playlist = Playlist(
            name: "single",
            wallpaperIDs: [imported.id],
            strategy: .interval(seconds: 60)
        )
        orchestrator.startPlaylist(playlist)
        let countBefore = engine.activeRendererUUIDs.count
        orchestrator.stopPlaylist()
        // Stopping the playlist halts rotation; the currently-rendering wallpaper stays.
        XCTAssertEqual(engine.activeRendererUUIDs.count, countBefore)
    }

    func test_engine_libraryRoot_is_wired_from_orchestrator_init() {
        XCTAssertEqual(engine.libraryRoot, library.libraryRoot)
    }

    func test_active_status_file_written_after_apply() throws {
        let imported = try library.importFile(at: fixtureMP4())
        orchestrator.applyToAllDisplays(wallpaper: imported)
        // The engine writes ActiveStatus as a sibling of its library root, so for
        // this temp-rooted test it lands inside the test's own directory rather
        // than the real ~/Library/Application Support/Mural/active.json. That temp
        // dir is always writable, so this is a strong assertion.
        let url = ActiveStatus.url(forLibraryRoot: library.libraryRoot)
        XCTAssertNotEqual(url, ActiveStatus.defaultURL(), "test must not touch the production status file")
        let status = try XCTUnwrap(ActiveStatus.read(from: url))
        XCTAssertTrue(Date().timeIntervalSince(status.updatedAt) < 10)
        XCTAssertTrue(status.displays.contains(where: { $0.wallpaperID == imported.id }))
    }
}
