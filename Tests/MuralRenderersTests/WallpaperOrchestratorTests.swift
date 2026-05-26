import AppKit
@testable import Mural
import XCTest

@MainActor
final class WallpaperOrchestratorTests: XCTestCase {
    private var root: URL!
    private var displayManager: DisplayManager!
    private var engine: WallpaperEngine!
    private var library: LibraryService!
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
        displayManager?.shutdown()
        try? FileManager.default.removeItem(at: root)
    }

    private func fixtureMP4() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    func test_apply_to_all_displays_attaches_video_renderer() throws {
        let wallpaper = try library.importFile(at: fixtureMP4())
        orchestrator.applyToAllDisplays(wallpaper: wallpaper)

        for host in displayManager.hosts.values {
            // VideoRenderer installs a single AVPlayerLayer sublayer.
            XCTAssertEqual(host.layer?.sublayers?.count, 1)
        }
        XCTAssertEqual(engine.activeRendererUUIDs.count, displayManager.hosts.count)
    }

    func test_scale_mode_persists_across_apply_calls() throws {
        orchestrator.scaleMode = .fit
        let wallpaper = try library.importFile(at: fixtureMP4())
        orchestrator.applyToAllDisplays(wallpaper: wallpaper)
        // We can't easily peek inside the factory closure; just verify the
        // orchestrator's published property survives.
        XCTAssertEqual(orchestrator.scaleMode, .fit)
    }
}
