import Foundation
@testable import Mural
import XCTest

final class LibraryRootTests: XCTestCase {
    func test_default_url_points_to_application_support_mural_library() {
        let url = LibraryRoot.defaultURL()
        XCTAssertTrue(url.path.hasSuffix("Application Support/Mural/library"))
    }

    func test_package_url_appends_uuid_to_root() throws {
        let root = URL(fileURLWithPath: "/tmp/mural-library")
        let id = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let url = LibraryRoot.packageURL(root: root, id: id)
        XCTAssertEqual(url.path, "/tmp/mural-library/00000000-0000-0000-0000-000000000001")
    }

    func test_catalog_url_is_sibling_of_library_root() {
        let root = URL(fileURLWithPath: "/tmp/mural/library")
        let url = LibraryRoot.catalogURL(root: root)
        XCTAssertEqual(url.path, "/tmp/mural/catalog.sqlite")
    }

    func test_ensure_exists_creates_missing_directory() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested/lib")
        defer { try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent().deletingLastPathComponent()) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
        try LibraryRoot.ensureExists(root: tmp)

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func test_ensure_exists_is_idempotent() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try LibraryRoot.ensureExists(root: tmp)
        try LibraryRoot.ensureExists(root: tmp) // second call must not throw
    }
}
