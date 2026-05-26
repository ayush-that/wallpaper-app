import Foundation
import OSLog

public enum Log {
    public static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "app.mural.Mural"
    }

    public static func subsystem(for category: String) -> String {
        "\(bundleID).\(category)"
    }

    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem(for: category), category: category)
    }
}
