#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float2 iResolution;
    float2 _pad0;
    float4 iMouse;
    float  iTime;
    float  iTimeDelta;
    int    iFrame;
    float  _pad1;
};

// Fullscreen triangle via a single triangle that overdraws the viewport.
// Three vertices in clip space cover the [-1,1]^2 quad without an index buffer.
vertex VertexOut mural_vertex(uint vid [[vertex_id]]) {
    float2 pos = float2(
        (vid == 2) ? 3.0 : -1.0,
        (vid == 1) ? -3.0 : 1.0
    );
    VertexOut out;
    out.position = float4(pos, 0.0, 1.0);
    out.uv = (pos * 0.5) + 0.5;
    return out;
}
