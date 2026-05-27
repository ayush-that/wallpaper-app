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
@MainActor
public final class WallpaperOrchestrator: ObservableObject {
    private let log = Log.logger("Orchestrator")
    private let engine: WallpaperEngine
    private let library: LibraryService

    public let audio = AudioPipeline()
    private var audioStarted = false

    @Published public var scaleMode: ScaleMode = .fill

    public init(engine: WallpaperEngine, library: LibraryService) {
        self.engine = engine
        self.library = library
    }

    public func applyToAllDisplays(wallpaper: Wallpaper) {
        let package = library.package(for: wallpaper.id)
        let mode = scaleMode
        let broadcaster = audio.broadcaster
        engine.setRendererForAllDisplays { [log] in
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
}
