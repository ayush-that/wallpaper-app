import Foundation
@testable import Mural
import XCTest
import ZIPFoundation

final class ZipWallpaperImporterTests: XCTestCase {
    private var libraryRoot: URL!

    override func setUpWithError() throws {
        libraryRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: libraryRoot)
    }

    private func fixtureZip() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "clock", withExtension: "zip", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/clock.zip"
        )
    }

    func test_imports_html_bundle_with_correct_metadata() throws {
        let importer = ZipWallpaperImporter(libraryRoot: libraryRoot)
        let wallpaper = try importer.importArchive(at: fixtureZip())

        XCTAssertEqual(wallpaper.title, "Clock Demo")
        XCTAssertEqual(wallpaper.author, "Anon")
        XCTAssertEqual(wallpaper.license, "CC-BY-4.0")
        XCTAssertEqual(wallpaper.type, .web)
        XCTAssertEqual(wallpaper.entryRelativePath, "index.html")
        XCTAssertEqual(wallpaper.sourceImporter, .lively)
        XCTAssertEqual(wallpaper.tags, ["clock", "html"])

        let pkgDir = libraryRoot.appendingPathComponent(wallpaper.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("wallpaper.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("thumbnail.png").path))
    }

    func test_type_mapping_covers_all_documented_codes() {
        XCTAssertEqual(ZipWallpaperImporter.mapType(0), .image)
        XCTAssertEqual(ZipWallpaperImporter.mapType(1), .video)
        XCTAssertEqual(ZipWallpaperImporter.mapType(2), .web)
        XCTAssertEqual(ZipWallpaperImporter.mapType(3), .gif)
        XCTAssertEqual(ZipWallpaperImporter.mapType(4), .urlPage)
        XCTAssertEqual(ZipWallpaperImporter.mapType(5), .web)
        XCTAssertEqual(ZipWallpaperImporter.mapType(6), .urlPage)
        XCTAssertEqual(ZipWallpaperImporter.mapType(7), .appWindow)
        XCTAssertEqual(ZipWallpaperImporter.mapType(8), .appWindow)
        XCTAssertEqual(ZipWallpaperImporter.mapType(9), .appWindow)
        XCTAssertEqual(ZipWallpaperImporter.mapType(10), .appWindow)
        XCTAssertEqual(ZipWallpaperImporter.mapType(11), .appWindow)
        XCTAssertEqual(ZipWallpaperImporter.mapType(12), .image)
        XCTAssertEqual(ZipWallpaperImporter.mapType(999), .image)
    }

    func test_import_missing_manifest_throws() throws {
        // Build a zip with NO LivelyInfo.json at the root.
        let scratch = libraryRoot.appendingPathComponent("scratch")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        try "<!doctype html>".write(
            to: scratch.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        let badZip = libraryRoot.appendingPathComponent("bad.zip")
        try FileManager.default.zipItem(at: scratch, to: badZip)

        let importer = ZipWallpaperImporter(libraryRoot: libraryRoot)
        XCTAssertThrowsError(try importer.importArchive(at: badZip)) { error in
            guard case ZipWallpaperImporterError.missingManifest = error else {
                return XCTFail("expected .missingManifest, got \(error)")
            }
        }
    }
}
