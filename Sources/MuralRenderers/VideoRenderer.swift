import AppKit
import AVFoundation
import OSLog

/// Plays a video asset as a wallpaper: muted, hardware-decoded, seamlessly
/// looped via `AVPlayerLooper`. The looper is retained for the lifetime of
/// the renderer (dropping it kills the loop silently). Audio is suppressed
/// at two layers (`isMuted = true` and `audioMix = nil`) to prevent the
/// audio HAL from being spun up, which is a real battery drain on idle
/// wallpapers.
@MainActor
public final class VideoRenderer: WallpaperRenderer {
    private let log = Log.logger("VideoRenderer")
    private let asset: VideoAsset
    private var scaleMode: ScaleMode

    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper // MUST be retained; drop and loop dies silently
    private let playerLayer: AVPlayerLayer
    private weak var host: WallpaperHost?

    public init(asset: VideoAsset, scaleMode: ScaleMode) throws {
        self.asset = asset
        self.scaleMode = scaleMode

        let urlAsset = AVURLAsset(url: asset.url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let item = AVPlayerItem(asset: urlAsset)
        item.audioMix = nil // prevent audio HAL spin-up entirely

        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        queue.automaticallyWaitsToMinimizeStalling = false
        queue.actionAtItemEnd = .advance
        player = queue

        looper = AVPlayerLooper(player: queue, templateItem: item)

        let layer = AVPlayerLayer(player: queue)
        layer.videoGravity = scaleMode.videoGravity
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer = layer
    }

    public func attach(to host: WallpaperHost) {
        self.host = host
        host.install(layer: playerLayer)
        player.play()
    }

    public func detach() {
        player.pause()
        host?.clear()
        host = nil
    }

    public func pause() {
        player.pause()
    }

    public func resume() {
        player.play()
    }

    public func setScaleMode(_ mode: ScaleMode) {
        scaleMode = mode
        playerLayer.videoGravity = mode.videoGravity
    }

    /// Phase 7 hook: clamp bitrate / resolution under thermal pressure.
    public func setPreferredCeiling(bitrateBPS: Double?, maxPixels: CGSize?) {
        if let bps = bitrateBPS { player.currentItem?.preferredPeakBitRate = bps }
        if let px = maxPixels { player.currentItem?.preferredMaximumResolution = px }
    }

    // MARK: - PropertiesSink

    /// Phase 9: apply a live property override. Recognised names: `playbackRate`,
    /// `volume`, `scaleMode`. Unknown names are silently ignored. Lives on the
    /// class (not a separate-file extension) because `player` is `private`.
    public func apply(propertyName: String, value: WebBridgePropertyValue) {
        switch propertyName {
        case "playbackRate":
            if case let .double(rate) = value {
                player.rate = Float(rate)
            }
        case "volume":
            if case let .double(level) = value {
                player.volume = Float(level)
                player.isMuted = level == 0
            }
        case "scaleMode":
            if case let .string(raw) = value, let mode = ScaleMode(rawValue: raw) {
                setScaleMode(mode)
            }
        default:
            break
        }
    }

    // MARK: - Test seams

    #if DEBUG
        /// Test-only accessor. Production callers go through the host.
        var testPlayerLayer: AVPlayerLayer? {
            playerLayer
        }

        /// Test-only accessor for verifying preferredPeakBitRate / preferredMaximumResolution.
        var testCurrentItem: AVPlayerItem? {
            player.currentItem
        }
    #endif
}

// MARK: - PropertiesSink conformance

extension VideoRenderer: PropertiesSink {}
