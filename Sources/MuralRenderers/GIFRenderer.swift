import AppKit
import CoreGraphics
import CoreVideo
import OSLog
import QuartzCore

/// Renders an animated GIF as a wallpaper. The frames are decoded eagerly by
/// `GIFFrameSequence`; this class owns a `CALayer` and a `CVDisplayLink` that
/// fires once per refresh, computing the right frame for the elapsed time and
/// swapping `layer.contents` on the main thread inside an action-disabled
/// `CATransaction`.
///
/// `pause` flips a flag — the display link keeps ticking, but `tick()` short-
/// circuits. This is cheaper than starting/stopping the link and keeps the
/// resume path instant.
///
/// macOS 14 baseline. `NSScreen.displayLink(target:selector:)` is macOS 15+,
/// so we use the deprecated-on-15 `CVDisplayLink` API; the deprecation
/// warning is suppressed narrowly on the specific call sites that need it.
@MainActor
public final class GIFRenderer: WallpaperRenderer {
    private let log = Log.logger("GIFRenderer")
    private let sequence: GIFFrameSequence
    private let scaleMode: ScaleMode
    private let layer = CALayer()
    private weak var host: WallpaperHost?
    private var displayLink: CVDisplayLink?
    private let startTime = CACurrentMediaTime()
    private var isPaused = false

    public init(url: URL, scaleMode: ScaleMode) throws {
        sequence = try GIFFrameSequence(url: url)
        self.scaleMode = scaleMode
        layer.contentsGravity = Self.gravity(for: scaleMode)
        layer.contents = sequence.frames.first?.image
    }

    public func attach(to host: WallpaperHost) {
        self.host = host
        host.install(layer: layer)
        startDisplayLink()
    }

    public func detach() {
        stopDisplayLink()
        host?.clear()
        host = nil
    }

    public func pause() {
        isPaused = true
    }

    public func resume() {
        isPaused = false
    }

    private static func gravity(for mode: ScaleMode) -> CALayerContentsGravity {
        switch mode {
        case .fill, .stretch: .resizeAspectFill
        case .fit: .resizeAspect
        case .center: .center
        case .tile: .resizeAspectFill // CAReplicatorLayer-based tile is Phase 9 polish
        }
    }

    // MARK: - Display link

    @available(
        macOS,
        deprecated: 15.0,
        message: "Replace with NSScreen.displayLink once macOS 15 is the minimum target"
    )
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        var link: CVDisplayLink?
        let createResult = CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard createResult == kCVReturnSuccess, let link else {
            log.error("CVDisplayLinkCreateWithActiveCGDisplays failed (\(createResult))")
            return
        }
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, ctx in
            guard let ctx else { return kCVReturnSuccess }
            let me = Unmanaged<GIFRenderer>.fromOpaque(ctx).takeUnretainedValue()
            // CVDisplayLink callbacks fire on a private thread; bounce to main
            // to mutate `layer.contents`. `assumeIsolated` tells strict
            // concurrency we're already on the main actor at the call site.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    me.tick()
                }
            }
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(link, callback, opaque)
        CVDisplayLinkStart(link)
        displayLink = link
    }

    @available(
        macOS,
        deprecated: 15.0,
        message: "Replace with NSScreen.displayLink once macOS 15 is the minimum target"
    )
    private func stopDisplayLink() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
    }

    private func tick() {
        guard !isPaused else { return }
        let elapsed = CACurrentMediaTime() - startTime
        let progress = elapsed / max(sequence.totalDuration, 0.001)
        guard let frame = sequence.frame(at: progress) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = frame.image
        CATransaction.commit()
    }
}
