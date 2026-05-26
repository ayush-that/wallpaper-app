import AppKit
@testable import Mural
import XCTest

@MainActor
final class DisplayManagerTests: XCTestCase {
    private func makeManager() throws -> DisplayManager {
        try XCTSkipIf(NSScreen.screens.isEmpty, "no displays attached")
        return DisplayManager()
    }

    func test_start_creates_one_window_per_screen() throws {
        let mgr = try makeManager()
        defer { mgr.shutdown() }
        mgr.start()
        XCTAssertEqual(mgr.windows.count, NSScreen.screens.count)
        for window in mgr.windows.values {
            XCTAssertTrue(window.isVisible)
        }
    }

    func test_start_creates_one_host_per_screen() throws {
        let mgr = try makeManager()
        defer { mgr.shutdown() }
        mgr.start()
        XCTAssertEqual(mgr.hosts.count, NSScreen.screens.count)
    }

    func test_shutdown_closes_all_windows() throws {
        let mgr = try makeManager()
        mgr.start()
        mgr.shutdown()
        XCTAssertTrue(mgr.windows.isEmpty)
        XCTAssertTrue(mgr.hosts.isEmpty)
        XCTAssertTrue(mgr.displays.isEmpty)
    }

    func test_host_for_display_returns_consistent_instance() throws {
        let mgr = try makeManager()
        defer { mgr.shutdown() }
        mgr.start()
        let screen = try XCTUnwrap(NSScreen.main)
        let display = try XCTUnwrap(Display(screen: screen))
        let h1 = try XCTUnwrap(mgr.host(for: display))
        let h2 = try XCTUnwrap(mgr.host(for: display))
        XCTAssertIdentical(h1, h2)
    }

    func test_screen_change_notification_is_idempotent_when_screens_unchanged() throws {
        let mgr = try makeManager()
        defer { mgr.shutdown() }
        mgr.start()
        let before = mgr.windows.count
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: NSApp
        )
        // Observer is dispatched async to .main; spin the runloop briefly so
        // the callback actually runs before we assert.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(mgr.windows.count, before)
    }
}
