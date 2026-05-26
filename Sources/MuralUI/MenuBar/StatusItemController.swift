import AppKit
import OSLog

@MainActor
public final class StatusItemController: NSObject {
    private let log = Log.logger("StatusItem")
    private let statusItem: NSStatusItem
    private let onMenuItem: @MainActor (StatusMenuAction) -> Void
    private let dropTarget: StatusBarDropTarget

    public init(
        onMenuItem: @escaping @MainActor (StatusMenuAction) -> Void,
        onVideoDrop: @escaping @MainActor (URL) -> Void
    ) {
        self.onMenuItem = onMenuItem
        dropTarget = StatusBarDropTarget(onDrop: onVideoDrop)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "photo.fill.on.rectangle.fill",
                accessibilityDescription: "Mural"
            )
            button.image?.isTemplate = true
            let overlay = DropForwardView(frame: button.bounds, target: dropTarget)
            overlay.autoresizingMask = [.width, .height]
            button.addSubview(overlay)
        }
        statusItem.menu = StatusMenu.build(target: self, action: #selector(handle(_:)))
    }

    @objc private func handle(_ sender: NSMenuItem) {
        log.info("Menu: \(sender.title, privacy: .public)")
        guard let action = StatusMenuAction(rawValue: sender.tag) else { return }
        onMenuItem(action)
    }
}
