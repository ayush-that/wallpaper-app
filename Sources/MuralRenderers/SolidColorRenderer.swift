import AppKit

/// A trivial renderer that fills the host with a single colour. Used as the
/// "Debug: Magenta Smoke Test" wallpaper in Phase 1 and forever after as a
/// minimal sanity check.
@MainActor
public final class SolidColorRenderer: WallpaperRenderer {
    private let color: NSColor
    private let layer = CALayer()
    private weak var host: WallpaperHost?

    public init(color: NSColor) {
        self.color = color
        layer.backgroundColor = color.cgColor
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
        // Static content, nothing to pause.
    }

    public func resume() {
        // Static content, nothing to resume.
    }
}
