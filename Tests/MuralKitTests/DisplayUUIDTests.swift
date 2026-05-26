import AppKit
@testable import Mural
import XCTest

final class DisplayUUIDTests: XCTestCase {
    func test_main_screen_yields_stable_uuid() throws {
        try XCTSkipIf(NSScreen.main == nil, "no display attached")
        let screen = try XCTUnwrap(NSScreen.main)
        let id1 = try XCTUnwrap(DisplayUUID.from(screen: screen))
        let id2 = try XCTUnwrap(DisplayUUID.from(screen: screen))
        XCTAssertEqual(id1, id2)
        XCTAssertFalse(id1.isEmpty)
    }

    func test_display_equality_uses_uuid_not_object_id() throws {
        try XCTSkipIf(NSScreen.main == nil, "no display attached")
        let s = try XCTUnwrap(NSScreen.main)
        let a = try XCTUnwrap(Display(screen: s))
        let b = try XCTUnwrap(Display(screen: s))
        XCTAssertEqual(a, b)
    }
}
