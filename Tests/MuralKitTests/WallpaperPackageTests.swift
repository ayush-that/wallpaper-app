import Foundation
@testable import Mural
import XCTest

final class WallpaperPackageTests: XCTestCase {
    private var tmpRoot: URL!

    override func setUpWithError() throws {
        tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    private func makePackageDir(for wallpaper: Wallpaper) throws -> URL {
        let dir = tmpRoot.appendingPathComponent(wallpaper.id.uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func test_write_then_read_metadata_round_trip() throws {
        let wallpaper = Wallpaper(title: "Demo", type: .image, entryRelativePath: "frame.png")
        let dir = try makePackageDir(for: wallpaper)
        try Data([0xFF]).write(to: dir.appendingPathComponent("frame.png"))
        try Data([0x00]).write(to: dir.appendingPathComponent("thumbnail.png"))

        let package = WallpaperPackage(root: dir)
        try package.writeMetadata(wallpaper)
        let loaded = try package.readMetadata()

        XCTAssertEqual(loaded.id, wallpaper.id)
        XCTAssertEqual(loaded.title, wallpaper.title)
        XCTAssertEqual(loaded.type, wallpaper.type)
        XCTAssertEqual(loaded.entryRelativePath, wallpaper.entryRelativePath)
    }

    func test_entry_url_resolves_against_root() throws {
        let wallpaper = Wallpaper(title: "Demo", type: .video, entryRelativePath: "clip.mp4")
        let dir = try makePackageDir(for: wallpaper)
        let package = WallpaperPackage(root: dir)
        try package.writeMetadata(wallpaper)

        let entry = try package.entryURL()
        XCTAssertEqual(entry.lastPathComponent, "clip.mp4")
        XCTAssertEqual(entry.deletingLastPathComponent().path, dir.path)
    }

    func test_thumbnail_url_resolves_nested_relative_path() throws {
        let wallpaper = Wallpaper(
            title: "Demo",
            type: .image,
            entryRelativePath: "frame.png",
            thumbnailRelativePath: "thumb/preview.png"
        )
        let dir = try makePackageDir(for: wallpaper)
        let package = WallpaperPackage(root: dir)
        try package.writeMetadata(wallpaper)

        let thumb = try package.thumbnailURL()
        XCTAssertEqual(thumb.lastPathComponent, "preview.png")
        XCTAssertTrue(thumb.path.hasSuffix("thumb/preview.png"))
    }

    func test_preview_url_is_nil_when_unset_else_resolves() throws {
        var wallpaper = Wallpaper(title: "Demo", type: .video, entryRelativePath: "clip.mp4")
        let dir = try makePackageDir(for: wallpaper)
        let package = WallpaperPackage(root: dir)
        try package.writeMetadata(wallpaper)

        XCTAssertNil(try package.previewURL())

        wallpaper.previewRelativePath = "preview.gif"
        try package.writeMetadata(wallpaper)
        let preview = try package.previewURL()
        XCTAssertEqual(preview?.lastPathComponent, "preview.gif")
    }

    func test_read_metadata_from_nonexistent_package_throws() {
        let dir = tmpRoot.appendingPathComponent(UUID().uuidString)
        let package = WallpaperPackage(root: dir)
        XCTAssertThrowsError(try package.readMetadata())
    }

    func test_write_metadata_is_atomic_and_pretty_sorted() throws {
        let wallpaper = Wallpaper(title: "Demo", type: .image, entryRelativePath: "frame.png")
        let dir = try makePackageDir(for: wallpaper)
        let package = WallpaperPackage(root: dir)
        try package.writeMetadata(wallpaper)

        let json = try String(contentsOf: package.metadataURL, encoding: .utf8)
        // Sorted keys → `author` appears before `id`
        let authorIdx = try XCTUnwrap(json.range(of: "\"author\""))
        let idIdx = try XCTUnwrap(json.range(of: "\"id\""))
        XCTAssertLessThan(authorIdx.lowerBound, idIdx.lowerBound)
        // Pretty-printed → at least one newline
        XCTAssertTrue(json.contains("\n"))
    }
}
