import Foundation
@testable import Mural
import XCTest

final class ImporterRouterTests: XCTestCase {
    private var libraryRoot: URL!

    override func setUpWithError() throws {
        libraryRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: libraryRoot)
    }

    private func fixture(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing Tests/Fixtures/\(name).\(ext)"
        )
    }

    func test_zip_routes_to_zip_importer() throws {
        let router = Importer(libraryRoot: libraryRoot)
        let wallpaper = try router.import(url: fixture("clock", "zip"))
        XCTAssertEqual(wallpaper.sourceImporter, .lively)
        XCTAssertEqual(wallpaper.type, .web)
    }

    func test_pkg_routes_to_pkg_importer() throws {
        let router = Importer(libraryRoot: libraryRoot)
        let wallpaper = try router.import(url: fixture("sample", "pkg"))
        XCTAssertEqual(wallpaper.sourceImporter, .wallpaperEngine)
        XCTAssertEqual(wallpaper.type, .video)
    }

    func test_mp4_routes_to_native_importer() throws {
        let router = Importer(libraryRoot: libraryRoot)
        let wallpaper = try router.import(url: fixture("red-1s", "mp4"))
        XCTAssertEqual(wallpaper.sourceImporter, .native)
        XCTAssertEqual(wallpaper.type, .video)
    }

    func test_uppercase_extension_routes_correctly() throws {
        // Copy the zip to a path with uppercase extension and verify routing.
        let src = try fixture("clock", "zip")
        let dst = libraryRoot.appendingPathComponent("CLOCK.ZIP")
        try FileManager.default.copyItem(at: src, to: dst)

        let router = Importer(libraryRoot: libraryRoot)
        let wallpaper = try router.import(url: dst)
        XCTAssertEqual(wallpaper.sourceImporter, .lively)
    }

    func test_unsupported_extension_propagates_native_importer_error() throws {
        let src = libraryRoot.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: src)

        let router = Importer(libraryRoot: libraryRoot)
        XCTAssertThrowsError(try router.import(url: src)) { error in
            guard case let NativeImporterError.unsupportedExtension(ext) = error else {
                return XCTFail("expected NativeImporterError.unsupportedExtension, got \(error)")
            }
            XCTAssertEqual(ext, "txt")
        }
    }
}
