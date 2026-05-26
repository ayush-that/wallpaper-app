import AppKit
import OSLog

@MainActor
public final class StatusItemController: NSObject {
    private let log = Log.logger("StatusItem")
    private let statusItem: NSStatusItem
    private let onMenuItem: @MainActor (StatusMenuAction) -> Void

    public init(onMenuItem: @escaping @MainActor (StatusMenuAction) -> Void) {
        self.onMenuItem = onMenuItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "photo.fill.on.rectangle.fill",
                accessibilityDescription: "Mural"
            )
            button.image?.isTemplate = true
        }
        statusItem.menu = StatusMenu.build(target: self, action: #selector(handle(_:)))
    }

    @objc private func handle(_ sender: NSMenuItem) {
        log.info("Menu: \(sender.title, privacy: .public)")
        guard let action = StatusMenuAction(rawValue: sender.tag) else { return }
        onMenuItem(action)
    }
}
