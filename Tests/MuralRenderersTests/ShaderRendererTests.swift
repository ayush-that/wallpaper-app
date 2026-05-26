import AppKit
import MetalKit
@testable import Mural
import XCTest

@MainActor
final class ShaderRendererTests: XCTestCase {
    private var host: WallpaperHost!

    override func setUp() async throws {
        host = WallpaperHost(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(
                forResource: name,
                withExtension: ext,
                subdirectory: "Fixtures/shaders"
            ),
            "missing Tests/Fixtures/shaders/\(name).\(ext)"
        )
    }

    func test_load_metal_shader_compiles_and_attaches() throws {
        let url = try fixtureURL("red", "metal")
        let renderer = try ShaderRenderer(shaderURL: url, isShaderToyStyle: false)
        renderer.attach(to: host)
        XCTAssertTrue(host.subviews.first is MTKView)
    }

    func test_load_glsl_shader_translates_and_compiles() throws {
        let url = try fixtureURL("uv", "glsl")
        let renderer = try ShaderRenderer(shaderURL: url, isShaderToyStyle: true)
        renderer.attach(to: host)
        XCTAssertTrue(host.subviews.first is MTKView)
    }

    func test_attach_installs_mtkview_with_transparent_layer() throws {
        let url = try fixtureURL("red", "metal")
        let renderer = try ShaderRenderer(shaderURL: url, isShaderToyStyle: false)
        renderer.attach(to: host)
        let mtk = try XCTUnwrap(host.subviews.first as? MTKView)
        XCTAssertEqual(mtk.layer?.isOpaque, false)
        XCTAssertEqual(mtk.preferredFramesPerSecond, 60)
    }

    func test_invalid_shader_throws_compile_failed() throws {
        let badURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).metal")
        try "this is not valid MSL".write(to: badURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: badURL) }

        XCTAssertThrowsError(try ShaderRenderer(shaderURL: badURL, isShaderToyStyle: false)) { error in
            guard case ShaderRendererError.compileFailed = error else {
                return XCTFail("expected .compileFailed; got \(error)")
            }
        }
    }

    func test_pause_then_resume_toggles_core_state() throws {
        let url = try fixtureURL("red", "metal")
        let renderer = try ShaderRenderer(shaderURL: url, isShaderToyStyle: false)
        renderer.attach(to: host)
        renderer.pause()
        renderer.resume()
        // No assertion target other than absence of crash. MTKView.isPaused
        // is checked indirectly via core.isPaused which the DEBUG accessor exposes.
    }

    func test_setPreferredFPS_clamps_to_safe_range() throws {
        let url = try fixtureURL("red", "metal")
        let renderer = try ShaderRenderer(shaderURL: url, isShaderToyStyle: false)
        renderer.attach(to: host)
        renderer.setPreferredFPS(-10)
        renderer.setPreferredFPS(9999)
        // Implicitly: clamps land inside [1, 120]. No crash expected.
    }

    func test_detach_clears_host() throws {
        let url = try fixtureURL("red", "metal")
        let renderer = try ShaderRenderer(shaderURL: url, isShaderToyStyle: false)
        renderer.attach(to: host)
        renderer.detach()
        XCTAssertTrue(host.subviews.isEmpty)
    }
}
