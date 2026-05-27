import AppKit
import OSLog

/// Watches the system's frontmost application. Fires `onChange(bundleID)`
/// once immediately on `start()` with the current frontmost app, then again
/// on every `NSWorkspace.didActivateApplicationNotification`.
///
/// `bundleID` is the new frontmost app's bundle identifier, or nil if the
/// foreground app has no bundle ID (rare — e.g. some shell helpers).
@MainActor
public final class ForegroundAppWatcher {
    public typealias Callback = @Sendable @MainActor (_ bundleID: String?) -> Void

    private let log = Log.logger("ForegroundApp")
    private var observer: NSObjectProtocol?

    public init() {}

    public func start(_ onChange: @escaping Callback) {
        // Fire current state immediately.
        let current = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        onChange(current)

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            MainActor.assumeIsolated {
                onChange(bundleID)
            }
        }
    }

    public func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }
}
