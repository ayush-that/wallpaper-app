import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Log.logger("AppDelegate")
    private var statusItem: StatusItemController?
    private var logSink: LogFileSink?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let logURL = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Mural/mural.log")
        if let sink = try? LogFileSink(url: logURL) {
            logSink = sink
            sink.write("Mural launched (version \(Bundle.main.shortVersionString))")
        }

        log.info("Mural launched (version \(Bundle.main.shortVersionString, privacy: .public))")
        statusItem = StatusItemController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}

private extension Bundle {
    var shortVersionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}
