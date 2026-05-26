@testable import Mural
import XCTest

final class GLSLAdapterTests: XCTestCase {
    func test_vec_types_are_translated() {
        let glsl = "vec2 a; vec3 b; vec4 c;"
        XCTAssertEqual(GLSLAdapter.translate(glsl), "float2 a; float3 b; float4 c;")
    }

    func test_mat_types_are_translated() {
        let glsl = "mat2 m2; mat3 m3; mat4 m4;"
        XCTAssertEqual(GLSLAdapter.translate(glsl), "float2x2 m2; float3x3 m3; float4x4 m4;")
    }

    func test_texture_sampler_call_rewrites_to_sample() {
        let glsl = "vec4 c = texture(iChannel0, uv);"
        XCTAssertEqual(
            GLSLAdapter.translate(glsl),
            "float4 c = iChannel0.sample(linearSampler, uv);"
        )
    }

    func test_texture_with_spaces_in_call_normalises() {
        let glsl = "texture( iChannel0 , vec2(0.5, 0.5) )"
        // The `\s*` patterns allow leading/trailing whitespace inside the parens.
        // The replacement preserves the second arg verbatim including its inner parens.
        let result = GLSLAdapter.translate(glsl)
        XCTAssertTrue(
            result.contains("iChannel0.sample(linearSampler"),
            "got: \(result)"
        )
    }

    func test_word_boundary_avoids_partial_replacement() {
        // `vec2f` is NOT `vec2 f`; we must not rewrite it to `float2f`.
        let glsl = "vec2f"
        XCTAssertEqual(GLSLAdapter.translate(glsl), "vec2f")
    }

    func test_word_boundary_avoids_replacement_in_identifier_suffix() {
        let glsl = "myvec3"
        XCTAssertEqual(GLSLAdapter.translate(glsl), "myvec3")
    }

    func test_passes_through_msl_already() {
        // Already-MSL code should be a no-op.
        let msl = "float4 frag = float4(0.0); float x = mix(0.0, 1.0, t);"
        XCTAssertEqual(GLSLAdapter.translate(msl), msl)
    }

    func test_leaves_unsupported_constructs_alone() {
        // `mod` and `gl_FragCoord` aren't handled. They pass through unchanged.
        let glsl = "vec3 p = vec3(mod(gl_FragCoord.x, 1.0), 0.0, 0.0);"
        // vec3 → float3 still applies; mod, gl_FragCoord stay.
        let expected = "float3 p = float3(mod(gl_FragCoord.x, 1.0), 0.0, 0.0);"
        XCTAssertEqual(GLSLAdapter.translate(glsl), expected)
    }

    func test_translates_full_simple_main_image() {
        let glsl = """
        void mainImage(out vec4 fragColor, in vec2 fragCoord) {
            vec2 uv = fragCoord / iResolution.xy;
            fragColor = vec4(uv, 0.5, 1.0);
        }
        """
        let result = GLSLAdapter.translate(glsl)
        XCTAssertFalse(result.contains("vec2"))
        XCTAssertFalse(result.contains("vec4"))
        XCTAssertTrue(result.contains("float2 uv"))
        XCTAssertTrue(result.contains("float4(uv, 0.5, 1.0)"))
    }

    func test_idempotent_on_already_translated_source() {
        let glsl = "vec2 a;"
        let once = GLSLAdapter.translate(glsl)
        let twice = GLSLAdapter.translate(once)
        XCTAssertEqual(once, twice)
    }
}
