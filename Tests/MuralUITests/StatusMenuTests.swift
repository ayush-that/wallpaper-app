import XCTest
import AppKit
@testable import Mural

@MainActor
final class StatusMenuTests: XCTestCase {
    func test_menu_contains_required_items() {
        let menu = StatusMenu.build(target: NSObject(), action: #selector(NSObject.description))
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains("Library…"))
        XCTAssertTrue(titles.contains("Settings…"))
        XCTAssertTrue(titles.contains("Pause All"))
        XCTAssertTrue(titles.contains("Quit Mural"))
    }
}
