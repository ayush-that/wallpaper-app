import AppKit
import OSLog

// SwiftUI installs `showSettingsWindow:` on NSApplication at runtime
// (it's the action behind the standard Cmd-, menu item for a Settings
// scene). It isn't declared in any public header, so we forward-declare
// it here purely to get a typed #selector reference instead of a stringly
// typed Selector(("showSettingsWindow:")).
@objc private protocol _MuralSettingsAction {
    func showSettingsWindow(_ sender: Any?)
}

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
        guard let menuAction = StatusMenuAction(rawValue: sender.tag) else { return }
        switch menuAction {
        case .settings:
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(#selector(_MuralSettingsAction.showSettingsWindow(_:)), to: nil, from: nil)
        case .quit:
            NSApp.terminate(nil)
        case .library, .pauseAll:
            break
        }
    }
}
