import Foundation
import OSLog

/// Listens to `ProcessInfo.thermalState` and invokes injected appliers to clamp
/// video bitrate/resolution and shader framerate when the system is hot. The
/// injection model decouples the policy logic from the renderer registry — the
/// AppDelegate wires the appliers to iterate every active renderer.
@MainActor
public final class PerformanceGovernor {
    public typealias VideoApplier = @MainActor (_ bitrateBPS: Double?, _ maxPixels: CGSize?) -> Void
    public typealias ShaderApplier = @MainActor (_ fps: Int) -> Void

    private let log = Log.logger("PerfGovernor")
    private let videoApply: VideoApplier
    private let shaderApply: ShaderApplier
    private var observer: NSObjectProtocol?

    public init(videoApply: @escaping VideoApplier, shaderApply: @escaping ShaderApplier) {
        self.videoApply = videoApply
        self.shaderApply = shaderApply
    }

    public func start() {
        applyCurrentState()
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyCurrentState() }
        }
    }

    public func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func applyCurrentState() {
        let state = ProcessInfo.processInfo.thermalState
        log.info("thermal state: \(String(describing: state), privacy: .public)")
        Self.apply(state: state, videoApply: videoApply, shaderApply: shaderApply)
    }

    /// Pure mapping function — exposed for testability.
    public static func apply(
        state: ProcessInfo.ThermalState,
        videoApply: VideoApplier,
        shaderApply: ShaderApplier
    ) {
        switch state {
        case .nominal, .fair:
            videoApply(nil, nil)
            shaderApply(60)
        case .serious:
            videoApply(4_000_000, CGSize(width: 1920, height: 1080))
            shaderApply(30)
        case .critical:
            videoApply(1_000_000, CGSize(width: 1280, height: 720))
            shaderApply(15)
        @unknown default:
            videoApply(nil, nil)
            shaderApply(60)
        }
    }
}
