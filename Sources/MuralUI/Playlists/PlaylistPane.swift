import SwiftUI

public struct PlaylistPane: View {
    @ObservedObject public var vm: PlaylistsViewModel
    public let availableWallpapers: [Wallpaper]
    @State private var editing: Playlist?

    public init(vm: PlaylistsViewModel, availableWallpapers: [Wallpaper]) {
        self.vm = vm
        self.availableWallpapers = availableWallpapers
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Playlists").font(.title3).bold()
                Spacer()
                Button("New Playlist") {
                    editing = Playlist(
                        name: "Untitled",
                        wallpaperIDs: [],
                        strategy: .interval(seconds: 600)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if vm.playlists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.playlists) { playlist in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).font(.headline)
                                Text(summary(of: playlist))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { playlist.enabled },
                                set: { _ in vm.toggle(playlist) }
                            ))
                            .labelsHidden()
                            Button("Edit") { editing = playlist }
                            Button(role: .destructive) {
                                vm.remove(id: playlist.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(item: $editing) { playlist in
            PlaylistEditor(
                initial: playlist,
                availableWallpapers: availableWallpapers,
                onSave: { saved in
                    vm.save(saved)
                    editing = nil
                },
                onCancel: { editing = nil }
            )
        }
        .alert(
            "Playlist error",
            isPresented: Binding(
                get: { vm.lastError != nil },
                set: { presented in if !presented { vm.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.lastError ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No playlists yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func summary(of playlist: Playlist) -> String {
        let count = playlist.wallpaperIDs.count
        let countLabel = count == 1 ? "1 wallpaper" : "\(count) wallpapers"
        let strategyLabel = switch playlist.strategy {
        case let .interval(seconds):
            "every \(humanize(seconds))"
        case let .shuffle(seconds):
            "shuffle every \(humanize(seconds))"
        case let .onIdle(seconds):
            "on idle (\(humanize(seconds)))"
        case let .timeOfDay(slots):
            "time of day (\(slots.count) slots)"
        }
        return "\(countLabel) · \(strategyLabel)"
    }

    private func humanize(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60) min" }
        return "\(s / 3600)h"
    }
}
