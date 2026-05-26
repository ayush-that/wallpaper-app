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
    private var smokeRenderers: [SolidColorRenderer] = []

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installLogSink()

        let mgr = DisplayManager()
        mgr.start()
        displayManager = mgr

        statusItem = StatusItemController(onMenuItem: { [weak self] action in
            self?.handle(action)
        })

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
            for renderer in smokeRenderers {
                renderer.pause()
            }
        case .smokeTest:
            runSmokeTest()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func runSmokeTest() {
        guard let mgr = displayManager else { return }
        // Tear down any existing smoke renderers first so subsequent clicks
        // re-apply cleanly.
        for renderer in smokeRenderers {
            renderer.detach()
        }
        smokeRenderers.removeAll()
        // One renderer per host — a single SolidColorRenderer attached to
        // multiple hosts would have its single CALayer reparented, leaving
        // every host except the last empty.
        for host in mgr.hosts.values {
            let renderer = SolidColorRenderer(color: .magenta)
            renderer.attach(to: host)
            smokeRenderers.append(renderer)
        }
    }
}

private extension Bundle {
    var shortVersionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}
