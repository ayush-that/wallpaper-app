import AppKit
@testable import Mural
import XCTest

@MainActor
final class WallpaperHostTests: XCTestCase {
    func test_host_is_layer_backed_with_resize_redraw() {
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(host.wantsLayer)
        XCTAssertNotNil(host.layer)
        XCTAssertEqual(host.layerContentsRedrawPolicy, .duringViewResize)
    }

    func test_install_layer_replaces_previous_sublayer() {
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let a = CALayer()
        a.backgroundColor = NSColor.red.cgColor
        let b = CALayer()
        b.backgroundColor = NSColor.green.cgColor

        host.install(layer: a)
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
        XCTAssertTrue(host.layer?.sublayers?.contains(a) == true)

        host.install(layer: b)
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
        XCTAssertTrue(host.layer?.sublayers?.contains(b) == true)
        XCTAssertFalse(host.layer?.sublayers?.contains(a) == true)
    }

    func test_install_view_replaces_previous_subview() {
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let v = NSView()
        host.install(view: v)
        XCTAssertEqual(host.subviews, [v])

        let w = NSView()
        host.install(view: w)
        XCTAssertEqual(host.subviews, [w])
    }

    func test_install_layer_then_install_view_replaces_layer() {
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let layer = CALayer()
        host.install(layer: layer)
        XCTAssertEqual(host.layer?.sublayers?.count, 1)

        let v = NSView()
        host.install(view: v)
        XCTAssertTrue((host.layer?.sublayers ?? []).isEmpty)
        XCTAssertEqual(host.subviews, [v])
    }

    func test_clear_removes_everything() {
        let host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        host.install(layer: CALayer())
        host.install(view: NSView())
        host.install(layer: CALayer())
        host.clear()
        XCTAssertTrue((host.layer?.sublayers ?? []).isEmpty)
        XCTAssertTrue(host.subviews.isEmpty)
    }
}
