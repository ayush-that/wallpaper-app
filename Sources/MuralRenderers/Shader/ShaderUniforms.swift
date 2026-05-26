import Foundation
import simd

/// Mirrors the MSL `Uniforms` struct in `Resources/shader/base.metal`.
/// Layout MUST stay byte-for-byte aligned: every field is 16-byte aligned via
/// explicit `_pad*` slots so Metal's automatic packing rules produce the same
/// offsets as the Swift compiler.
///
/// Field offsets / sizes:
/// - iResolution: offset 0,  size 8  (pixels)
/// - _pad0:       offset 8,  size 8  → ends at 16
/// - iMouse:      offset 16, size 16 (xy current, zw click) → ends at 32
/// - iTime:       offset 32, size 4  (seconds)
/// - iTimeDelta:  offset 36, size 4
/// - iFrame:      offset 40, size 4
/// - _pad1:       offset 44, size 4  → ends at 48
///
/// Total size: 48 bytes, stride: 48 bytes (already 16-aligned).
public struct ShaderUniforms: Equatable, Sendable {
    public var iResolution: SIMD2<Float> = .zero
    public var _pad0: SIMD2<Float> = .zero
    public var iMouse: SIMD4<Float> = .zero
    public var iTime: Float = 0
    public var iTimeDelta: Float = 0
    public var iFrame: Int32 = 0
    public var _pad1: Float = 0

    public init() {}
}
