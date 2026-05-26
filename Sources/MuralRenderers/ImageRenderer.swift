import AppKit

/// Renders a static image as a wallpaper. Backed by a single `CALayer` whose
/// `contents` is a `CGImage`. `ScaleMode` maps to `contentsGravity`; there is
/// no animation, so `pause` and `resume` are no-ops. If the image fails to
/// decode, the layer is still attached but `contents` is `nil` — visible as a
/// transparent square rather than a crash.
@MainActor
public final class ImageRenderer: WallpaperRenderer {
    private let url: URL
    private let layer = CALayer()
    private weak var host: WallpaperHost?

    public init(url: URL, scaleMode: ScaleMode) {
        self.url = url
        layer.contentsGravity = Self.gravity(for: scaleMode)
        if let image = NSImage(contentsOf: url),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        {
            layer.contents = cg
        }
    }

    public func attach(to host: WallpaperHost) {
        self.host = host
        host.install(layer: layer)
    }

    public func detach() {
        host?.clear()
        host = nil
    }

    public func pause() {
        // Static content — nothing to pause.
    }

    public func resume() {
        // Static content — nothing to resume.
    }

    public func setScaleMode(_ mode: ScaleMode) {
        layer.contentsGravity = Self.gravity(for: mode)
    }

    private static func gravity(for mode: ScaleMode) -> CALayerContentsGravity {
        switch mode {
        case .fill, .stretch: .resizeAspectFill
        case .fit: .resizeAspect
        case .center: .center
        case .tile: .resizeAspectFill // CAReplicatorLayer-based tile is a future polish; v1 falls back to fill
        }
    }
}
