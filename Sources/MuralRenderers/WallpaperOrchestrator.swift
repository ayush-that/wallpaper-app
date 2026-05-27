import AppKit
import Combine
import OSLog

/// The single object the library UI calls when the user picks a wallpaper.
/// Owns the active `ScaleMode` and walks every display known to the engine,
/// asking the `RendererFactory` to build a renderer per-host. Failures from
/// the factory fall back to a red solid-colour renderer so the display is
/// not left in an indeterminate state.
///
/// Also owns the shared `AudioPipeline`. Every web renderer produced by
/// `applyToAllDisplays` is auto-subscribed to the pipeline's broadcaster —
/// when audio is off the broadcaster simply never publishes, so the
/// subscriptions cost nothing. The UI calls `enableAudio()` once the user
/// opts in (and grants Screen Recording TCC).
///
/// Owns a `PlaylistScheduler` too. UI calls `startPlaylist(_:)` to begin
/// rotation; the scheduler invokes our private `applyByID(_:)` on each tick
/// which fetches the wallpaper from the catalog and routes through the same
/// `applyToAllDisplays` path used by manual picks.
@MainActor
public final class WallpaperOrchestrator: ObservableObject {
    private let log = Log.logger("Orchestrator")
    private let engine: WallpaperEngine
    private let library: LibraryService
    /// The scheduler closes over `self`, so we can't construct it inline with
    /// the other stored properties. Built lazily on first playlist start. Once
    /// assigned it lives for the orchestrator's lifetime.
    private lazy var scheduler: PlaylistScheduler = .init { [weak self] wallpaperID in
        self?.applyByID(wallpaperID)
    }

    public let audio = AudioPipeline()
    private var audioStarted = false

    @Published public var scaleMode: ScaleMode = .fill

    public init(engine: WallpaperEngine, library: LibraryService) {
        self.engine = engine
        self.library = library
        // Wire the library root into the engine so `ActiveStatus` snapshots
        // carry the right path for cross-process readers (screensaver bundle).
        engine.libraryRoot = library.libraryRoot
    }

    public func applyToAllDisplays(wallpaper: Wallpaper) {
        let package = library.package(for: wallpaper.id)
        let mode = scaleMode
        let broadcaster = audio.broadcaster
        let wallpaperID = wallpaper.id
        engine.setRendererForAllDisplays(
            factory: { [log] in
                do {
                    let renderer = try RendererFactory.makeRenderer(
                        for: wallpaper,
                        package: package,
                        scaleMode: mode
                    )
                    if let webRenderer = renderer as? WebRenderer {
                        webRenderer.attachAudio(broadcaster)
                    }
                    return renderer
                } catch {
                    log.error(
                        "RendererFactory failed for \(wallpaper.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                    return SolidColorRenderer(color: .systemRed)
                }
            },
            wallpaperID: wallpaperID
        )
    }

    /// Begin (or replace) the active playlist. Each scheduler tick fetches the
    /// picked wallpaper from the catalog and applies it to every display.
    public func startPlaylist(_ playlist: Playlist) {
        scheduler.start(playlist: playlist)
    }

    /// Halt scheduled rotation. The currently-rendering wallpaper stays put;
    /// stopping the playlist does not clear displays.
    public func stopPlaylist() {
        scheduler.stop()
    }

    private func applyByID(_ wallpaperID: UUID) {
        do {
            guard let wallpaper = try library.catalog.fetch(id: wallpaperID) else {
                log.warning("Playlist picked unknown wallpaper \(wallpaperID.uuidString, privacy: .public)")
                return
            }
            applyToAllDisplays(wallpaper: wallpaper)
        } catch {
            log.error("Playlist pick fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Start system audio capture. Idempotent.
    ///
    /// We don't trust `CGPreflightScreenCaptureAccess()` — on macOS 15+ the
    /// permission was renamed to "Screen & System Audio Recording" and lives
    /// in a different TCC bucket than the legacy "Screen Recording" one the
    /// preflight API checks. Always attempt `audio.start()`; SCStream's own
    /// error path is authoritative. If start fails with what looks like a
    /// permission error, post the TCC onboarding sheet notification.
    @discardableResult
    public func enableAudio() async -> Bool {
        guard !audioStarted else { return true }
        do {
            try await audio.start()
            audioStarted = true
            log.info("AudioPipeline started.")
            return true
        } catch {
            let description = error.localizedDescription
            log.error("AudioPipeline start failed: \(description, privacy: .public)")
            let lower = description.lowercased()
            if lower.contains("permission") || lower.contains("tcc") || lower.contains("declined")
                || lower.contains("denied") || lower.contains("not authorized")
            {
                PermissionRequest.post(.screenRecording)
            }
            return false
        }
    }

    /// Stop system audio capture. Idempotent.
    public func disableAudio() async {
        await audio.stop()
        audioStarted = false
    }

    /// Snapshot of the currently active `PropertiesSink`s, one per display.
    /// PropertiesViewModel calls into each sink so a single slider drag updates
    /// every display's renderer simultaneously.
    public func activePropertySinks() -> [PropertiesSink] {
        engine.activeRendererUUIDs.compactMap { uuid in
            engine.renderer(for: uuid) as? PropertiesSink
        }
    }

    /// UUID of the "primary" display for property-override scoping. macOS doesn't
    /// expose a stable "primary" concept here; we pick the first attached display
    /// alphabetically so per-display overrides are deterministic across launches.
    public func primaryDisplayUUID() -> String? {
        engine.activeRendererUUIDs.sorted().first
    }
}
