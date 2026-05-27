import AppKit
import OSLog
import SwiftUI

/// SwiftUI installs `showSettingsWindow:` on NSApplication at runtime
/// (it's the action behind the standard Cmd-, menu item for a Settings
/// scene). It isn't declared in any public header, so we forward-declare
/// it here purely to get a typed #selector reference instead of a stringly
/// typed Selector(("showSettingsWindow:")).
@objc private protocol _MuralSettingsAction {
    func showSettingsWindow(_ sender: Any?)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Log.logger("AppDelegate")
    private let settings = SettingsStore()

    private var statusItem: StatusItemController?
    private var logSink: LogFileSink?
    private var displayManager: DisplayManager?
    private var engine: WallpaperEngine?
    private var activeScaleMode: ScaleMode = .fill
    private var userPaused = false

    // Phase 7: pause/throttle policy stack.
    private var pauseCoordinator: PauseCoordinator?
    private var powerWatcher: PowerWatcher?
    private var foregroundAppWatcher: ForegroundAppWatcher?
    private var fullscreenWatcher: FullscreenWatcher?
    private var remoteSessionWatcher: RemoteSessionWatcher?
    private var performanceGovernor: PerformanceGovernor?

    private(set) var libraryService: LibraryService?
    private(set) var libraryViewModel: LibraryViewModel?
    private(set) var playlistsViewModel: PlaylistsViewModel?
    private(set) var orchestrator: WallpaperOrchestrator?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installLogSink()

        let mgr = DisplayManager()
        mgr.start()
        displayManager = mgr
        let engine = WallpaperEngine(displayManager: mgr)
        self.engine = engine

        setupLibrary()

        SystemWallpaperOverride.applyAll()

        setupPolicyWatchers(engine: engine, displayManager: mgr)

        statusItem = StatusItemController(
            onMenuItem: { [weak self] action in self?.handle(action) },
            onVideoDrop: { [weak self] url in self?.dropped(url) },
            onScaleChange: { [weak self] mode in self?.setScale(mode) },
            activeScaleMode: activeScaleMode,
            pauseLabel: userPaused ? "Resume All" : "Pause All"
        )

        log.info("Mural launched (version \(Bundle.main.shortVersionString, privacy: .public))")

        // Audio reactivity is opt-in. During Debug builds the binary's cdhash
        // changes every rebuild, so any SCK call retriggers the Screen Recording
        // TCC prompt — annoying and noisy. The Phase 11 Settings UI will surface
        // a single toggle that calls `orchestrator?.enableAudio()` on demand;
        // until then audio capture stays dormant. The audio pipeline remains
        // wired so existing audio-reactive web wallpapers will Just Work the
        // moment the user opts in.
    }

    func applicationWillTerminate(_: Notification) {
        teardownPolicyWatchers()
        displayManager?.shutdown()
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "mural" {
            switch url.host {
            case "library":
                LibraryWindowController.shared.open(
                    viewModel: libraryViewModel,
                    playlistsViewModel: playlistsViewModel,
                    orchestrator: orchestrator,
                    onPlaylistEnabledChange: { [weak self] playlist in
                        self?.playlistEnabledChanged(playlist)
                    }
                )
            default:
                log.warning("Unhandled mural:// host: \(url.host ?? "nil", privacy: .public)")
            }
        }
    }

    private func setupLibrary() {
        let libRoot = LibraryRoot.defaultURL()
        try? LibraryRoot.ensureExists(root: libRoot)
        let catalogURL = LibraryRoot.catalogURL(root: libRoot)
        if let catalog = try? Catalog(url: catalogURL) {
            let library = LibraryService(libraryRoot: libRoot, catalog: catalog)
            libraryService = library
            libraryViewModel = LibraryViewModel(service: library)
            playlistsViewModel = PlaylistsViewModel(catalog: catalog)
            if let engine {
                orchestrator = WallpaperOrchestrator(engine: engine, library: library)
            }
        } else {
            log.error("Catalog open failed at \(catalogURL.path, privacy: .public) — library disabled this run")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    private func installLogSink() {
        let logURL = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Mural/mural.log")
        if let sink = try? LogFileSink(url: logURL) {
            logSink = sink
            sink.write("Mural launched (version \(Bundle.main.shortVersionString))")
        }
    }

    private func handle(_ action: StatusMenuAction) {
        switch action {
        case .library:
            LibraryWindowController.shared.open(
                viewModel: libraryViewModel,
                playlistsViewModel: playlistsViewModel,
                orchestrator: orchestrator,
                onPlaylistEnabledChange: { [weak self] playlist in
                    self?.playlistEnabledChanged(playlist)
                }
            )
        case .settings:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(#selector(_MuralSettingsAction.showSettingsWindow(_:)), to: nil, from: nil)
        case .pauseAll:
            toggleUserPause()
        case .smokeTest:
            engine?.setRendererForAllDisplays(factory: { SolidColorRenderer(color: .magenta) })
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func toggleUserPause() {
        userPaused.toggle()
        let coordinator = pauseCoordinator
        if let displayManager {
            for uuid in displayManager.windows.keys {
                if userPaused {
                    coordinator?.add(.userPaused, for: uuid)
                } else {
                    coordinator?.remove(.userPaused, for: uuid)
                }
            }
        }
        statusItem?.rebuildMenu(pauseLabel: userPaused ? "Resume All" : "Pause All")
    }

    private func setScale(_ mode: ScaleMode) {
        activeScaleMode = mode
        statusItem?.setActiveScaleMode(mode)
        guard let engine else { return }
        for uuid in engine.activeRendererUUIDs {
            if let video = engine.renderer(for: uuid) as? VideoRenderer {
                video.setScaleMode(mode)
            }
        }
    }

    private func setupPolicyWatchers(engine: WallpaperEngine, displayManager: DisplayManager) {
        // `WallpaperRenderer` is `AnyObject` but not `Sendable`, so it can't be
        // returned directly from a `MainActor.assumeIsolated` block in a
        // `@Sendable` lookup closure under strict concurrency. Wrap both the
        // engine handoff and the renderer carry-out in `@unchecked Sendable`
        // boxes — lookups are only ever invoked on MainActor (PauseCoordinator
        // hops there before calling), so the unchecked annotation is sound.
        let engineBox = EngineLookupBox(engine)
        let coordinator = PauseCoordinator { uuid in
            let carrier = MainActor.assumeIsolated {
                RendererCarrier(engineBox.engine.renderer(for: uuid))
            }
            return carrier.renderer
        }
        pauseCoordinator = coordinator

        // Power: battery + Low Power Mode.
        let power = PowerWatcher()
        power.start { [weak self] onBattery, lowPower in
            guard let self else { return }
            let pauseOnBattery = settings.get(.pauseOnBattery)
            let pauseOnLowPower = settings.get(.pauseOnLowPowerMode)
            for uuid in displayManager.windows.keys {
                if onBattery, pauseOnBattery {
                    coordinator.add(.onBattery, for: uuid)
                } else {
                    coordinator.remove(.onBattery, for: uuid)
                }
                if lowPower, pauseOnLowPower {
                    coordinator.add(.lowPowerMode, for: uuid)
                } else {
                    coordinator.remove(.lowPowerMode, for: uuid)
                }
            }
        }
        powerWatcher = power

        // Foreground app rule (Zoom, Keynote, Slack, etc).
        let foreground = ForegroundAppWatcher()
        foreground.start { [weak self] bundleID in
            guard let self else { return }
            let rules = settings.get(.appPauseRules)
            let matched = rules.match(bundleID: bundleID) != nil
            for uuid in displayManager.windows.keys {
                if matched {
                    coordinator.add(.foregroundAppRule, for: uuid)
                } else {
                    coordinator.remove(.foregroundAppRule, for: uuid)
                }
            }
        }
        foregroundAppWatcher = foreground

        // Fullscreen occlusion (per-display).
        //
        // FullscreenWatcher polls `CGWindowListCopyWindowInfo`. On macOS 26 that
        // API triggers the Screen Recording TCC prompt on every Debug rebuild
        // (cdhash changes invalidate the prior grant). Until the Phase 11
        // Settings UI surfaces an explicit opt-in toggle and Phase 12 ships a
        // notarised Developer ID build (stable cdhash), keep this watcher
        // dormant. Other watchers (Power, ForegroundApp, RemoteSession,
        // PerformanceGovernor) don't touch TCC-gated APIs and stay active.
        let fullscreen = FullscreenWatcher(displayProvider: { [weak displayManager] in
            guard let displayManager else { return [:] }
            var out: [String: NSScreen] = [:]
            for (uuid, window) in displayManager.windows {
                if let screen = window.screen { out[uuid] = screen }
            }
            return out
        })
        fullscreenWatcher = fullscreen
        _ = coordinator // silence unused-warning when start() is gated off; coordinator is captured by other watchers

        // Remote session (Screen Sharing, VNC, ARD).
        let remote = RemoteSessionWatcher()
        remote.start { isRemote in
            for uuid in displayManager.windows.keys {
                if isRemote {
                    coordinator.add(.remoteSession, for: uuid)
                } else {
                    coordinator.remove(.remoteSession, for: uuid)
                }
            }
        }
        remoteSessionWatcher = remote

        // Thermal governor — clamps every active renderer on heat.
        let governor = PerformanceGovernor(
            videoApply: { [weak engine] bitrate, maxPixels in
                guard let engine else { return }
                for uuid in engine.activeRendererUUIDs {
                    if let video = engine.renderer(for: uuid) as? VideoRenderer {
                        video.setPreferredCeiling(bitrateBPS: bitrate, maxPixels: maxPixels)
                    }
                }
            },
            shaderApply: { [weak engine] fps in
                guard let engine else { return }
                for uuid in engine.activeRendererUUIDs {
                    if let shader = engine.renderer(for: uuid) as? ShaderRenderer {
                        shader.setPreferredFPS(fps)
                    }
                }
            }
        )
        governor.start()
        performanceGovernor = governor
    }

    private func teardownPolicyWatchers() {
        powerWatcher?.stop(); powerWatcher = nil
        foregroundAppWatcher?.stop(); foregroundAppWatcher = nil
        fullscreenWatcher?.stop(); fullscreenWatcher = nil
        remoteSessionWatcher?.stop(); remoteSessionWatcher = nil
        performanceGovernor?.stop(); performanceGovernor = nil
        pauseCoordinator = nil
    }

    private func playlistEnabledChanged(_ playlist: Playlist) {
        guard let orchestrator else { return }
        if playlist.enabled {
            orchestrator.startPlaylist(playlist)
        } else {
            orchestrator.stopPlaylist()
        }
    }

    private func dropped(_ url: URL) {
        guard let engine else { return }
        do {
            let asset = try VideoAsset(url: url)
            let mode = activeScaleMode
            engine.setRendererForAllDisplays {
                do {
                    return try VideoRenderer(asset: asset, scaleMode: mode)
                } catch {
                    Log.logger("AppDelegate").error(
                        "VideoRenderer init failed: \(error.localizedDescription, privacy: .public)"
                    )
                    return SolidColorRenderer(color: .black)
                }
            }
            log.info("Dropped video: \(url.lastPathComponent, privacy: .public)")
        } catch {
            log.error("Drop rejected: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension Bundle {
    var shortVersionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}

/// `WallpaperEngine` is `@MainActor`-isolated and its renderer values are
/// non-Sendable. To hand the engine to `PauseCoordinator`'s `@Sendable` lookup
/// closure we wrap it in an `@unchecked Sendable` box; the engine is only ever
/// touched on MainActor via `assumeIsolated`.
private final class EngineLookupBox: @unchecked Sendable {
    let engine: WallpaperEngine
    init(_ engine: WallpaperEngine) {
        self.engine = engine
    }
}

/// Carries a non-Sendable `WallpaperRenderer?` out of a `MainActor.assumeIsolated`
/// block without tripping the strict-concurrency Sendable check on the return
/// value. The coordinator only ever uses the result back on MainActor.
private final class RendererCarrier: @unchecked Sendable {
    let renderer: WallpaperRenderer?
    init(_ renderer: WallpaperRenderer?) {
        self.renderer = renderer
    }
}
