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
    private var activeWallpaperIDs: [String: UUID] = [:] // keyed by Display.uuid

    /// Optional library root used when persisting `ActiveStatus`. Wired by the
    /// orchestrator from `LibraryService.libraryRoot` on construction. While
    /// nil, `persistActive()` is a no-op so unit tests that don't care about
    /// disk side effects can stand the engine up bare.
    public var libraryRoot: URL?

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

    /// Variant that records the wallpaper ID for this display so the engine can
    /// publish an `ActiveStatus` snapshot. The zero-ID overload above remains
    /// for callers that don't have a wallpaper identity (test renderers, the
    /// solid-colour fallback path).
    public func setRenderer(
        _ renderer: WallpaperRenderer,
        for display: Display,
        wallpaperID: UUID
    ) {
        setRenderer(renderer, for: display)
        activeWallpaperIDs[display.uuid] = wallpaperID
        persistActive()
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

    /// Variant that records `wallpaperID` against every display the factory
    /// applies to, then persists `ActiveStatus`.
    public func setRendererForAllDisplays(
        factory: () -> WallpaperRenderer,
        wallpaperID: UUID
    ) {
        setRendererForAllDisplays(factory: factory)
        for uuid in displayManager.hosts.keys {
            activeWallpaperIDs[uuid] = wallpaperID
        }
        persistActive()
    }

    /// Detach and drop the renderer for `display`, if any. Also clears any
    /// recorded wallpaper ID and re-persists `ActiveStatus` if the entry
    /// actually existed.
    public func clear(for display: Display) {
        current[display.uuid]?.detach()
        current.removeValue(forKey: display.uuid)
        if activeWallpaperIDs.removeValue(forKey: display.uuid) != nil {
            persistActive()
        }
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

    /// Write the current `(display, wallpaperID)` map to disk. Silently swallows
    /// errors — losing one snapshot is preferable to crashing the renderer
    /// pipeline; readers (screensaver bundle etc.) will pick up the next write.
    private func persistActive() {
        guard let libraryRoot else { return }
        let snapshot = ActiveStatus(
            displays: activeWallpaperIDs.map { uuid, wallpaperID in
                ActiveStatus.PerDisplay(displayUUID: uuid, wallpaperID: wallpaperID)
            },
            libraryRoot: libraryRoot.path
        )
        do {
            try ActiveStatus.write(snapshot)
        } catch {
            log.error("ActiveStatus write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
