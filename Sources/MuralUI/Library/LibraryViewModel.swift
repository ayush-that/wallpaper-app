import Combine
import Foundation
import OSLog

@MainActor
public final class LibraryViewModel: ObservableObject {
    private let log = Log.logger("LibraryVM")
    private let service: LibraryService

    @Published public private(set) var wallpapers: [Wallpaper] = []
    @Published public private(set) var selected: Wallpaper?
    @Published public var importError: String?

    public init(service: LibraryService) {
        self.service = service
        refresh()
    }

    public func refresh() {
        do {
            wallpapers = try service.allWallpapers()
        } catch {
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func select(_ wallpaper: Wallpaper) {
        selected = wallpaper
    }

    public func importURLs(_ urls: [URL]) {
        for url in urls {
            do {
                _ = try service.importFile(at: url)
            } catch {
                importError = error.localizedDescription
                log.error(
                    "import failed for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        refresh()
    }

    public func thumbnail(for wallpaper: Wallpaper) -> URL {
        service.package(for: wallpaper.id).root.appendingPathComponent(wallpaper.thumbnailRelativePath)
    }
}
