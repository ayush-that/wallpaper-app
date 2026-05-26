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
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
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
