import AppKit
@testable import Mural
import SwiftUI
import XCTest

@MainActor
final class LibraryWindowControllerTests: XCTestCase {
    func test_window_enforces_a_minimum_content_size() {
        let window = LibraryWindowController.makeWindow(rootView: Text("test"))
        // A resizable window with no minimum can be dragged down until its
        // content clips. Guard against regressing to an unbounded floor.
        XCTAssertGreaterThanOrEqual(window.contentMinSize.width, 800)
        XCTAssertGreaterThanOrEqual(window.contentMinSize.height, 500)
        XCTAssertEqual(window.contentMinSize, LibraryWindowController.minimumContentSize)
    }

    func test_window_is_titled_and_resizable() {
        let window = LibraryWindowController.makeWindow(rootView: Text("test"))
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.resizable))
    }

    func test_default_content_size_is_at_least_the_minimum() {
        let window = LibraryWindowController.makeWindow(rootView: Text("test"))
        let content = window.contentRect(forFrameRect: window.frame).size
        XCTAssertGreaterThanOrEqual(content.width, window.contentMinSize.width)
        XCTAssertGreaterThanOrEqual(content.height, window.contentMinSize.height)
    }
}
