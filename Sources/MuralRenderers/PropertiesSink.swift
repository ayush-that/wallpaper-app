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

/// Fans a single `apply` call out to every wrapped sink. Used when the UI
/// wants per-display renderers to react in lockstep to a single slider drag.
@MainActor
public final class FanOutPropertiesSink: PropertiesSink {
    private let sinks: [PropertiesSink]

    public init(_ sinks: [PropertiesSink]) {
        self.sinks = sinks
    }

    public func apply(propertyName: String, value: WebBridgePropertyValue) {
        for sink in sinks {
            sink.apply(propertyName: propertyName, value: value)
        }
    }
}
