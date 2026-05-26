import AppKit
@testable import Mural
import XCTest

@MainActor
final class DesktopWindowTests: XCTestCase {
    private func makeScreen() throws -> NSScreen {
        try XCTSkipIf(NSScreen.main == nil, "no display attached")
        return try XCTUnwrap(NSScreen.main)
    }

    func test_window_is_at_desktop_level_behind_icons() throws {
        let screen = try makeScreen()
        let w = DesktopWindow(screen: screen)
        let expected = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        XCTAssertEqual(w.level, expected)
    }

    func test_window_is_transparent_and_borderless() throws {
        let screen = try makeScreen()
        let w = DesktopWindow(screen: screen)
        XCTAssertFalse(w.isOpaque)
        XCTAssertEqual(w.backgroundColor, .clear)
        XCTAssertFalse(w.hasShadow)
        XCTAssertTrue(w.styleMask.contains(.borderless))
    }

    func test_window_ignores_mouse_events() throws {
        let screen = try makeScreen()
        let w = DesktopWindow(screen: screen)
        XCTAssertTrue(w.ignoresMouseEvents)
    }

    func test_collection_behavior_for_persistence_across_spaces() throws {
        let screen = try makeScreen()
        let w = DesktopWindow(screen: screen)
        let cb = w.collectionBehavior
        XCTAssertTrue(cb.contains(.canJoinAllSpaces))
        XCTAssertTrue(cb.contains(.stationary))
        XCTAssertTrue(cb.contains(.ignoresCycle))
        XCTAssertTrue(cb.contains(.fullScreenNone))
    }

    func test_sharing_type_is_none() throws {
        let screen = try makeScreen()
        let w = DesktopWindow(screen: screen)
        XCTAssertEqual(w.sharingType, .none)
    }

    func test_window_frame_matches_screen() throws {
        let screen = try makeScreen()
        let w = DesktopWindow(screen: screen)
        XCTAssertEqual(w.frame, screen.frame)
    }
}
