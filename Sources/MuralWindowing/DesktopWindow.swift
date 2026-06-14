import AppKit

/// An NSWindow that lives on the desktop layer (behind icons, transparent,
/// click-through, present on every Space).
///
/// Modeled on Plash's DesktopWindow. Level is `CGWindowLevelForKey(.desktopWindow)`,
/// which sits below desktop icons but above the system Desktop Picture.
/// `ignoresMouseEvents = true` lets clicks fall through to the Finder.
/// `collectionBehavior` keeps the window alive across Space switches,
/// stationary in Mission Control, ignored by `Cmd-`` cycling, and excluded
/// from the fullscreen Space.
/// `sharingType = .none` excludes the window from screenshots and Mission
/// Control snapshots; wallpaper isn't content the user is sharing.
public final class DesktopWindow: NSWindow {
    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        sharingType = .none

        setFrame(screen.frame, display: false)
    }

    /// Clicks should fall through to the desktop; never make this window key/main.
    override public var canBecomeKey: Bool {
        false
    }

    override public var canBecomeMain: Bool {
        false
    }
}
