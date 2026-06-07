import Foundation
import OSLog
import Sparkle

/// Wraps `SPUStandardUpdaterController` so the rest of the app talks to a
/// single object instead of Sparkle's machinery. `checkNow()` triggers the
/// standard user-driven update flow (with a "Check for Updates…" panel).
/// Background auto-checks run on a 24-hour schedule by default.
///
/// Sparkle 2 silently no-ops if the app is not Developer-ID signed; for
/// Debug builds the manager initialises but reports no available updates.
/// The notarized Phase 12 distribution flow is where this actually fires.
@MainActor
public final class UpdateManager: NSObject, ObservableObject {
    private let log = Log.logger("UpdateManager")
    public let controller: SPUStandardUpdaterController
    public var updater: SPUUpdater {
        controller.updater
    }

    /// Two-way bindable for SwiftUI. Reads/writes Sparkle's KVO-compliant
    /// `automaticallyChecksForUpdates`, which Sparkle persists under the
    /// `SUEnableAutomaticChecks` key in `UserDefaults`.
    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    override public init() {
        // First-launch default. `register(defaults:)` is a no-op once the
        // user toggles the value, so their choice survives subsequent launches.
        UserDefaults.standard.register(defaults: ["SUEnableAutomaticChecks": true])

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        // Policy: never silently install — always prompt.
        updater.automaticallyDownloadsUpdates = false
        let feed = updater.feedURL?.absoluteString ?? "nil"
        log.info("Sparkle initialised (feedURL=\(feed, privacy: .public))")
    }

    /// User-initiated check. Triggers the standard Sparkle UI panel.
    public func checkNow() {
        updater.checkForUpdates()
    }
}
