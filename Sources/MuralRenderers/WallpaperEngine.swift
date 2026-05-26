import AppKit
import OSLog

/// Coordinator that ties `DisplayManager` (which owns hosts) and `WallpaperRenderer`s
/// (which know how to draw) together. Owns a map from `Display.uuid` to the
/// currently-attached renderer for that display and provides the single entry
/// point for higher layers (UI, policy, pause coordinator) to swap, clear, and
/// pause/resume wallpapers.
///
/// When asked to act on a `Display` whose host is no longer present in the
/// `DisplayManager` — typically because the display was unplugged between the
/// caller's snapshot and our action — we log a warning and return rather than
/// crashing.
@MainActor
public final class WallpaperEngine {
    private let log = Log.logger("Engine")
    private let displayManager: DisplayManager
    private var current: [String: WallpaperRenderer] = [:] // keyed by Display.uuid

    public init(displayManager: DisplayManager) {
        self.displayManager = displayManager
    }

    /// Attach `renderer` to the host for `display`. Detaches any prior renderer
    /// for that display first. No-op (with a warning) if the display has no host.
    public func setRenderer(_ renderer: WallpaperRenderer, for display: Display) {
        if let prior = current[display.uuid] {
            prior.detach()
            current.removeValue(forKey: display.uuid)
        }
        guard let host = displayManager.host(for: display) else {
            log.warning("No host for display \(display.uuid, privacy: .public); attach skipped")
            return
        }
        renderer.attach(to: host)
        current[display.uuid] = renderer
    }

    /// Apply a fresh renderer (produced by `factory`) to every display known to
    /// the `DisplayManager`. Any previously-attached renderers are detached first.
    public func setRendererForAllDisplays(factory: () -> WallpaperRenderer) {
        for (uuid, host) in displayManager.hosts {
            if let prior = current[uuid] {
                prior.detach()
                current.removeValue(forKey: uuid)
            }
            let renderer = factory()
            renderer.attach(to: host)
            current[uuid] = renderer
        }
    }

    /// Detach and drop the renderer for `display`, if any.
    public func clear(for display: Display) {
        current[display.uuid]?.detach()
        current.removeValue(forKey: display.uuid)
    }

    /// Pause every active renderer. Safe to call repeatedly — renderers are
    /// required to make `pause` idempotent.
    public func pauseAll() {
        for renderer in current.values {
            renderer.pause()
        }
    }

    /// Resume every active renderer. Safe to call repeatedly.
    public func resumeAll() {
        for renderer in current.values {
            renderer.resume()
        }
    }

    /// Phase 7 `PauseCoordinator` entry point: read-only lookup by display UUID.
    public func renderer(for displayUUID: String) -> WallpaperRenderer? {
        current[displayUUID]
    }

    /// The set of display UUIDs that currently have an attached renderer.
    public var activeRendererUUIDs: [String] {
        Array(current.keys)
    }
}
