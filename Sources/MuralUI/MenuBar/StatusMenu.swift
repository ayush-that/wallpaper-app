import AppKit

public enum StatusMenuAction: Int {
    case library
    case settings
    case pauseAll
    case smokeTest
    case quit
}

@MainActor
public enum StatusMenu {
    public static func build(
        target: AnyObject,
        action: Selector,
        scaleAction: Selector,
        activeScaleMode: ScaleMode = .fill,
        pauseLabel: String = "Pause All"
    ) -> NSMenu {
        let menu = NSMenu()

        addTopLevel(
            menu, target: target, action: action,
            title: "Library…", tag: .library, key: "l"
        )
        addTopLevel(
            menu, target: target, action: action,
            title: "Settings…", tag: .settings, key: ","
        )
        addTopLevel(
            menu, target: target, action: action,
            title: pauseLabel, tag: .pauseAll, key: "p"
        )

        let scaleItem = NSMenuItem(title: "Scale Mode", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Scale Mode")
        for mode in ScaleMode.allCases {
            let item = NSMenuItem(
                title: "Scale: \(mode.rawValue)",
                action: scaleAction,
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = mode.rawValue
            item.state = (mode == activeScaleMode) ? .on : .off
            submenu.addItem(item)
        }
        scaleItem.submenu = submenu
        menu.addItem(scaleItem)

        addTopLevel(
            menu, target: target, action: action,
            title: "Debug: Magenta Smoke Test", tag: .smokeTest, key: ""
        )

        menu.addItem(.separator())

        addTopLevel(
            menu, target: target, action: action,
            title: "Quit Mural", tag: .quit, key: "q"
        )

        return menu
    }

    private static func addTopLevel(
        _ menu: NSMenu,
        target: AnyObject,
        action: Selector,
        title: String,
        tag: StatusMenuAction,
        key: String
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.tag = tag.rawValue
        menu.addItem(item)
    }
}
