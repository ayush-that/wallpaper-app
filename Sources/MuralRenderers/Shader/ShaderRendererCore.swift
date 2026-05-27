import Metal
import MetalKit
import OSLog
import QuartzCore
import simd

public enum ShaderRendererError: Error, Equatable {
    case noMetalDevice
    case loadFailed(String)
    case compileFailed(String)
    case pipelineFailed(String)
    case missingTemplate(String)
}

/// `MTKViewDelegate` that submits a single fullscreen-triangle draw per frame.
/// The pipeline state is built from a string of MSL at init; `iTime`,
/// `iTimeDelta`, and `iFrame` are advanced inside `draw(in:)` and copied into
/// the fragment shader via `setFragmentBytes`.
@MainActor
public final class ShaderRendererCore: NSObject, MTKViewDelegate {
    private let log = Log.logger("ShaderCore")

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    private var uniforms = ShaderUniforms()
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()
    private var frame: Int32 = 0
    public var isPaused = false

    /// Phase 9 user uniforms — written by `PropertiesSink.apply` on `ShaderRenderer`
    /// and packed into fragment buffer slot 1 every frame. Dictionary keys are
    /// property names; the on-GPU layout sorts by name so a shader can declare
    /// `constant float4 user[16] [[buffer(1)]]` and address slots positionally.
    private var userUniforms: [String: SIMD4<Float>] = [:]
    private let maxUserUniforms = 16

    public init(device: MTLDevice, mslSource: String, pixelFormat: MTLPixelFormat) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw ShaderRendererError.noMetalDevice
        }
        commandQueue = queue

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: mslSource, options: nil)
        } catch {
            throw ShaderRendererError.compileFailed(String(describing: error))
        }
        guard let vertexFn = library.makeFunction(name: "mural_vertex"),
              let fragmentFn = library.makeFunction(name: "mural_main")
        else {
            throw ShaderRendererError.compileFailed("missing mural_vertex or mural_main")
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFn
        desc.fragmentFunction = fragmentFn
        desc.colorAttachments[0].pixelFormat = pixelFormat
        do {
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            throw ShaderRendererError.pipelineFailed(String(describing: error))
        }
        super.init()
    }

    public func mtkView(_: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.iResolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    public func draw(in view: MTKView) {
        guard !isPaused,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = commandQueue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        let now = CACurrentMediaTime()
        uniforms.iTime = Float(now - startTime)
        uniforms.iTimeDelta = Float(now - lastTime)
        uniforms.iFrame = frame
        lastTime = now
        frame &+= 1

        encoder.setRenderPipelineState(pipeline)
        var snapshot = uniforms
        encoder.setFragmentBytes(
            &snapshot,
            length: MemoryLayout<ShaderUniforms>.stride,
            index: 0
        )

        // Pack user uniforms into a fixed-size 16-slot float4 array. Sorted by
        // name so the GPU layout is deterministic — shaders that opt in declare
        // `constant float4 user[16] [[buffer(1)]]`; shaders that don't simply
        // ignore the binding.
        var userBuffer = [SIMD4<Float>](
            repeating: SIMD4<Float>(0, 0, 0, 0),
            count: maxUserUniforms
        )
        for (index, name) in userUniforms.keys.sorted().enumerated() where index < maxUserUniforms {
            userBuffer[index] = userUniforms[name] ?? .zero
        }
        encoder.setFragmentBytes(
            &userBuffer,
            length: MemoryLayout<SIMD4<Float>>.stride * maxUserUniforms,
            index: 1
        )

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }

    /// Write (or overwrite) a single-channel user uniform. The value lands in
    /// the `x` channel of a `float4`; remaining channels are zero.
    public func setUserUniform(name: String, value: Float) {
        setUserUniform(name: name, rgba: SIMD4<Float>(value, 0, 0, 0))
    }

    /// Write (or overwrite) a four-channel user uniform — typically an RGBA
    /// colour. Silently drops new keys once the 16-slot cap is reached so the
    /// fixed-size GPU layout never overflows.
    public func setUserUniform(name: String, rgba: SIMD4<Float>) {
        if userUniforms[name] == nil, userUniforms.count >= maxUserUniforms {
            return
        }
        userUniforms[name] = rgba
    }

    public func setMouse(_ point: CGPoint, clicked: Bool) {
        uniforms.iMouse = SIMD4<Float>(
            Float(point.x),
            Float(point.y),
            clicked ? 1 : 0,
            0
        )
    }

    #if DEBUG
        /// Test-only accessor for assertions on the uniform state.
        public var testUniformsSnapshot: ShaderUniforms {
            uniforms
        }
    #endif
}
