import AppKit
@testable import Mural
import XCTest

@MainActor
final class WallpaperEngineTests: XCTestCase {
    private func makeEngine() throws -> (DisplayManager, WallpaperEngine) {
        try XCTSkipIf(NSScreen.screens.isEmpty, "no displays attached")
        let dm = DisplayManager()
        dm.start()
        return (dm, WallpaperEngine(displayManager: dm))
    }

    func test_setRendererForAllDisplays_attaches_one_per_host() throws {
        let (dm, engine) = try makeEngine()
        defer { dm.shutdown() }
        engine.setRendererForAllDisplays { SolidColorRenderer(color: .systemPink) }
        for host in dm.hosts.values {
            XCTAssertEqual(host.layer?.sublayers?.count, 1)
        }
        XCTAssertEqual(engine.activeRendererUUIDs.count, dm.hosts.count)
    }

    func test_setRenderer_for_specific_display_replaces_previous() throws {
        let (dm, engine) = try makeEngine()
        defer { dm.shutdown() }
        let screen = try XCTUnwrap(NSScreen.main)
        let display = try XCTUnwrap(Display(screen: screen))
        engine.setRenderer(SolidColorRenderer(color: .red), for: display)
        engine.setRenderer(SolidColorRenderer(color: .blue), for: display)
        let host = try XCTUnwrap(dm.host(for: display))
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
        XCTAssertEqual(host.layer?.sublayers?.first?.backgroundColor, NSColor.blue.cgColor)
    }

    func test_renderer_for_displayUUID_returns_current_assignment() throws {
        let (dm, engine) = try makeEngine()
        defer { dm.shutdown() }
        let screen = try XCTUnwrap(NSScreen.main)
        let display = try XCTUnwrap(Display(screen: screen))
        let r = SolidColorRenderer(color: .green)
        engine.setRenderer(r, for: display)
        XCTAssertTrue(engine.renderer(for: display.uuid) === r)
    }

    func test_clear_for_display_removes_renderer() throws {
        let (dm, engine) = try makeEngine()
        defer { dm.shutdown() }
        let screen = try XCTUnwrap(NSScreen.main)
        let display = try XCTUnwrap(Display(screen: screen))
        engine.setRenderer(SolidColorRenderer(color: .red), for: display)
        engine.clear(for: display)
        let host = try XCTUnwrap(dm.host(for: display))
        XCTAssertTrue(host.layer?.sublayers?.isEmpty ?? true)
        XCTAssertNil(engine.renderer(for: display.uuid))
    }

    func test_pauseAll_and_resumeAll_dispatch_to_every_renderer() throws {
        let (dm, engine) = try makeEngine()
        defer { dm.shutdown() }
        engine.setRendererForAllDisplays { TrackingRenderer() }
        engine.pauseAll()
        for uuid in engine.activeRendererUUIDs {
            let r = try XCTUnwrap(engine.renderer(for: uuid) as? TrackingRenderer)
            XCTAssertEqual(r.pauseCount, 1)
            XCTAssertEqual(r.resumeCount, 0)
        }
        engine.resumeAll()
        for uuid in engine.activeRendererUUIDs {
            let r = try XCTUnwrap(engine.renderer(for: uuid) as? TrackingRenderer)
            XCTAssertEqual(r.resumeCount, 1)
        }
    }

    func test_renderer_for_unknown_uuid_returns_nil() throws {
        let (dm, engine) = try makeEngine()
        defer { dm.shutdown() }
        XCTAssertNil(engine.renderer(for: "not-a-real-display-uuid"))
    }
}

/// Test double for verifying pause/resume fan-out without needing a real renderer.
@MainActor
private final class TrackingRenderer: WallpaperRenderer {
    var pauseCount = 0
    var resumeCount = 0

    func attach(to host: WallpaperHost) {
        host.install(layer: CALayer())
    }

    func detach() {}

    func pause() {
        pauseCount += 1
    }

    func resume() {
        resumeCount += 1
    }
}
