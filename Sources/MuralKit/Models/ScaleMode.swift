import AVFoundation
import Foundation

/// How wallpaper content fits the display.
public enum ScaleMode: String, CaseIterable, Codable, Sendable {
    case fill // crop to fill (preserve aspect, cover)
    case fit // letterbox to fit (preserve aspect, contain)
    case stretch // distort to fill (ignore aspect)
    case center // 1:1 centered (no scaling)
    case tile // repeated

    /// Best-effort mapping to AVPlayerLayer.videoGravity. `.center` and `.tile`
    /// fall back to `.resizeAspect`; the renderer takes responsibility for the
    /// real behavior (`.center` via explicit frame; `.tile` via CAReplicatorLayer).
    public var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: .resizeAspectFill
        case .fit: .resizeAspect
        case .stretch: .resize
        case .center: .resizeAspect
        case .tile: .resizeAspect
        }
    }
}
