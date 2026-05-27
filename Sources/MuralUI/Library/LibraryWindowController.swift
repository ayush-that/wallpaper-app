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
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Mural Library"
        window.setContentSize(NSSize(width: 1180, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension LibraryWindowController: NSWindowDelegate {
    public func windowWillClose(_: Notification) {
        window = nil
    }
}
