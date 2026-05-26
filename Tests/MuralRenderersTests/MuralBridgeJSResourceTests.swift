import Foundation
@testable import Mural
import XCTest

final class MuralBridgeJSResourceTests: XCTestCase {
    private func bridgeURL() throws -> URL {
        // Resources/ is bundled as a folder reference under
        // Mural.app/Contents/Resources/Resources/. The lookup pattern matches
        // SystemWallpaperOverride.blackImageURL().
        let direct = Bundle.main.url(forResource: "mural-bridge", withExtension: "js")
        if let direct { return direct }
        let nested = Bundle.main.url(forResource: "mural-bridge", withExtension: "js", subdirectory: "Resources")
        return try XCTUnwrap(nested, "mural-bridge.js not bundled — check Resources/ in project.yml")
    }

    func test_bridge_resource_is_in_bundle() throws {
        _ = try bridgeURL()
    }

    func test_bridge_declares_lively_compatibility_functions() throws {
        let url = try bridgeURL()
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("livelyPropertyListener"),
            "livelyPropertyListener missing — third-party wallpapers depend on this name"
        )
        XCTAssertTrue(
            source.contains("livelyAudioListener"),
            "livelyAudioListener missing — audio-reactive wallpapers depend on this name"
        )
        XCTAssertTrue(source.contains("livelyCurrentTrack"))
        XCTAssertTrue(source.contains("livelySystemInformation"))
        XCTAssertTrue(source.contains("livelyWallpaperPlaybackChanged"))
    }

    func test_bridge_declares_native_message_handler_name() throws {
        let url = try bridgeURL()
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("muralBridge"),
            "muralBridge handler name missing — WebRenderer (Task 3) registers under this name"
        )
    }

    func test_bridge_installs_idempotency_guard() throws {
        let url = try bridgeURL()
        let source = try String(contentsOf: url, encoding: .utf8)
        // Inject the script twice → second run must be a no-op. The guard
        // prevents double-installing the muted-media override (which would
        // call setter recursively and crash).
        XCTAssertTrue(
            source.contains("__muralBridgeInstalled"),
            "missing the install-once guard variable"
        )
    }

    func test_bridge_includes_scroll_and_selection_css() throws {
        let url = try bridgeURL()
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("overflow:hidden"),
            "scroll-disable CSS missing — wallpapers must not scroll"
        )
        XCTAssertTrue(
            source.contains("user-select:none"),
            "text-selection-disable CSS missing"
        )
        XCTAssertTrue(
            source.contains("background:transparent"),
            "body transparency CSS missing — see Phase 4 plan §pitfalls"
        )
    }
}
