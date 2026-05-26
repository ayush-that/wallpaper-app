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

    func test_menu_items_have_expected_action_tags() {
        let menu = StatusMenu.build(target: NSObject(), action: #selector(NSObject.description))
        func tag(forTitle title: String) -> Int? {
            menu.items.first(where: { $0.title == title })?.tag
        }
        XCTAssertEqual(tag(forTitle: "Library…"), StatusMenuAction.library.rawValue)
        XCTAssertEqual(tag(forTitle: "Settings…"), StatusMenuAction.settings.rawValue)
        XCTAssertEqual(tag(forTitle: "Pause All"), StatusMenuAction.pauseAll.rawValue)
        XCTAssertEqual(tag(forTitle: "Quit Mural"), StatusMenuAction.quit.rawValue)
    }
}
