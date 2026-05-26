import AppKit
@testable import Mural
import XCTest

@MainActor
final class ImageRendererTests: XCTestCase {
    private var tmpURL: URL!

    override func setUp() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.blue.set()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let pngData = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        tmpURL = dir.appendingPathComponent("blue.png")
        try pngData.write(to: tmpURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }

    func test_attach_installs_layer_with_image_contents() throws {
        let renderer = ImageRenderer(url: tmpURL, scaleMode: .fill)
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        renderer.attach(to: host)
        let layer = try XCTUnwrap(host.layer?.sublayers?.first)
        XCTAssertNotNil(layer.contents)
        XCTAssertEqual(layer.contentsGravity, .resizeAspectFill)
    }

    func test_setScaleMode_updates_gravity_without_reload() throws {
        let renderer = ImageRenderer(url: tmpURL, scaleMode: .fill)
        let host = WallpaperHost(frame: .zero)
        renderer.attach(to: host)
        let layer = try XCTUnwrap(host.layer?.sublayers?.first)
        let originalContents = layer.contents
        renderer.setScaleMode(.fit)
        XCTAssertEqual(layer.contentsGravity, .resizeAspect)
        XCTAssertTrue(layer.contents as AnyObject? === originalContents as AnyObject?)
    }

    func test_detach_clears_host() {
        let renderer = ImageRenderer(url: tmpURL, scaleMode: .fill)
        let host = WallpaperHost(frame: .zero)
        renderer.attach(to: host)
        renderer.detach()
        XCTAssertTrue(host.layer?.sublayers?.isEmpty ?? true)
    }

    func test_unreadable_url_does_not_crash() {
        let bogus = URL(fileURLWithPath: "/tmp/does-not-exist.png")
        let renderer = ImageRenderer(url: bogus, scaleMode: .fill)
        let host = WallpaperHost(frame: .zero)
        renderer.attach(to: host)
        // Layer is installed but `contents` is nil — visible as a transparent square.
        let layer = host.layer?.sublayers?.first
        XCTAssertNotNil(layer)
        XCTAssertNil(layer?.contents)
    }
}
