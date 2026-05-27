import SwiftUI

/// Top-level layout for the library window. Combines the wallpaper grid on the
/// left with a segmented right pane (Playlists / Properties) inside an
/// `HSplitView` so the user can resize the boundary at will. View models are
/// injected so the same surface can be driven from production (`AppDelegate`)
/// and from previews/tests.
public struct LibraryRootView: View {
    @ObservedObject public var libraryVM: LibraryViewModel
    @ObservedObject public var playlistsVM: PlaylistsViewModel
    public var onUseAsWallpaper: (Wallpaper) -> Void
    public var onPlaylistEnabledChange: (Playlist) -> Void
    public var makePropertiesVM: (Wallpaper) -> PropertiesViewModel?

    private enum RightPane: String, CaseIterable, Identifiable {
        case playlists, properties
        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .playlists:
                "Playlists"
            case .properties:
                "Properties"
            }
        }
    }

    @State private var rightPane: RightPane = .playlists

    public init(
        libraryVM: LibraryViewModel,
        playlistsVM: PlaylistsViewModel,
        onUseAsWallpaper: @escaping (Wallpaper) -> Void,
        onPlaylistEnabledChange: @escaping (Playlist) -> Void,
        makePropertiesVM: @escaping (Wallpaper) -> PropertiesViewModel? = { _ in nil }
    ) {
        self.libraryVM = libraryVM
        self.playlistsVM = playlistsVM
        self.onUseAsWallpaper = onUseAsWallpaper
        self.onPlaylistEnabledChange = onPlaylistEnabledChange
        self.makePropertiesVM = makePropertiesVM
    }

    public var body: some View {
        HSplitView {
            LibraryView(vm: libraryVM, onUseAsWallpaper: onUseAsWallpaper)
                .frame(minWidth: 480)

            VStack(spacing: 0) {
                Picker("", selection: $rightPane) {
                    ForEach(RightPane.allCases) { pane in
                        Text(pane.title).tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(12)

                Divider()

                switch rightPane {
                case .playlists:
                    PlaylistPane(
                        vm: playlistsVM,
                        availableWallpapers: libraryVM.wallpapers,
                        onPlaylistEnabledChange: onPlaylistEnabledChange
                    )
                case .properties:
                    propertiesPane
                }
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 520)
        }
    }

    @ViewBuilder
    private var propertiesPane: some View {
        if let selected = libraryVM.selected, let vm = makePropertiesVM(selected) {
            PropertiesPanel(vm: vm)
        } else {
            emptyPropertiesState
        }
    }

    private var emptyPropertiesState: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(libraryVM.selected == nil
                ? "Select a wallpaper to see its properties."
                : "This wallpaper has no customizable properties.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
