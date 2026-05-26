import Foundation
@testable import Mural
import XCTest

@MainActor
final class LibraryServiceTests: XCTestCase {
    private var root: URL!
    private var libraryRoot: URL!
    private var service: LibraryService!

    override func setUp() async throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        libraryRoot = root.appendingPathComponent("library")
        let catalog = try Catalog(url: root.appendingPathComponent("catalog.sqlite"))
        service = LibraryService(libraryRoot: libraryRoot, catalog: catalog)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func fixtureMP4() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    func test_import_inserts_into_catalog_and_returns_wallpaper() throws {
        let wallpaper = try service.importFile(at: fixtureMP4())
        XCTAssertEqual(wallpaper.type, .video)

        let fetched = try service.catalog.fetch(id: wallpaper.id)
        XCTAssertEqual(fetched?.title, wallpaper.title)
        XCTAssertEqual(try service.allWallpapers().count, 1)
    }

    func test_import_twice_creates_two_distinct_wallpapers() throws {
        let a = try service.importFile(at: fixtureMP4())
        let b = try service.importFile(at: fixtureMP4())
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(try service.allWallpapers().count, 2)
    }

    func test_package_path_resolves_under_library_root() throws {
        let wallpaper = try service.importFile(at: fixtureMP4())
        let package = service.package(for: wallpaper.id)
        XCTAssertEqual(package.root.lastPathComponent, wallpaper.id.uuidString)
        XCTAssertTrue(package.root.path.hasPrefix(libraryRoot.path))
    }

    func test_remove_deletes_row_and_directory() throws {
        let wallpaper = try service.importFile(at: fixtureMP4())
        let dir = LibraryRoot.packageURL(root: libraryRoot, id: wallpaper.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

        try service.remove(id: wallpaper.id)

        XCTAssertNil(try service.catalog.fetch(id: wallpaper.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
        XCTAssertEqual(try service.allWallpapers().count, 0)
    }

    func test_remove_unknown_id_is_a_noop() throws {
        try service.remove(id: UUID())
    }

    func test_all_wallpapers_sorted_by_createdAt_desc() throws {
        _ = try service.importFile(at: fixtureMP4())
        Thread.sleep(forTimeInterval: 0.05)
        let newer = try service.importFile(at: fixtureMP4())

        let all = try service.allWallpapers()
        XCTAssertEqual(all.first?.id, newer.id)
    }
}
