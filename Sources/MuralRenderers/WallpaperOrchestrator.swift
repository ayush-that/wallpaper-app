import AppKit
import Combine
import OSLog

/// The single object the library UI calls when the user picks a wallpaper.
/// Owns the active `ScaleMode` and walks every display known to the engine,
/// asking the `RendererFactory` to build a renderer per-host. Failures from
/// the factory fall back to a red solid-colour renderer so the display is
/// not left in an indeterminate state.
@MainActor
public final class WallpaperOrchestrator: ObservableObject {
    private let log = Log.logger("Orchestrator")
    private let engine: WallpaperEngine
    private let library: LibraryService

    @Published public var scaleMode: ScaleMode = .fill

    public init(engine: WallpaperEngine, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    public func applyToAllDisplays(wallpaper: Wallpaper) {
        let package = library.package(for: wallpaper.id)
        let mode = scaleMode
        engine.setRendererForAllDisplays { [log] in
            do {
                return try RendererFactory.makeRenderer(
                    for: wallpaper,
                    package: package,
                    scaleMode: mode
                )
            } catch {
                log.error(
                    "RendererFactory failed for \(wallpaper.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return SolidColorRenderer(color: .systemRed)
            }
        }
    }
}
