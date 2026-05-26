import AppKit
@testable import Mural
import XCTest

@MainActor
final class SolidColorRendererTests: XCTestCase {
    func test_attach_installs_layer_with_expected_background_color() {
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        let renderer = SolidColorRenderer(color: NSColor.magenta)
        renderer.attach(to: host)
        let installed = host.layer?.sublayers?.first
        XCTAssertEqual(installed?.backgroundColor, NSColor.magenta.cgColor)
    }

    func test_pause_does_not_remove_layer() {
        let host = WallpaperHost(frame: .zero)
        let renderer = SolidColorRenderer(color: NSColor.red)
        renderer.attach(to: host)
        renderer.pause()
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
    }

    func test_resume_is_idempotent_when_not_paused() {
        let host = WallpaperHost(frame: .zero)
        let renderer = SolidColorRenderer(color: NSColor.red)
        renderer.attach(to: host)
        renderer.resume()
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
    }

    func test_detach_clears_host() {
        let host = WallpaperHost(frame: .zero)
        let renderer = SolidColorRenderer(color: NSColor.red)
        renderer.attach(to: host)
        renderer.detach()
        XCTAssertTrue(host.layer?.sublayers?.isEmpty ?? true)
    }

    func test_reattach_after_detach_reinstalls_layer() {
        let host = WallpaperHost(frame: .zero)
        let renderer = SolidColorRenderer(color: NSColor.red)
        renderer.attach(to: host)
        renderer.detach()
        renderer.attach(to: host)
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
    }
}
