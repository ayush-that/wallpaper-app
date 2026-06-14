import Foundation
@testable import Mural
import XCTest

final class ActiveStatusTests: XCTestCase {
    private var tmpURL: URL!

    override func setUpWithError() throws {
        tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpURL)
    }

    func test_write_then_read_round_trips() throws {
        let original = ActiveStatus(
            displays: [
                .init(displayUUID: "A", wallpaperID: UUID()),
                .init(displayUUID: "B", wallpaperID: UUID())
            ],
            libraryRoot: "/tmp/library"
        )
        try ActiveStatus.write(original, to: tmpURL)
        let loaded = try XCTUnwrap(ActiveStatus.read(from: tmpURL))
        XCTAssertEqual(loaded.displays.count, 2)
        XCTAssertEqual(loaded.libraryRoot, "/tmp/library")
        XCTAssertEqual(Set(loaded.displays.map(\.displayUUID)), ["A", "B"])
    }

    func test_read_returns_nil_when_file_missing() throws {
        XCTAssertNil(try ActiveStatus.read(from: tmpURL))
    }

    func test_write_is_atomic_overwrite() throws {
        let first = ActiveStatus(displays: [], libraryRoot: "/a")
        try ActiveStatus.write(first, to: tmpURL)
        let second = ActiveStatus(
            displays: [.init(displayUUID: "X", wallpaperID: UUID())],
            libraryRoot: "/b"
        )
        try ActiveStatus.write(second, to: tmpURL)
        let loaded = try XCTUnwrap(ActiveStatus.read(from: tmpURL))
        XCTAssertEqual(loaded.libraryRoot, "/b")
        XCTAssertEqual(loaded.displays.count, 1)
    }

    func test_default_url_points_under_application_support_mural() {
        let url = ActiveStatus.defaultURL()
        XCTAssertTrue(url.path.contains("Application Support/Mural"))
        XCTAssertEqual(url.lastPathComponent, "active.json")
    }

    func test_url_for_library_root_is_a_sibling_of_the_library_directory() {
        let root = URL(fileURLWithPath: "/var/folders/xx/T/abc/library", isDirectory: true)
        let url = ActiveStatus.url(forLibraryRoot: root)
        XCTAssertEqual(url, URL(fileURLWithPath: "/var/folders/xx/T/abc/active.json"))
    }

    func test_url_for_production_library_root_equals_default_url() {
        // The real app derives the status path from its library root; that must
        // resolve to the same file external readers use via defaultURL().
        XCTAssertEqual(ActiveStatus.url(forLibraryRoot: LibraryRoot.defaultURL()), ActiveStatus.defaultURL())
    }
}
