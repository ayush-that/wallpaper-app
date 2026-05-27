import AppKit
import CoreGraphics
import OSLog

/// Polls `CGWindowListCopyWindowInfo` every `pollInterval` seconds and emits
/// the set of display UUIDs that are occluded by ≥`coverageThreshold` coverage
/// from a non-Mural window. Drives `PauseReason.fullscreenOccluded`.
///
/// The watcher accepts a `displayProvider` closure that returns the current
/// snapshot of displays keyed by their persistent UUID — typically provided
/// from `DisplayManager` at the AppDelegate layer.
@MainActor
public final class FullscreenWatcher {
    public typealias DisplayProvider = @MainActor () -> [String: NSScreen]
    public typealias Callback = @MainActor (Set<String>) -> Void

    private let log = Log.logger("FullscreenWatcher")
    private let displayProvider: DisplayProvider
    private let pollInterval: TimeInterval
    private let coverageThreshold: CGFloat
    private let queue = DispatchQueue(label: "app.mural.fullscreen.watch")
    private var timer: DispatchSourceTimer?

    public init(
        displayProvider: @escaping DisplayProvider,
        pollInterval: TimeInterval = 1.0,
        coverageThreshold: CGFloat = 0.95
    ) {
        self.displayProvider = displayProvider
        self.pollInterval = pollInterval
        self.coverageThreshold = coverageThreshold
    }

    public func start(_ onChange: @escaping Callback) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: pollInterval)
        let coverage = coverageThreshold
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let displays = self.displayProvider()
                let occluded = Self.scan(displays: displays, coverageThreshold: coverage)
                onChange(occluded)
            }
        }
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Pure function: given a snapshot of displays and a coverage threshold,
    /// returns the set of display UUIDs occluded by a non-Mural window.
    /// Public for testability.
    public static func scan(displays: [String: NSScreen], coverageThreshold: CGFloat) -> Set<String> {
        guard !displays.isEmpty else { return [] }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var occluded: Set<String> = []
        for (uuid, screen) in displays {
            let target = screen.frame
            let area = target.width * target.height
            guard area > 0 else { continue }
            for window in raw {
                let layer = (window[kCGWindowLayer as String] as? Int) ?? 0
                if layer < 0 { continue } // below us; ignore
                if let owner = window[kCGWindowOwnerName as String] as? String, owner == "Mural" {
                    continue // ourselves
                }
                guard let geom = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
                let rect = CGRect(
                    x: geom["X"] ?? 0,
                    y: geom["Y"] ?? 0,
                    width: geom["Width"] ?? 0,
                    height: geom["Height"] ?? 0
                )
                let intersection = rect.intersection(target)
                if intersection.isNull { continue }
                let coverage = (intersection.width * intersection.height) / area
                if coverage >= coverageThreshold {
                    occluded.insert(uuid)
                    break
                }
            }
        }
        return occluded
    }
}
