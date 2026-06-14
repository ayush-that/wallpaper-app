import AppKit

/// The view that lives inside a DesktopWindow and hosts whatever renderer
/// is currently active.
///
/// Renderers come in two flavors:
///   - `CALayer`-based (AVPlayerLayer, image, GIF frame layer): install via `install(layer:)`.
///   - `NSView`-based (WKWebView, MTKView, AVPlayerView): install via `install(view:)`.
///
/// Installation is atomic: the previous content (whether layer or view) is
/// removed before the new one is added. `clear()` returns the host to its
/// transparent empty state, used when pausing in "blank when paused" mode.
public final class WallpaperHost: NSView {
    override public init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public func install(layer newLayer: CALayer) {
        guard let host = layer else { return }
        host.sublayers?.forEach { $0.removeFromSuperlayer() }
        subviews.forEach { $0.removeFromSuperview() }
        newLayer.frame = host.bounds
        newLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        host.addSublayer(newLayer)
    }

    public func install(view newView: NSView) {
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        subviews.forEach { $0.removeFromSuperview() }
        newView.frame = bounds
        newView.autoresizingMask = [.width, .height]
        addSubview(newView)
    }

    public func clear() {
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        subviews.forEach { $0.removeFromSuperview() }
    }
}
