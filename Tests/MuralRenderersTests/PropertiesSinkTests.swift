import AppKit
import AVFoundation
@testable import Mural
import XCTest

@MainActor
final class PropertiesSinkTests: XCTestCase {
    // MARK: - VideoRenderer

    private func fixtureMP4() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4"
        )
    }

    func test_video_renderer_applies_playback_rate_property() throws {
        let renderer = try VideoRenderer(asset: VideoAsset(url: fixtureMP4()), scaleMode: .fill)
        renderer.attach(to: WallpaperHost(frame: .zero))
        let layer = try XCTUnwrap(renderer.testPlayerLayer)

        renderer.apply(propertyName: "playbackRate", value: .double(2.0))
        XCTAssertEqual(layer.player?.rate, 2.0)

        renderer.apply(propertyName: "playbackRate", value: .double(0.5))
        XCTAssertEqual(layer.player?.rate, 0.5)
    }

    func test_video_renderer_applies_volume_and_unmutes_on_nonzero() throws {
        let renderer = try VideoRenderer(asset: VideoAsset(url: fixtureMP4()), scaleMode: .fill)
        renderer.attach(to: WallpaperHost(frame: .zero))
        let layer = try XCTUnwrap(renderer.testPlayerLayer)

        renderer.apply(propertyName: "volume", value: .double(0.5))
        XCTAssertEqual(layer.player?.volume, 0.5)
        XCTAssertEqual(layer.player?.isMuted, false)

        renderer.apply(propertyName: "volume", value: .double(0.0))
        XCTAssertEqual(layer.player?.isMuted, true)
    }

    func test_video_renderer_applies_scale_mode_property() throws {
        let renderer = try VideoRenderer(asset: VideoAsset(url: fixtureMP4()), scaleMode: .fill)
        renderer.attach(to: WallpaperHost(frame: .zero))
        let layer = try XCTUnwrap(renderer.testPlayerLayer)
        renderer.apply(propertyName: "scaleMode", value: .string("fit"))
        XCTAssertEqual(layer.videoGravity, .resizeAspect)
    }

    func test_video_renderer_ignores_unknown_properties() throws {
        let renderer = try VideoRenderer(asset: VideoAsset(url: fixtureMP4()), scaleMode: .fill)
        renderer.attach(to: WallpaperHost(frame: .zero))
        // Must not crash.
        renderer.apply(propertyName: "definitely-not-a-property", value: .string("whatever"))
        renderer.apply(propertyName: "tint", value: .color("#ff8800"))
    }

    // MARK: - ShaderRenderer

    private func shaderURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(
                forResource: "red",
                withExtension: "metal",
                subdirectory: "Fixtures/shaders"
            ),
            "missing Tests/Fixtures/shaders/red.metal"
        )
    }

    func test_shader_renderer_accepts_user_uniform_updates() throws {
        let renderer = try ShaderRenderer(shaderURL: shaderURL(), isShaderToyStyle: false)
        renderer.attach(to: WallpaperHost(frame: .zero))
        // Must not crash.
        renderer.apply(propertyName: "speed", value: .double(1.5))
        renderer.apply(propertyName: "enabled", value: .bool(true))
        renderer.apply(propertyName: "tint", value: .color("#ff8800"))
        renderer.apply(propertyName: "engine", value: .int(2))
    }

    func test_shader_renderer_color_hex_parses_to_rgba() {
        let rgba = ShaderRenderer.parseHexColor("#ff8800")
        XCTAssertEqual(rgba.x, 1.0, accuracy: 0.005)
        XCTAssertEqual(rgba.y, Float(0x88) / 255, accuracy: 0.005)
        XCTAssertEqual(rgba.z, 0.0, accuracy: 0.005)
        XCTAssertEqual(rgba.w, 1.0)
    }

    func test_shader_renderer_color_hex_without_hash_parses() {
        let rgba = ShaderRenderer.parseHexColor("00ff00")
        XCTAssertEqual(rgba.x, 0.0, accuracy: 0.005)
        XCTAssertEqual(rgba.y, 1.0, accuracy: 0.005)
        XCTAssertEqual(rgba.z, 0.0, accuracy: 0.005)
    }

    // MARK: - WebRenderer

    private func htmlFixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "index", withExtension: "html", subdirectory: "Fixtures/web"),
            "missing Tests/Fixtures/web/index.html"
        )
    }

    func test_web_renderer_apply_delegates_to_set_property() throws {
        let url = try htmlFixtureURL()
        let renderer = WebRenderer(entryURL: url, packageRoot: url.deletingLastPathComponent())
        renderer.attach(to: WallpaperHost(frame: .zero))
        // Smoke: apply must not crash. JS invocation is unit-tested in Phase 4.
        renderer.apply(propertyName: "color", value: .color("#00ff00"))
    }
}
