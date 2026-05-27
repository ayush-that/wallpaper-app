import Foundation

/// One row in the per-wallpaper customization form. Each case carries the
/// canonical fields for its type; the control's identity is its `name` (the
/// key it had in the source JSON), which is used both as the storage key in
/// `PropertyOverrideStore` and as the argument passed into the wallpaper's
/// `livelyPropertyListener(name, value)` JS callback.
public enum PropertyControl: Codable, Equatable, Identifiable, Sendable {
    case slider(name: String, label: String, value: Double, min: Double, max: Double, step: Double)
    case color(name: String, label: String, value: String)
    case checkbox(name: String, label: String, value: Bool)
    case dropdown(name: String, label: String, items: [String], value: Int)
    case folderDropdown(name: String, label: String, folder: String, filter: String, value: String)
    case textbox(name: String, label: String, value: String)
    case button(name: String, label: String, value: String)
    case label(name: String, value: String)

    public var id: String {
        name
    }

    public var name: String {
        switch self {
        case let .slider(name, _, _, _, _, _),
             let .color(name, _, _),
             let .checkbox(name, _, _),
             let .dropdown(name, _, _, _),
             let .folderDropdown(name, _, _, _, _),
             let .textbox(name, _, _),
             let .button(name, _, _),
             let .label(name, _):
            name
        }
    }
}
