import SwiftUI

/// Top-level layout for the library window. Combines the wallpaper grid on the
/// left with the playlists pane on the right inside an `HSplitView` so the user
/// can resize the boundary at will. View models are injected so the same surface
/// can be driven from production (`AppDelegate`) and from previews/tests.
public struct LibraryRootView: View {
    @ObservedObject public var libraryVM: LibraryViewModel
    @ObservedObject public var playlistsVM: PlaylistsViewModel
    public var onUseAsWallpaper: (Wallpaper) -> Void
    public var onPlaylistEnabledChange: (Playlist) -> Void

    public init(
        libraryVM: LibraryViewModel,
        playlistsVM: PlaylistsViewModel,
        onUseAsWallpaper: @escaping (Wallpaper) -> Void,
        onPlaylistEnabledChange: @escaping (Playlist) -> Void
    ) {
        self.libraryVM = libraryVM
        self.playlistsVM = playlistsVM
        self.onUseAsWallpaper = onUseAsWallpaper
        self.onPlaylistEnabledChange = onPlaylistEnabledChange
    }

    public var body: some View {
        HSplitView {
            LibraryView(vm: libraryVM, onUseAsWallpaper: onUseAsWallpaper)
                .frame(minWidth: 480)
            PlaylistPane(
                vm: playlistsVM,
                availableWallpapers: libraryVM.wallpapers,
                onPlaylistEnabledChange: onPlaylistEnabledChange
            )
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 480)
        }
    }
}
