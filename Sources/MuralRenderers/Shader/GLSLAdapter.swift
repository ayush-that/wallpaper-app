import Foundation

/// String-level adapter that rewrites a subset of ShaderToy/GLSL syntax to
/// Metal Shading Language. Covers vector/matrix type renames and the most
/// common `texture(sampler, uv)` form. Anything else (mod, mix-with-bvec,
/// gl_FragCoord, etc.) is left alone; if the resulting MSL fails to
/// compile, ShaderRenderer surfaces the error to the user.
///
/// Known limitations (v1):
/// - Multi-arg `texture(channel, uv, bias)` overloads are not rewritten.
/// - GLSL `mod` (float-accepting) is left alone; MSL requires `fmod`.
/// - Other ShaderToy idioms (e.g. `gl_FragCoord`) pass through unchanged.
public enum GLSLAdapter {
    public static func translate(_ glsl: String) -> String {
        var result = glsl
        for pair in patterns {
            result = result.replacingOccurrences(
                of: pair.pattern,
                with: pair.replacement,
                options: .regularExpression
            )
        }
        return result
    }

    private struct Pair {
        let pattern: String
        let replacement: String
    }

    private static let patterns: [Pair] = [
        Pair(pattern: #"\bvec2\b"#, replacement: "float2"),
        Pair(pattern: #"\bvec3\b"#, replacement: "float3"),
        Pair(pattern: #"\bvec4\b"#, replacement: "float4"),
        Pair(pattern: #"\bmat2\b"#, replacement: "float2x2"),
        Pair(pattern: #"\bmat3\b"#, replacement: "float3x3"),
        Pair(pattern: #"\bmat4\b"#, replacement: "float4x4"),
        Pair(
            pattern: #"texture\(\s*(\w+)\s*,\s*([^)]+)\)"#,
            replacement: "$1.sample(linearSampler, $2)"
        )
    ]
}
