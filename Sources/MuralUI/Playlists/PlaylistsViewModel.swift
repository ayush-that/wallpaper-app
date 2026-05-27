import Combine
import Foundation
import OSLog

@MainActor
public final class PlaylistsViewModel: ObservableObject {
    private let log = Log.logger("PlaylistsVM")
    private let catalog: Catalog

    @Published public private(set) var playlists: [Playlist] = []
    @Published public var lastError: String?

    public init(catalog: Catalog) {
        self.catalog = catalog
        refresh()
    }

    public func refresh() {
        do {
            playlists = try catalog.allPlaylists()
        } catch {
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    public func save(_ playlist: Playlist) {
        do {
            try catalog.upsert(playlist)
            refresh()
        } catch {
            log.error("save failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    public func remove(id: UUID) {
        do {
            try catalog.deletePlaylist(id: id)
            refresh()
        } catch {
            log.error("remove failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    public func toggle(_ playlist: Playlist) {
        var updated = playlist
        updated.enabled.toggle()
        save(updated)
    }
}
