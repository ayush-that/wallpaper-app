import Foundation
import OSLog

/// Drives wallpaper rotation for a single `Playlist`. Each tick selects the
/// next wallpaper UUID according to the playlist's `RotationStrategy` and
/// invokes `onPick` on the main actor. Construct once and call
/// `start(playlist:)` whenever the active playlist changes; calling `start`
/// again replaces any prior schedule.
@MainActor
public final class PlaylistScheduler {
    public typealias PickHandler = @MainActor @Sendable (UUID) -> Void

    private let log = Log.logger("PlaylistScheduler")
    private let onPick: PickHandler
    private var timer: DispatchSourceTimer?
    private var cursor = 0
    private var shuffleBag: [UUID] = []

    public init(onPick: @escaping PickHandler) {
        self.onPick = onPick
    }

    public func start(playlist: Playlist) {
        stop()
        guard playlist.enabled, !playlist.wallpaperIDs.isEmpty else {
            log.debug("start ignored: disabled or empty playlist")
            return
        }
        cursor = 0
        shuffleBag = playlist.wallpaperIDs.shuffled()
        tick(playlist: playlist)

        let interval = playlist.strategy.minIntervalSeconds
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.tick(playlist: playlist)
            }
        }
        timer.resume()
        self.timer = timer
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick(playlist: Playlist) {
        guard !playlist.wallpaperIDs.isEmpty else { return }

        let pick: UUID
        switch playlist.strategy {
        case .interval, .onIdle:
            pick = playlist.wallpaperIDs[cursor % playlist.wallpaperIDs.count]
            cursor += 1

        case .shuffle:
            if shuffleBag.isEmpty {
                shuffleBag = playlist.wallpaperIDs.shuffled()
            }
            pick = shuffleBag.removeFirst()

        case let .timeOfDay(slots):
            if slots.isEmpty {
                pick = playlist.wallpaperIDs[0]
            } else {
                let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
                let nowMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
                let nearest = slots.min(by: { a, b in
                    abs((a.hour * 60 + a.minute) - nowMinutes)
                        < abs((b.hour * 60 + b.minute) - nowMinutes)
                })
                pick = nearest?.wallpaperID ?? playlist.wallpaperIDs[0]
            }
        }

        onPick(pick)
    }
}
