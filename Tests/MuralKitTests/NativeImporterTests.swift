import AppKit
import Foundation
@testable import Mural
import XCTest

@MainActor
final class NativeImporterTests: XCTestCase {
    private var libraryRoot: URL!

    override func setUp() async throws {
        libraryRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: libraryRoot)
    }

    private func fixtureMP4() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    func test_import_mp4_creates_video_wallpaper_with_thumbnail() throws {
        let importer = NativeImporter(libraryRoot: libraryRoot)
        let wallpaper = try importer.importFile(at: fixtureMP4())

        XCTAssertEqual(wallpaper.type, .video)
        XCTAssertEqual(wallpaper.entryRelativePath, "asset.mp4")
        XCTAssertEqual(wallpaper.sourceImporter, .native)
        XCTAssertEqual(wallpaper.title, "red-1s")

        let pkgDir = libraryRoot.appendingPathComponent(wallpaper.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("asset.mp4").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("thumbnail.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("wallpaper.json").path))
    }

    func test_import_png_creates_image_wallpaper_with_thumbnail() throws {
        let src = libraryRoot.appendingPathComponent("blue.png")
        let pngData = try makeTinyPNG()
        try pngData.write(to: src)

        let importer = NativeImporter(libraryRoot: libraryRoot)
        let wallpaper = try importer.importFile(at: src)

        XCTAssertEqual(wallpaper.type, .image)
        XCTAssertEqual(wallpaper.entryRelativePath, "asset.png")

        let pkgDir = libraryRoot.appendingPathComponent(wallpaper.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("asset.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("thumbnail.png").path))
    }

    func test_import_unsupported_extension_throws() {
        let src = libraryRoot.appendingPathComponent("notes.txt")
        try? Data("hello".utf8).write(to: src)

        let importer = NativeImporter(libraryRoot: libraryRoot)
        XCTAssertThrowsError(try importer.importFile(at: src)) { error in
            guard case let NativeImporterError.unsupportedExtension(ext) = error else {
                return XCTFail("expected .unsupportedExtension; got \(error)")
            }
            XCTAssertEqual(ext, "txt")
        }
    }

    func test_import_html_creates_web_wallpaper_without_thumbnail() throws {
        let src = libraryRoot.appendingPathComponent("page.html")
        try "<!doctype html><body>hi".write(to: src, atomically: true, encoding: .utf8)

        let importer = NativeImporter(libraryRoot: libraryRoot)
        let wallpaper = try importer.importFile(at: src)

        XCTAssertEqual(wallpaper.type, .web)
        XCTAssertEqual(wallpaper.entryRelativePath, "asset.html")
        let pkgDir = libraryRoot.appendingPathComponent(wallpaper.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("asset.html").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("thumbnail.png").path))
    }

    func test_import_creates_library_root_if_missing() throws {
        let nested = libraryRoot.appendingPathComponent("nested/lib")
        XCTAssertFalse(FileManager.default.fileExists(atPath: nested.path))

        let importer = NativeImporter(libraryRoot: nested)
        let wallpaper = try importer.importFile(at: fixtureMP4())

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: nested.appendingPathComponent(wallpaper.id.uuidString).path)
        )
    }

    func test_import_metal_shader_creates_shader_wallpaper_with_placeholder_thumbnail() throws {
        // Create a tiny .metal file in tmp and import it.
        let src = libraryRoot.appendingPathComponent("simple.metal")
        let body = """
        fragment float4 mural_main(VertexOut in [[stage_in]],
                                   constant Uniforms& u [[buffer(0)]]) {
            return float4(1.0);
        }
        """
        try body.write(to: src, atomically: true, encoding: .utf8)

        let importer = NativeImporter(libraryRoot: libraryRoot)
        let wallpaper = try importer.importFile(at: src)

        XCTAssertEqual(wallpaper.type, .shader)
        XCTAssertEqual(wallpaper.entryRelativePath, "asset.metal")
        let pkgDir = libraryRoot.appendingPathComponent(wallpaper.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("asset.metal").path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("thumbnail.png").path),
            "shader-placeholder.png should be copied into the package"
        )
    }

    /// Build a real 8x8 PNG in-process so the test doesn't depend on a fixture file.
    private func makeTinyPNG() throws -> Data {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.blue.set()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }
}
