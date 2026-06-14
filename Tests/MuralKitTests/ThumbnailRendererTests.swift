import AppKit
import AVFoundation
import CoreGraphics
@testable import Mural
import XCTest

@MainActor
final class ThumbnailRendererTests: XCTestCase {
    private var tmp: URL!
    private var fixturePNG: URL!
    private var fixtureMP4: URL!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Build a real 8x8 PNG in-process so the test doesn't depend on a fixture.
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.blue.set()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let pngData = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        fixturePNG = tmp.appendingPathComponent("blue.png")
        try pngData.write(to: fixturePNG)

        // Use the Phase-2 video fixture.
        fixtureMP4 = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_render_image_writes_png_at_requested_size() throws {
        let out = tmp.appendingPathComponent("thumb.png")
        try ThumbnailRenderer.render(imageURL: fixturePNG, to: out, size: CGSize(width: 16, height: 16))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        let nsImage = try XCTUnwrap(NSImage(contentsOf: out))
        // CGImageSource's `kCGImageSourceThumbnailMaxPixelSize` is a *max*; the
        // result may be smaller (especially upscaling - it returns the original).
        XCTAssertGreaterThan(nsImage.size.width, 0)
        XCTAssertLessThanOrEqual(nsImage.size.width, 16)
    }

    func test_render_video_writes_png_for_first_frame() throws {
        let out = tmp.appendingPathComponent("vthumb.png")
        try ThumbnailRenderer.render(videoURL: fixtureMP4, to: out, size: CGSize(width: 64, height: 48))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        let nsImage = try XCTUnwrap(NSImage(contentsOf: out))
        // AVAssetImageGenerator respects `maximumSize` strictly.
        XCTAssertLessThanOrEqual(nsImage.size.width, 64)
        XCTAssertLessThanOrEqual(nsImage.size.height, 48)
    }

    func test_render_image_from_missing_file_throws_unreadable() {
        let missing = tmp.appendingPathComponent("does-not-exist.png")
        let out = tmp.appendingPathComponent("out.png")
        XCTAssertThrowsError(
            try ThumbnailRenderer.render(imageURL: missing, to: out, size: CGSize(width: 8, height: 8))
        ) { error in
            guard case ThumbnailRendererError.unreadable = error else {
                return XCTFail("expected .unreadable, got \(error)")
            }
        }
    }

    func test_render_video_from_missing_file_throws_unreadable() {
        let missing = tmp.appendingPathComponent("does-not-exist.mp4")
        let out = tmp.appendingPathComponent("out.png")
        XCTAssertThrowsError(
            try ThumbnailRenderer.render(videoURL: missing, to: out, size: CGSize(width: 8, height: 8))
        ) { error in
            guard case ThumbnailRendererError.unreadable = error else {
                return XCTFail("expected .unreadable, got \(error)")
            }
        }
    }
}
