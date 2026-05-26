import AppKit
@testable import Mural
import WebKit
import XCTest

@MainActor
final class WebRendererAudioTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "Fixtures/web"),
            "missing Tests/Fixtures/web/index.html"
        )
    }

    func test_attach_audio_subscribes_to_broadcaster() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        renderer.attach(to: WallpaperHost(frame: .zero))
        let broadcaster = AudioBroadcaster()
        renderer.attachAudio(broadcaster)
        XCTAssertEqual(broadcaster.subscriberCount, 1)
    }

    func test_detach_clears_audio_subscription() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        renderer.attach(to: WallpaperHost(frame: .zero))
        let broadcaster = AudioBroadcaster()
        renderer.attachAudio(broadcaster)
        renderer.detach()
        XCTAssertEqual(broadcaster.subscriberCount, 0)
    }

    func test_attach_audio_is_idempotent_against_repeat_calls() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        renderer.attach(to: WallpaperHost(frame: .zero))
        let broadcaster = AudioBroadcaster()
        renderer.attachAudio(broadcaster)
        renderer.attachAudio(broadcaster)
        renderer.attachAudio(broadcaster)
        XCTAssertEqual(
            broadcaster.subscriberCount, 1,
            "re-attaching to same broadcaster must replace, not duplicate"
        )
    }

    func test_detach_audio_from_different_broadcaster_is_noop() throws {
        let url = try fixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        renderer.attach(to: WallpaperHost(frame: .zero))
        let a = AudioBroadcaster()
        let b = AudioBroadcaster()
        renderer.attachAudio(a)
        renderer.detachAudio(from: b)
        XCTAssertEqual(a.subscriberCount, 1, "wrong-broadcaster detach must not unsubscribe")
    }
}
