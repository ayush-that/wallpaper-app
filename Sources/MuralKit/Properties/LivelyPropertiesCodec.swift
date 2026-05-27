import Foundation

/// Decodes the `LivelyProperties.json` wire format into a sorted array of
/// `PropertyControl`. Field name capitalization matches the on-disk format;
/// renaming would break compat with existing bundles users may want to import.
///
/// Output ordering: alphabetical by `name` (the JSON dictionary is unordered,
/// so we pick a stable order so the form rows don't shuffle each render).
public enum LivelyPropertiesCodec {
    public enum DecodeError: Error, Equatable {
        case notADictionary
        case unsupportedControlType(String)
    }

    public static func decode(_ data: Data) throws -> [PropertyControl] {
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = any as? [String: [String: Any]] else {
            throw DecodeError.notADictionary
        }
        return root
            .compactMap { name, dict -> PropertyControl? in
                try? makeControl(name: name, dict: dict)
            }
            .sorted { $0.name < $1.name }
    }

    private static func makeControl(name: String, dict: [String: Any]) throws -> PropertyControl {
        let type = dict["type"] as? String ?? "label"
        let text = dict["text"] as? String ?? name
        switch type {
        case "slider":
            return .slider(
                name: name,
                label: text,
                value: doubleValue(dict["value"]) ?? 0,
                min: doubleValue(dict["min"]) ?? 0,
                max: doubleValue(dict["max"]) ?? 1,
                step: doubleValue(dict["step"]) ?? 0.01
            )
        case "color":
            return .color(name: name, label: text, value: dict["value"] as? String ?? "#ffffff")
        case "checkbox":
            return .checkbox(name: name, label: text, value: dict["value"] as? Bool ?? false)
        case "dropdown":
            return .dropdown(
                name: name,
                label: text,
                items: dict["items"] as? [String] ?? [],
                value: dict["value"] as? Int ?? 0
            )
        case "folderDropdown":
            return .folderDropdown(
                name: name,
                label: text,
                folder: dict["folder"] as? String ?? "",
                filter: dict["filter"] as? String ?? "*",
                value: dict["value"] as? String ?? ""
            )
        case "textbox":
            return .textbox(name: name, label: text, value: dict["value"] as? String ?? "")
        case "button":
            return .button(name: name, label: text, value: dict["value"] as? String ?? "")
        case "label":
            return .label(name: name, value: dict["value"] as? String ?? "")
        default:
            throw DecodeError.unsupportedControlType(type)
        }
    }

    /// JSON numbers can decode as Int or Double depending on the value;
    /// normalize to Double for slider math.
    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }
}
