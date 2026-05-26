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
    private var statusItem: StatusItemController?
    private var logSink: LogFileSink?
    private var displayManager: DisplayManager?
    private var engine: WallpaperEngine?
    private var activeScaleMode: ScaleMode = .fill

    private(set) var libraryService: LibraryService?
    private(set) var libraryViewModel: LibraryViewModel?
    private(set) var orchestrator: WallpaperOrchestrator?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installLogSink()

        let mgr = DisplayManager()
        mgr.start()
        displayManager = mgr
        engine = WallpaperEngine(displayManager: mgr)

        setupLibrary()

        SystemWallpaperOverride.applyAll()

        statusItem = StatusItemController(
            onMenuItem: { [weak self] action in self?.handle(action) },
            onVideoDrop: { [weak self] url in self?.dropped(url) },
            onScaleChange: { [weak self] mode in self?.setScale(mode) },
            activeScaleMode: activeScaleMode
        )

        log.info("Mural launched (version \(Bundle.main.shortVersionString, privacy: .public))")
    }

    func applicationWillTerminate(_: Notification) {
        displayManager?.shutdown()
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "mural" {
            switch url.host {
            case "library":
                LibraryWindowController.shared.open(
                    viewModel: libraryViewModel,
                    orchestrator: orchestrator
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
                orchestrator: orchestrator
            )
        case .settings:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(#selector(_MuralSettingsAction.showSettingsWindow(_:)), to: nil, from: nil)
        case .pauseAll:
            engine?.pauseAll()
        case .smokeTest:
            engine?.setRendererForAllDisplays(factory: { SolidColorRenderer(color: .magenta) })
        case .quit:
            NSApp.terminate(nil)
        }
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
