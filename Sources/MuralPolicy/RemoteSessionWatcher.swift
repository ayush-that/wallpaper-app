import Foundation
import OSLog
import Quartz

/// Polls whether the current session is running on the console (local) or via
/// a remote control tool (Screen Sharing, VNC, ARD). Coarse polling: remote
/// connect/disconnect is a rare event so 5 s latency is fine.
@MainActor
public final class RemoteSessionWatcher {
    public typealias Callback = @MainActor (_ isRemote: Bool) -> Void

    private let log = Log.logger("RemoteSession")
    private let queue = DispatchQueue(label: "app.mural.remote.watch")
    private let pollInterval: TimeInterval
    private var timer: DispatchSourceTimer?
    private var lastReportedState: Bool?

    public init(pollInterval: TimeInterval = 5.0) {
        self.pollInterval = pollInterval
    }

    /// Returns `true` if the current login session is being controlled remotely.
    /// Synchronous, no I/O.
    public func isRemote() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        // `kCGSessionOnConsoleKey` is true when the session is on the console.
        let onConsole = (dict[kCGSessionOnConsoleKey as String] as? Bool) ?? true
        return !onConsole
    }

    public func start(_ onChange: @escaping Callback) {
        // Fire current state immediately.
        let initial = isRemote()
        lastReportedState = initial
        onChange(initial)

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let current = self.isRemote()
                if current != self.lastReportedState {
                    self.lastReportedState = current
                    onChange(current)
                }
            }
        }
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        lastReportedState = nil
    }
}
