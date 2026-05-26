import Combine
import Foundation
@testable import Mural
import XCTest

@MainActor
final class LibraryViewModelTests: XCTestCase {
    private var root: URL!
    private var libraryRoot: URL!
    private var service: LibraryService!
    private var vm: LibraryViewModel!

    override func setUp() async throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        libraryRoot = root.appendingPathComponent("library")
        let catalog = try Catalog(url: root.appendingPathComponent("catalog.sqlite"))
        service = LibraryService(libraryRoot: libraryRoot, catalog: catalog)
        vm = LibraryViewModel(service: service)
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

    func test_initial_state_is_empty() {
        XCTAssertTrue(vm.wallpapers.isEmpty)
        XCTAssertNil(vm.selected)
        XCTAssertNil(vm.importError)
    }

    func test_refresh_picks_up_inserted_wallpapers() throws {
        _ = try service.importFile(at: fixtureMP4())
        vm.refresh()
        XCTAssertEqual(vm.wallpapers.count, 1)
    }

    func test_importURLs_imports_and_refreshes() throws {
        let url = try fixtureMP4()
        vm.importURLs([url])
        XCTAssertEqual(vm.wallpapers.count, 1)
    }

    func test_importURLs_surfaces_error_for_unsupported_file() throws {
        let bad = root.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: bad)
        vm.importURLs([bad])
        XCTAssertNotNil(vm.importError)
    }

    func test_select_publishes_selected_wallpaper() async throws {
        _ = try service.importFile(at: fixtureMP4())
        vm.refresh()
        let wallpaper = try XCTUnwrap(vm.wallpapers.first)

        let expectation = expectation(description: "selection published")
        let cancellable = vm.$selected.dropFirst().sink { selected in
            if selected?.id == wallpaper.id { expectation.fulfill() }
        }
        vm.select(wallpaper)
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func test_thumbnail_url_resolves_under_library_root() throws {
        let wallpaper = try service.importFile(at: fixtureMP4())
        vm.refresh()
        let thumb = vm.thumbnail(for: wallpaper)
        XCTAssertEqual(thumb.lastPathComponent, "thumbnail.png")
        XCTAssertTrue(thumb.path.contains(wallpaper.id.uuidString))
    }
}
