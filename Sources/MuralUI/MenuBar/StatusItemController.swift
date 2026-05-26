import AppKit
import OSLog

@MainActor
public final class StatusItemController: NSObject {
    private let log = Log.logger("StatusItem")
    private let statusItem: NSStatusItem

    public override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.fill.on.rectangle.fill",
                                   accessibilityDescription: "Mural")
            button.image?.isTemplate = true
        }
        statusItem.menu = StatusMenu.build(target: self, action: #selector(handle(_:)))
    }

    @objc private func handle(_ sender: NSMenuItem) {
        log.info("Menu: \(sender.title, privacy: .public)")
        switch sender.title {
        case "Settings…":
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case "Quit Mural":
            NSApp.terminate(nil)
        default:
            break
        }
    }
}
