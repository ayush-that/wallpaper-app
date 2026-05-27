import AppKit
import Foundation
import OSLog
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the rest of the app interacts with a small,
/// testable surface. `SMAppService` is macOS 13+ and replaces the deprecated
/// `SMLoginItemSetEnabled` flow. The first `setEnabled(true)` may require the
/// user to approve the helper in System Settings -> Login Items — there's no
/// programmatic grant, only a deep-link.
@MainActor
public final class LoginItemController {
    public static let shared = LoginItemController()

    private let log = Log.logger("LoginItem")
    private let service = SMAppService.mainApp

    private init() {}

    public var status: SMAppService.Status {
        service.status
    }

    public func isEnabled() -> Bool {
        service.status == .enabled
    }

    /// Toggle launch-at-login. Errors are logged; we don't propagate them
    /// because the UI side handles the user-facing flow (deep-link to System
    /// Settings if `.requiresApproval` is the eventual status).
    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            log.error("SMAppService toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Convenience deep-link into System Settings -> Login Items.
    public static func openSystemSettingsLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
