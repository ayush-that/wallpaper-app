import AppKit

@MainActor
public enum StatusMenu {
    public static func build(target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu()
        let entries: [(String, String?)] = [
            ("Library…", "l"),
            ("Settings…", ","),
            ("Pause All", "p"),
            ("Quit Mural", "q"),
        ]
        for (title, key) in entries {
            if title == "Quit Mural" {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key ?? "")
            item.target = target
            menu.addItem(item)
        }
        return menu
    }
}
