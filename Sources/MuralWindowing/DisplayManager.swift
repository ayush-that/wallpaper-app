import AppKit
import OSLog

/// Owns the per-display `DesktopWindow` and `WallpaperHost` lifecycle. Observes
/// `NSApplication.didChangeScreenParametersNotification` and re-syncs whenever
/// the display layout changes (hotplug, resolution change, arrangement change).
///
/// This is the single source of truth for "what hosts exist right now." All
/// state is keyed by `Display.uuid`, which is stable across hotplug. The
/// underlying `NSScreen` instance may be replaced even when the same physical
/// display reconnects, so we re-bind frames rather than recreating the window.
@MainActor
public final class DisplayManager {
    private let log = Log.logger("DisplayManager")

    public private(set) var windows: [String: DesktopWindow] = [:]
    public private(set) var hosts: [String: WallpaperHost] = [:]
    public private(set) var displays: [String: Display] = [:]

    private var observer: NSObjectProtocol?

    public init() {}

    public func start() {
        guard observer == nil else {
            log.warning("start() called while already running")
            return
        }
        sync()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sync()
            }
        }
    }

    public func shutdown() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        for window in windows.values {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        hosts.removeAll()
        displays.removeAll()
    }

    public func host(for display: Display) -> WallpaperHost? {
        hosts[display.uuid]
    }

    private func sync() {
        var current: [String: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let uuid = DisplayUUID.from(screen: screen) {
                current[uuid] = screen
            }
        }

        // Add or update windows for present screens.
        for (uuid, screen) in current {
            if let window = windows[uuid] {
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                }
                continue
            }
            guard let display = Display(screen: screen) else { continue }
            let window = DesktopWindow(screen: screen)
            let host = WallpaperHost(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.contentView = host
            window.orderFront(nil)
            windows[uuid] = window
            hosts[uuid] = host
            displays[uuid] = display
            log.info("Added display \(uuid, privacy: .public)")
        }

        // Remove windows for disappeared screens.
        for uuid in windows.keys where current[uuid] == nil {
            windows[uuid]?.orderOut(nil)
            windows[uuid]?.close()
            windows.removeValue(forKey: uuid)
            hosts.removeValue(forKey: uuid)
            displays.removeValue(forKey: uuid)
            log.info("Removed display \(uuid, privacy: .public)")
        }
    }
}
