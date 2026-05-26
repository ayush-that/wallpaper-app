import AppKit
@testable import Mural
import WebKit
import XCTest

@MainActor
final class WebRendererTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "Fixtures/web"),
            "missing Tests/Fixtures/web/index.html"
        )
    }

    private func makeHost() -> WallpaperHost {
        WallpaperHost(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    }

    func test_attach_installs_wkwebview_with_transparent_background() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        let host = makeHost()
        renderer.attach(to: host)
        let webView = try XCTUnwrap(host.subviews.first as? WKWebView)
        XCTAssertEqual(webView.value(forKey: "drawsBackground") as? Bool, false)
    }

    func test_console_message_round_trips_from_js_to_native() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        var captured: [WebBridgeMessage] = []
        renderer.onBridgeMessage = { captured.append($0) }
        renderer.attach(to: makeHost())

        let expectation = expectation(description: "console message arrives")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let consoleHits = captured.compactMap { message -> String? in
                if case let .console(_, text) = message { return text }
                return nil
            }
            let matched = consoleHits.contains(where: { $0.contains("hello from web wallpaper") })
            XCTAssertTrue(matched, "expected to receive 'hello from web wallpaper' console message; got \(consoleHits)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }

    func test_set_property_invokes_livelyPropertyListener() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        renderer.attach(to: makeHost())

        let expectation = expectation(description: "dot background changes after setProperty")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            renderer.set(property: "color", value: .color("#00ff00"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let webView = renderer.testWebView
                webView.evaluateJavaScript("document.getElementById('dot').style.background") { result, _ in
                    let css = (result as? String) ?? ""
                    XCTAssertTrue(
                        css.contains("rgb(0, 255, 0)") || css.contains("#00ff00") || css.contains("0, 255, 0"),
                        "expected green; got '\(css)'"
                    )
                    expectation.fulfill()
                }
            }
        }
        wait(for: [expectation], timeout: 6.0)
    }

    func test_detach_clears_host() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        let host = makeHost()
        renderer.attach(to: host)
        renderer.detach()
        XCTAssertTrue(host.subviews.isEmpty)
    }
}
