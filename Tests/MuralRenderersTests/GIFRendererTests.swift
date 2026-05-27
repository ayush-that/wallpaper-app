import AppKit
import CoreGraphics
@testable import Mural
import XCTest

@MainActor
final class GIFRendererTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "2frame", withExtension: "gif", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/2frame.gif"
        )
    }

    func test_attach_installs_layer_with_first_frame() throws {
        let renderer = try GIFRenderer(url: fixtureURL(), scaleMode: .fill)
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        renderer.attach(to: host)
        let layer = try XCTUnwrap(host.layer?.sublayers?.first)
        XCTAssertNotNil(layer.contents)
        XCTAssertEqual(layer.contentsGravity, .resizeAspectFill)
    }

    func test_scale_mode_fit_maps_to_resizeAspect() throws {
        let renderer = try GIFRenderer(url: fixtureURL(), scaleMode: .fit)
        let host = WallpaperHost(frame: .zero)
        renderer.attach(to: host)
        let layer = try XCTUnwrap(host.layer?.sublayers?.first)
        XCTAssertEqual(layer.contentsGravity, .resizeAspect)
    }

    func test_pause_resume_does_not_crash() throws {
        let renderer = try GIFRenderer(url: fixtureURL(), scaleMode: .fill)
        renderer.attach(to: WallpaperHost(frame: .zero))
        renderer.pause()
        renderer.resume()
        renderer.pause()
    }

    func test_detach_clears_host() throws {
        let renderer = try GIFRenderer(url: fixtureURL(), scaleMode: .fill)
        let host = WallpaperHost(frame: .zero)
        renderer.attach(to: host)
        renderer.detach()
        XCTAssertTrue(host.layer?.sublayers?.isEmpty ?? true)
    }

    func test_invalid_gif_throws() {
        let bad = URL(fileURLWithPath: "/dev/null")
        XCTAssertThrowsError(try GIFRenderer(url: bad, scaleMode: .fill))
    }

    func test_reattach_after_detach_resumes_animation() throws {
        let renderer = try GIFRenderer(url: fixtureURL(), scaleMode: .fill)
        let host = WallpaperHost(frame: .zero)
        renderer.attach(to: host)
        renderer.detach()
        renderer.attach(to: host)
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
    }
}
