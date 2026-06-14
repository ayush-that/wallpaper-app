import AppKit
import AVFoundation
@testable import Mural
import XCTest

@MainActor
final class VideoRendererTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    private func makeHost() -> WallpaperHost {
        WallpaperHost(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    }

    func test_attach_installs_AVPlayerLayer_and_starts_playback() throws {
        let url = try fixtureURL()
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        let host = makeHost()
        renderer.attach(to: host)

        let layers = host.layer?.sublayers ?? []
        XCTAssertEqual(layers.count, 1)
        let playerLayer = try XCTUnwrap(layers.first as? AVPlayerLayer)
        XCTAssertNotNil(playerLayer.player)
        XCTAssertEqual(playerLayer.videoGravity, .resizeAspectFill)

        let expectation = expectation(description: "player rate > 0")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertGreaterThan(playerLayer.player?.rate ?? 0, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func test_audio_is_muted_and_audio_mix_is_nil() throws {
        let url = try fixtureURL()
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        renderer.attach(to: makeHost())
        let layer = try XCTUnwrap(renderer.testPlayerLayer)
        let player = try XCTUnwrap(layer.player as? AVQueuePlayer)
        XCTAssertTrue(player.isMuted)
        XCTAssertNil(player.currentItem?.audioMix)
    }

    func test_pause_zeroes_rate_resume_restores_it() throws {
        let url = try fixtureURL()
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        renderer.attach(to: makeHost())
        let layer = try XCTUnwrap(renderer.testPlayerLayer)

        renderer.pause()
        XCTAssertEqual(layer.player?.rate ?? 1, 0)

        renderer.resume()
        let expectation = expectation(description: "resumed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertGreaterThan(layer.player?.rate ?? 0, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func test_setScaleMode_updates_videoGravity_without_reload() throws {
        let url = try fixtureURL()
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        renderer.attach(to: makeHost())
        let layer = try XCTUnwrap(renderer.testPlayerLayer)
        let originalPlayer = layer.player

        renderer.setScaleMode(.fit)
        XCTAssertEqual(layer.videoGravity, .resizeAspect)
        XCTAssertTrue(layer.player === originalPlayer, "scale change must not rebuild player")

        renderer.setScaleMode(.stretch)
        XCTAssertEqual(layer.videoGravity, .resize)
    }

    func test_detach_clears_host_but_keeps_player_alive_for_reattach() throws {
        let url = try fixtureURL()
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        let host = makeHost()
        renderer.attach(to: host)

        renderer.detach()
        XCTAssertTrue(host.layer?.sublayers?.isEmpty ?? true)

        // Re-attach to verify the player survived
        renderer.attach(to: host)
        XCTAssertEqual(host.layer?.sublayers?.count, 1)
    }

    func test_setPreferredCeiling_applies_to_current_item() throws {
        let url = try fixtureURL()
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        renderer.attach(to: makeHost())
        renderer.setPreferredCeiling(bitrateBPS: 1_500_000, maxPixels: CGSize(width: 1920, height: 1080))
        let item = try XCTUnwrap(renderer.testCurrentItem)
        XCTAssertEqual(item.preferredPeakBitRate, 1_500_000)
        XCTAssertEqual(item.preferredMaximumResolution, CGSize(width: 1920, height: 1080))
    }

    func test_webm_vp9_loads_and_plays() throws {
        let url = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "webm", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.webm"
        )
        let renderer = try VideoRenderer(asset: VideoAsset(url: url), scaleMode: .fill)
        let host = makeHost()
        renderer.attach(to: host)
        let layer = try XCTUnwrap(host.layer?.sublayers?.first as? AVPlayerLayer)

        let expectation = expectation(description: "VP9 player rate > 0")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertGreaterThan(
                layer.player?.rate ?? 0,
                0,
                "VP9 didn't start playing - check macOS / AVFoundation VP9 support"
            )
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
    }
}
