import AppKit
import OSLog

@MainActor
public enum SystemWallpaperOverride {
    private static let log = Log.logger("SystemWallpaperOverride")

    public static func blackImageURL() -> URL? {
        // Resources/ is copied into Mural.app/Contents/Resources/Resources/
        // via XcodeGen's `type: folder` (a blue folder reference), so we
        // pass the subdirectory explicitly to resolve the PNG inside it.
        Bundle.main.url(forResource: "black-1x1", withExtension: "png", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "black-1x1", withExtension: "png")
    }

    public static func apply(to screen: NSScreen) throws {
        guard let url = blackImageURL() else {
            log.error("black-1x1.png missing from bundle")
            return
        }
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
            .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue
        ])
    }

    public static func applyAll() {
        for screen in NSScreen.screens {
            do {
                try apply(to: screen)
            } catch {
                log.error("Failed to override desktop image on screen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
