import Foundation
@testable import Mural
import XCTest

final class PropertyOverrideStoreTests: XCTestCase {
    private var tmp: URL!
    private var store: PropertyOverrideStore!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        store = PropertyOverrideStore(root: tmp)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - DisplayArrangementHash

    func test_arrangement_hash_is_order_independent() {
        let a = DisplayArrangementHash(displayUUIDs: ["A", "B", "C"])
        let b = DisplayArrangementHash(displayUUIDs: ["C", "A", "B"])
        XCTAssertEqual(a, b)
    }

    func test_arrangement_hash_changes_with_set_membership() {
        let single = DisplayArrangementHash(displayUUIDs: ["A"])
        let dual = DisplayArrangementHash(displayUUIDs: ["A", "B"])
        XCTAssertNotEqual(single, dual)
    }

    // MARK: - Store

    func test_read_missing_returns_empty_dict_without_throwing() {
        let arrangement = DisplayArrangementHash(displayUUIDs: ["X"])
        let result = store.read(
            wallpaperID: UUID(),
            displayUUID: "X",
            arrangement: arrangement
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_write_then_read_round_trips_values() throws {
        let wallpaper = UUID()
        let arrangement = DisplayArrangementHash(displayUUIDs: ["A", "B"])
        let written: PropertyOverrideStore.Overrides = [
            "speed": .double(1.5),
            "smooth": .bool(true),
            "tint": .color("#ff8800"),
            "engine": .int(2),
            "title": .string("hello")
        ]
        try store.write(written, wallpaperID: wallpaper, displayUUID: "A", arrangement: arrangement)
        let read = store.read(wallpaperID: wallpaper, displayUUID: "A", arrangement: arrangement)
        XCTAssertEqual(read, written)
    }

    func test_set_creates_or_updates_single_property() throws {
        let wallpaper = UUID()
        let arrangement = DisplayArrangementHash(displayUUIDs: ["X"])
        try store.set(.double(0.5), for: "speed", wallpaperID: wallpaper, displayUUID: "X", arrangement: arrangement)
        try store.set(.bool(true), for: "smooth", wallpaperID: wallpaper, displayUUID: "X", arrangement: arrangement)
        try store.set(.double(0.75), for: "speed", wallpaperID: wallpaper, displayUUID: "X", arrangement: arrangement)

        let result = store.read(wallpaperID: wallpaper, displayUUID: "X", arrangement: arrangement)
        XCTAssertEqual(result["speed"], .double(0.75))
        XCTAssertEqual(result["smooth"], .bool(true))
    }

    func test_different_displays_are_isolated() throws {
        let wallpaper = UUID()
        let arrangement = DisplayArrangementHash(displayUUIDs: ["A", "B"])
        try store.set(.double(1.25), for: "speed", wallpaperID: wallpaper, displayUUID: "A", arrangement: arrangement)
        try store.set(.double(2.5), for: "speed", wallpaperID: wallpaper, displayUUID: "B", arrangement: arrangement)

        let a = store.read(wallpaperID: wallpaper, displayUUID: "A", arrangement: arrangement)
        let b = store.read(wallpaperID: wallpaper, displayUUID: "B", arrangement: arrangement)
        XCTAssertEqual(a["speed"], .double(1.25))
        XCTAssertEqual(b["speed"], .double(2.5))
    }

    func test_different_arrangements_are_isolated() throws {
        let wallpaper = UUID()
        let solo = DisplayArrangementHash(displayUUIDs: ["A"])
        let multi = DisplayArrangementHash(displayUUIDs: ["A", "B"])

        try store.set(.int(1), for: "engine", wallpaperID: wallpaper, displayUUID: "A", arrangement: solo)
        try store.set(.int(7), for: "engine", wallpaperID: wallpaper, displayUUID: "A", arrangement: multi)

        XCTAssertEqual(
            store.read(wallpaperID: wallpaper, displayUUID: "A", arrangement: solo)["engine"],
            .int(1)
        )
        XCTAssertEqual(
            store.read(wallpaperID: wallpaper, displayUUID: "A", arrangement: multi)["engine"],
            .int(7)
        )
    }

    func test_corrupted_file_returns_empty_dict_without_throwing() throws {
        let wallpaper = UUID()
        let arrangement = DisplayArrangementHash(displayUUIDs: ["X"])
        let location = store.url(wallpaperID: wallpaper, displayUUID: "X", arrangement: arrangement)
        try FileManager.default.createDirectory(
            at: location.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("definitely not json".utf8).write(to: location)
        let result = store.read(wallpaperID: wallpaper, displayUUID: "X", arrangement: arrangement)
        XCTAssertTrue(result.isEmpty)
    }

    func test_url_path_layout_is_predictable() throws {
        let wallpaper = try XCTUnwrap(UUID(uuidString: "DEADBEEF-DEAD-DEAD-DEAD-DEADDEADBEEF"))
        let arrangement = DisplayArrangementHash(displayUUIDs: ["A", "B"])
        let location = store.url(wallpaperID: wallpaper, displayUUID: "C", arrangement: arrangement)
        XCTAssertEqual(location.lastPathComponent, "C.json")
        XCTAssertEqual(location.deletingLastPathComponent().lastPathComponent, "A+B")
        XCTAssertEqual(
            location.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent,
            "DEADBEEF-DEAD-DEAD-DEAD-DEADDEADBEEF"
        )
    }
}
