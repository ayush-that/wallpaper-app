import AppKit
import OSLog
import SwiftUI

/// Lightweight `NSWindow` controller for the library window.
///
/// We use a regular `NSWindow` rather than a SwiftUI `WindowGroup` because
/// (a) we need to inject runtime-constructed view models (`LibraryViewModel`,
/// `WallpaperOrchestrator`) without an environment dance, and (b) we already
/// have AppKit infrastructure in `AppDelegate`. This is the path of least
/// resistance for a single, on-demand window opened from a menu item.
@MainActor
public final class LibraryWindowController: NSObject {
    public static let shared = LibraryWindowController()

    private let log = Log.logger("LibraryWindow")
    private var window: NSWindow?

    override private init() {
        super.init()
    }

    public func open(
        viewModel: LibraryViewModel?,
        playlistsViewModel: PlaylistsViewModel?,
        orchestrator: WallpaperOrchestrator?,
        onPlaylistEnabledChange: @MainActor @escaping (Playlist) -> Void = { _ in },
        makePropertiesVM: @MainActor @escaping (Wallpaper) -> PropertiesViewModel? = { _ in nil }
    ) {
        guard let viewModel, let playlistsViewModel, let orchestrator else {
            log.error("Library not available (catalog open failed at launch)")
            return
        }
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = LibraryRootView(
            libraryVM: viewModel,
            playlistsVM: playlistsViewModel,
            onUseAsWallpaper: { wallpaper in
                orchestrator.applyToAllDisplays(wallpaper: wallpaper)
            },
            onPlaylistEnabledChange: onPlaylistEnabledChange,
            makePropertiesVM: makePropertiesVM
        )
        let window = Self.makeWindow(rootView: rootView)
        window.delegate = self
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The smallest content size at which both panes stay usable: the grid keeps
    /// a full column and the right pane shows its header controls without
    /// clipping. Matches the sum of the pane minimums in `LibraryRootView`
    /// (left 480 + right 320 + the split divider) so nothing is truncated at the
    /// floor. Without this the resizable window has no minimum and can be dragged
    /// down until the content clips.
    static let minimumContentSize = NSSize(width: 820, height: 520)

    /// Builds and configures the library window without presenting it. Factored
    /// out so the window chrome (minimum size, resize behaviour) is testable
    /// without the side effects of activating the app.
    static func makeWindow(rootView: some View) -> NSWindow {
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Mural Library"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.contentMinSize = minimumContentSize
        window.setContentSize(NSSize(width: 1180, height: 600))
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }
}

extension LibraryWindowController: NSWindowDelegate {
    public func windowWillClose(_: Notification) {
        window = nil
    }
}
