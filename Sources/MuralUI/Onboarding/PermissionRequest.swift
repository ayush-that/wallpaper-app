import Foundation

public extension Notification.Name {
    /// Posted by code that detects a TCC service is needed but not granted.
    /// AppDelegate (or any SwiftUI scene) observes and presents
    /// `PermissionRequiredSheet`. UserInfo contains `["service": TCCStatus.Service]`.
    static let muralRequestPermission = Notification.Name("app.mural.requestPermission")
}

public enum PermissionRequest {
    public static func post(_ service: TCCStatus.Service) {
        NotificationCenter.default.post(
            name: .muralRequestPermission,
            object: nil,
            userInfo: ["service": service]
        )
    }
}
