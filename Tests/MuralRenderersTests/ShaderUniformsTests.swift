@testable import Mural
import XCTest

final class ShaderUniformsTests: XCTestCase {
    func test_uniforms_size_is_48_bytes() {
        XCTAssertEqual(MemoryLayout<ShaderUniforms>.size, 48)
    }

    func test_uniforms_stride_is_16_byte_aligned() {
        XCTAssertEqual(
            MemoryLayout<ShaderUniforms>.stride % 16,
            0,
            "Metal requires 16-byte alignment for constant buffer entries"
        )
    }

    func test_default_init_zeros_all_fields() {
        let u = ShaderUniforms()
        XCTAssertEqual(u.iTime, 0)
        XCTAssertEqual(u.iTimeDelta, 0)
        XCTAssertEqual(u.iFrame, 0)
        XCTAssertEqual(u.iResolution, .zero)
        XCTAssertEqual(u.iMouse, .zero)
    }

    func test_mutate_iResolution_persists() {
        var u = ShaderUniforms()
        u.iResolution = SIMD2<Float>(1920, 1080)
        XCTAssertEqual(u.iResolution.x, 1920)
        XCTAssertEqual(u.iResolution.y, 1080)
    }

    func test_msl_base_template_exists_in_bundle() throws {
        let url = Bundle.main.url(
            forResource: "base",
            withExtension: "metal",
            subdirectory: "Resources/shader"
        ) ?? Bundle.main.url(forResource: "base", withExtension: "metal")
        let resolved = try XCTUnwrap(
            url,
            "base.metal not bundled - check Resources/shader/ in project.yml"
        )
        let source = try String(contentsOf: resolved, encoding: .utf8)
        XCTAssertTrue(source.contains("mural_vertex"), "base.metal must declare mural_vertex")
        XCTAssertTrue(source.contains("struct Uniforms"), "base.metal must declare Uniforms struct")
        XCTAssertTrue(source.contains("VertexOut"), "base.metal must declare VertexOut")
    }

    func test_msl_shadertoy_wrap_template_exists_with_placeholder() throws {
        let url = Bundle.main.url(
            forResource: "shadertoy-wrap",
            withExtension: "metal",
            subdirectory: "Resources/shader"
        ) ?? Bundle.main.url(forResource: "shadertoy-wrap", withExtension: "metal")
        let resolved = try XCTUnwrap(url, "shadertoy-wrap.metal not bundled")
        let source = try String(contentsOf: resolved, encoding: .utf8)
        XCTAssertTrue(source.contains("%SHADER_BODY%"), "wrapper missing template placeholder")
        XCTAssertTrue(source.contains("mural_main"), "wrapper must declare mural_main fragment")
        XCTAssertTrue(source.contains("mainImage"), "wrapper must invoke user's mainImage(...)")
    }
}
