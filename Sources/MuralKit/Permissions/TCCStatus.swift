import AppKit
import CoreGraphics

public enum TCCStatus {
    public enum Service {
        case screenRecording, automation, accessibility, microphone
    }

    public static func systemSettingsURL(for service: Service) -> URL {
        let anchor = switch service {
        case .screenRecording: "Privacy_ScreenCapture"
        case .automation: "Privacy_Automation"
        case .accessibility: "Privacy_Accessibility"
        case .microphone: "Privacy_Microphone"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }

    @MainActor
    public static func openSystemSettings(for service: Service) {
        NSWorkspace.shared.open(systemSettingsURL(for: service))
    }

    public static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
