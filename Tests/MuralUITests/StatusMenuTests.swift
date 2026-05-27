import AppKit
@testable import Mural
import XCTest

@MainActor
final class StatusMenuTests: XCTestCase {
    private func buildMenu(activeScaleMode: ScaleMode = .fill) -> NSMenu {
        StatusMenu.build(
            target: NSObject(),
            action: #selector(NSObject.description),
            scaleAction: #selector(NSObject.description),
            activeScaleMode: activeScaleMode
        )
    }

    func test_menu_contains_required_items() {
        let menu = buildMenu()
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains("Library…"))
        XCTAssertTrue(titles.contains("Settings…"))
        XCTAssertTrue(titles.contains("Pause All"))
        XCTAssertTrue(titles.contains("Quit Mural"))
    }

    func test_menu_items_have_expected_action_tags() {
        let menu = buildMenu()
        func tag(forTitle title: String) -> Int? {
            menu.items.first(where: { $0.title == title })?.tag
        }
        XCTAssertEqual(tag(forTitle: "Library…"), StatusMenuAction.library.rawValue)
        XCTAssertEqual(tag(forTitle: "Settings…"), StatusMenuAction.settings.rawValue)
        XCTAssertEqual(tag(forTitle: "Pause All"), StatusMenuAction.pauseAll.rawValue)
        XCTAssertEqual(tag(forTitle: "Quit Mural"), StatusMenuAction.quit.rawValue)
    }

    func test_menu_contains_smoke_test_item_with_correct_tag() {
        let menu = buildMenu()
        let item = menu.items.first(where: { $0.title == "Debug: Magenta Smoke Test" })
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.tag, StatusMenuAction.smokeTest.rawValue)
    }

    func test_menu_contains_check_for_updates_item_with_correct_tag() {
        let menu = buildMenu()
        let item = menu.items.first(where: { $0.title == "Check for Updates…" })
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.tag, StatusMenuAction.checkForUpdates.rawValue)
        XCTAssertEqual(item?.keyEquivalent, "u")
    }

    func test_menu_action_tags_are_unique() {
        let menu = buildMenu()
        let topLevelTitles: Set = [
            "Library…", "Settings…", "Pause All", "Debug: Magenta Smoke Test",
            "Check for Updates…", "Quit Mural"
        ]
        let tags = menu.items
            .filter { topLevelTitles.contains($0.title) }
            .map(\.tag)
        XCTAssertEqual(tags, Array(Set(tags)).sorted())
    }

    func test_scale_mode_submenu_exists_with_all_modes() throws {
        let menu = buildMenu(activeScaleMode: .fill)
        let scaleItem = menu.items.first(where: { $0.title == "Scale Mode" })
        let submenu = try XCTUnwrap(scaleItem?.submenu)
        XCTAssertEqual(submenu.items.count, ScaleMode.allCases.count)
    }

    func test_active_scale_mode_is_checked_on_in_submenu() {
        let menu = buildMenu(activeScaleMode: .fit)
        let submenu = menu.items.first(where: { $0.title == "Scale Mode" })?.submenu
        let onItems = submenu?.items.filter { $0.state == .on } ?? []
        XCTAssertEqual(onItems.count, 1)
        XCTAssertEqual(onItems.first?.representedObject as? String, "fit")
    }

    func test_scale_submenu_items_carry_rawvalue_as_representedObject() {
        let menu = buildMenu()
        let submenu = menu.items.first(where: { $0.title == "Scale Mode" })?.submenu
        let rawValues = (submenu?.items ?? []).compactMap { $0.representedObject as? String }
        XCTAssertEqual(Set(rawValues), Set(ScaleMode.allCases.map(\.rawValue)))
    }

    func test_pause_all_label_is_customisable() {
        let menu = StatusMenu.build(
            target: NSObject(),
            action: #selector(NSObject.description),
            scaleAction: #selector(NSObject.description),
            activeScaleMode: .fill,
            pauseLabel: "Resume All"
        )
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains("Resume All"))
        XCTAssertFalse(titles.contains("Pause All"))
    }

    func test_pause_all_label_defaults_to_Pause_All() {
        let menu = StatusMenu.build(
            target: NSObject(),
            action: #selector(NSObject.description),
            scaleAction: #selector(NSObject.description),
            activeScaleMode: .fill
        )
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains("Pause All"))
    }
}
