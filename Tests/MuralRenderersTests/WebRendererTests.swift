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

        // Fulfill as soon as the expected message arrives rather than sampling
        // once after a fixed delay: a headless WebView in CI can take longer
        // than a couple of seconds to load the page and round-trip the console
        // call, which made the fixed-delay version flaky.
        let expectation = expectation(description: "console message arrives")
        expectation.assertForOverFulfill = false
        renderer.onBridgeMessage = { message in
            if case let .console(_, text) = message, text.contains("hello from web wallpaper") {
                expectation.fulfill()
            }
        }
        renderer.attach(to: makeHost())

        wait(for: [expectation], timeout: 15.0)
    }

    func test_set_property_invokes_livelyPropertyListener() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())

        let expectation = expectation(description: "dot background changes after setProperty")
        expectation.assertForOverFulfill = false

        func pollForGreen(attemptsLeft: Int) {
            renderer.testWebView.evaluateJavaScript("document.getElementById('dot').style.background") { result, _ in
                let css = (result as? String) ?? ""
                if css.contains("rgb(0, 255, 0)") || css.contains("#00ff00") || css.contains("0, 255, 0") {
                    expectation.fulfill()
                } else if attemptsLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pollForGreen(attemptsLeft: attemptsLeft - 1)
                    }
                }
            }
        }

        var started = false
        renderer.onBridgeMessage = { message in
            guard !started, case let .console(_, text) = message,
                  text.contains("hello from web wallpaper") else { return }
            started = true
            renderer.set(property: "color", value: .color("#00ff00"))
            pollForGreen(attemptsLeft: 50)
        }
        renderer.attach(to: makeHost())

        wait(for: [expectation], timeout: 15.0)
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
