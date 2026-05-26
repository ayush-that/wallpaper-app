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

    /// Start system audio capture. Idempotent. Returns `false` if Screen
    /// Recording TCC is not granted or the capture pipeline fails to start —
    /// the UI catches `false` and surfaces the TCC onboarding sheet (Task 8).
    @discardableResult
    public func enableAudio() async -> Bool {
        guard !audioStarted else { return true }
        guard SystemAudioCapture.preflight() == .granted else {
            log.warning("Audio enable requested but Screen Recording TCC not granted.")
            PermissionRequest.post(.screenRecording)
            return false
        }
        do {
            try await audio.start()
            audioStarted = true
            return true
        } catch {
            log.error("AudioPipeline start failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Stop system audio capture. Idempotent.
    public func disableAudio() async {
        await audio.stop()
        audioStarted = false
    }
}
