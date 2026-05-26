import AppKit

public enum StatusMenuAction: Int {
    case library
    case settings
    case pauseAll
    case quit
}

@MainActor
public enum StatusMenu {
    public static func build(target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu()
        let entries: [(String, String?, StatusMenuAction)] = [
            ("Library…", "l", .library),
            ("Settings…", ",", .settings),
            ("Pause All", "p", .pauseAll),
            ("Quit Mural", "q", .quit)
        ]
        for (title, key, menuAction) in entries {
            if menuAction == .quit {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key ?? "")
            item.target = target
            item.tag = menuAction.rawValue
            menu.addItem(item)
        }
        return menu
    }
}
