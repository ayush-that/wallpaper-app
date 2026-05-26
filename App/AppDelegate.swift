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

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installLogSink()

        let mgr = DisplayManager()
        mgr.start()
        displayManager = mgr
        engine = WallpaperEngine(displayManager: mgr)

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
            // Wired in Phase 3.
            break
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
