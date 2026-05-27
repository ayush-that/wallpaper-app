import Foundation

/// A renderer that accepts live property updates from the per-wallpaper
/// customization UI (Phase 9 `PropertiesPanel`). `apply(propertyName:value:)`
/// receives the on-disk override values directly — sinks decide which property
/// names they understand. Unknown names are silently ignored (forward-compat
/// with future controls + third-party wallpapers shipping novel keys).
@MainActor
public protocol PropertiesSink: AnyObject {
    func apply(propertyName: String, value: WebBridgePropertyValue)
}
