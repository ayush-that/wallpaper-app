import AppKit
import Foundation
import Metal
import MetalKit

/// `WallpaperRenderer` for `.metal` and `.glsl` shader files. Hosts a single
/// `MTKView` and delegates drawing to a `ShaderRendererCore`. ShaderToy-style
/// shaders are routed through `GLSLAdapter` and concatenated under the
/// `shadertoy-wrap.metal` template; raw MSL shaders are concatenated directly
/// onto `base.metal` (which defines `VertexOut`, `Uniforms`, and `mural_vertex`).
@MainActor
public final class ShaderRenderer: WallpaperRenderer {
    private weak var host: WallpaperHost?
    private let mtkView: MTKView
    private let core: ShaderRendererCore

    public init(shaderURL: URL, isShaderToyStyle: Bool) throws {
        let raw = try String(contentsOf: shaderURL, encoding: .utf8)
        let baseSource = try Self.loadTemplate(name: "base")
        let body: String
        if isShaderToyStyle || shaderURL.pathExtension.lowercased() == "glsl" {
            let translated = GLSLAdapter.translate(raw)
            let wrapper = try Self.loadTemplate(name: "shadertoy-wrap")
            // Only substitute the marker when it occupies its own line, so we
            // don't accidentally replace the literal `%SHADER_BODY%` text that
            // appears inside the template's own descriptive comment block.
            body = Self.substituteBody(in: wrapper, with: translated)
        } else {
            body = raw
        }
        let fullSource = baseSource + "\n" + body

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ShaderRendererError.noMetalDevice
        }
        let mtk = MTKView(frame: .zero, device: device)
        mtk.colorPixelFormat = .bgra8Unorm
        mtk.framebufferOnly = true
        mtk.layer?.isOpaque = false
        mtk.preferredFramesPerSecond = 60
        mtk.isPaused = false
        mtk.enableSetNeedsDisplay = false
        mtk.autoResizeDrawable = true

        core = try ShaderRendererCore(
            device: device,
            mslSource: fullSource,
            pixelFormat: mtk.colorPixelFormat
        )
        mtk.delegate = core
        mtkView = mtk
    }

    public func attach(to host: WallpaperHost) {
        self.host = host
        host.install(view: mtkView)
    }

    public func detach() {
        core.isPaused = true
        host?.clear()
        host = nil
    }

    public func pause() {
        core.isPaused = true
        mtkView.isPaused = true
    }

    public func resume() {
        core.isPaused = false
        mtkView.isPaused = false
    }

    /// Phase 7 hook — cap framerate under thermal pressure.
    public func setPreferredFPS(_ fps: Int) {
        mtkView.preferredFramesPerSecond = max(1, min(120, fps))
    }

    /// Phase 9 hook — forward global mouse to interactive shaders.
    public func setGlobalMouse(_ point: NSPoint, screenFrame: CGRect) {
        guard screenFrame.width > 0, screenFrame.height > 0 else { return }
        let nx = (point.x - screenFrame.minX) / screenFrame.width
        let ny = (point.y - screenFrame.minY) / screenFrame.height
        let local = CGPoint(
            x: nx * mtkView.bounds.width,
            y: ny * mtkView.bounds.height
        )
        core.setMouse(local, clicked: false)
    }

    /// Replace only the bare-on-its-own-line `%SHADER_BODY%` marker. The
    /// wrap template's leading comment mentions `%SHADER_BODY%` for human
    /// readability; we leave that occurrence alone.
    private static func substituteBody(in wrapper: String, with body: String) -> String {
        let lines = wrapper.components(separatedBy: "\n")
        let mapped = lines.map { line -> String in
            line.trimmingCharacters(in: .whitespaces) == "%SHADER_BODY%" ? body : line
        }
        return mapped.joined(separator: "\n")
    }

    private static func loadTemplate(name: String) throws -> String {
        let candidate = Bundle.main.url(
            forResource: name,
            withExtension: "metal",
            subdirectory: "Resources/shader"
        ) ?? Bundle.main.url(forResource: name, withExtension: "metal")
        guard let url = candidate else {
            throw ShaderRendererError.missingTemplate(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
