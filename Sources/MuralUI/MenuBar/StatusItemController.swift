import AppKit
import OSLog

@MainActor
public final class StatusItemController: NSObject {
    private let log = Log.logger("StatusItem")
    private let statusItem: NSStatusItem
    private let onMenuItem: @MainActor (StatusMenuAction) -> Void
    private let onScaleChange: @MainActor (ScaleMode) -> Void
    private let dropTarget: StatusBarDropTarget

    public init(
        onMenuItem: @escaping @MainActor (StatusMenuAction) -> Void,
        onVideoDrop: @escaping @MainActor (URL) -> Void,
        onScaleChange: @escaping @MainActor (ScaleMode) -> Void,
        activeScaleMode: ScaleMode = .fill
    ) {
        self.onMenuItem = onMenuItem
        self.onScaleChange = onScaleChange
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
        statusItem.menu = StatusMenu.build(
            target: self,
            action: #selector(handle(_:)),
            scaleAction: #selector(handleScale(_:)),
            activeScaleMode: activeScaleMode
        )
    }

    /// Updates the checkmark in the Scale Mode submenu without rebuilding.
    public func setActiveScaleMode(_ mode: ScaleMode) {
        guard let menu = statusItem.menu else { return }
        guard let submenu = menu.items.first(where: { $0.title == "Scale Mode" })?.submenu else { return }
        for item in submenu.items {
            guard let raw = item.representedObject as? String,
                  let itemMode = ScaleMode(rawValue: raw) else { continue }
            item.state = (itemMode == mode) ? .on : .off
        }
    }

    @objc private func handle(_ sender: NSMenuItem) {
        log.info("Menu: \(sender.title, privacy: .public)")
        guard let action = StatusMenuAction(rawValue: sender.tag) else { return }
        onMenuItem(action)
    }

    @objc private func handleScale(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ScaleMode(rawValue: raw) else { return }
        log.info("Scale Mode: \(raw, privacy: .public)")
        onScaleChange(mode)
    }
}
