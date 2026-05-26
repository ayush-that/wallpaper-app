// ShaderToy adapter. The runtime concatenates this AFTER base.metal.
// %SHADER_BODY% is replaced with the user's translated `mainImage(...)` function.

constexpr sampler linearSampler(coord::normalized,
                                address::repeat,
                                filter::linear);

%SHADER_BODY%

fragment float4 mural_main(VertexOut in [[stage_in]],
                           constant Uniforms& u [[buffer(0)]]) {
    float2 fragCoord = in.uv * u.iResolution;
    fragCoord.y = u.iResolution.y - fragCoord.y;     // flip Y to ShaderToy origin (bottom-left)

    float  iTime       = u.iTime;
    float  iTimeDelta  = u.iTimeDelta;
    int    iFrame      = u.iFrame;
    float2 iResolution = u.iResolution;
    float4 iMouse      = u.iMouse;

    float4 fragColor = float4(0.0);
    mainImage(fragColor, fragCoord);
    return fragColor;
}
