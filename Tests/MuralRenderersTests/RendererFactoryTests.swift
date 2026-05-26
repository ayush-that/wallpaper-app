import AppKit
import AVFoundation
@testable import Mural
import XCTest

@MainActor
final class RendererFactoryTests: XCTestCase {
    private var pkgRoot: URL!

    override func setUp() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        pkgRoot = dir
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: pkgRoot)
    }

    private func fixtureMP4() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    func test_video_wallpaper_yields_video_renderer() throws {
        let src = try fixtureMP4()
        let entry = pkgRoot.appendingPathComponent("asset.mp4")
        try FileManager.default.copyItem(at: src, to: entry)
        let wallpaper = Wallpaper(title: "x", type: .video, entryRelativePath: "asset.mp4")
        let package = WallpaperPackage(root: pkgRoot)
        try package.writeMetadata(wallpaper)

        let renderer = try RendererFactory.makeRenderer(
            for: wallpaper,
            package: package,
            scaleMode: .fill
        )
        XCTAssertTrue(renderer is VideoRenderer)
    }

    func test_image_wallpaper_yields_image_renderer() throws {
        // Tiny PNG.
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.red.set()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let pngData = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let entry = pkgRoot.appendingPathComponent("frame.png")
        try pngData.write(to: entry)

        let wallpaper = Wallpaper(title: "x", type: .image, entryRelativePath: "frame.png")
        let package = WallpaperPackage(root: pkgRoot)
        try package.writeMetadata(wallpaper)

        let renderer = try RendererFactory.makeRenderer(
            for: wallpaper,
            package: package,
            scaleMode: .fill
        )
        XCTAssertTrue(renderer is ImageRenderer)
    }

    func test_web_wallpaper_yields_web_renderer() throws {
        let entry = pkgRoot.appendingPathComponent("index.html")
        try "<!doctype html>".write(to: entry, atomically: true, encoding: .utf8)
        let wallpaper = Wallpaper(title: "x", type: .web, entryRelativePath: "index.html")
        let package = WallpaperPackage(root: pkgRoot)
        try package.writeMetadata(wallpaper)

        let renderer = try RendererFactory.makeRenderer(
            for: wallpaper,
            package: package,
            scaleMode: .fill
        )
        XCTAssertTrue(renderer is WebRenderer)
    }

    func test_urlPage_with_http_scheme_yields_web_renderer() throws {
        // entryRelativePath holds the URL string, not a real path.
        let wallpaper = Wallpaper(
            title: "Shadertoy demo",
            type: .urlPage,
            entryRelativePath: "https://www.shadertoy.com/embed/3l23Rh"
        )
        let package = WallpaperPackage(root: pkgRoot)
        try package.writeMetadata(wallpaper)

        let renderer = try RendererFactory.makeRenderer(
            for: wallpaper,
            package: package,
            scaleMode: .fill
        )
        XCTAssertTrue(renderer is WebRenderer)
    }

    func test_urlPage_with_invalid_scheme_falls_back_to_placeholder() throws {
        let wallpaper = Wallpaper(
            title: "Bad URL",
            type: .urlPage,
            entryRelativePath: "not-a-url"
        )
        let package = WallpaperPackage(root: pkgRoot)
        try package.writeMetadata(wallpaper)

        let renderer = try RendererFactory.makeRenderer(
            for: wallpaper,
            package: package,
            scaleMode: .fill
        )
        XCTAssertTrue(renderer is SolidColorRenderer)
    }

    func test_gif_still_returns_placeholder_until_phase_6() throws {
        let entry = pkgRoot.appendingPathComponent("clip.gif")
        try Data([0x00]).write(to: entry)
        let wallpaper = Wallpaper(title: "x", type: .gif, entryRelativePath: "clip.gif")
        let package = WallpaperPackage(root: pkgRoot)
        try package.writeMetadata(wallpaper)

        let renderer = try RendererFactory.makeRenderer(
            for: wallpaper,
            package: package,
            scaleMode: .fill
        )
        XCTAssertTrue(renderer is SolidColorRenderer)
    }
}
