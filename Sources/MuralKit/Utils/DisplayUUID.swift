import AppKit
import CoreGraphics

public enum DisplayUUID {
    /// Extract the CGDirectDisplayID from an NSScreen via the documented
    /// "NSScreenNumber" device description key.
    public static func cgDisplayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    /// Return a stable UUID string that survives display hotplug,
    /// using `CGDisplayCreateUUIDFromDisplayID`.
    public static func from(screen: NSScreen) -> String? {
        guard let id = cgDisplayID(for: screen),
              let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, cfUUID) as String
    }
}
