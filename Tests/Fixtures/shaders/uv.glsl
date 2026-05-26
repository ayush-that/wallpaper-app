void mainImage(thread vec4& fragColor, vec2 fragCoord) {
    vec2 uv = fragCoord;
    fragColor = vec4(uv.x, uv.y, 0.5, 1.0);
}
