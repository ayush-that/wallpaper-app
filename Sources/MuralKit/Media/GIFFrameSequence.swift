import CoreGraphics
import Foundation
import ImageIO

public enum GIFFrameSequenceError: Error, Equatable {
    case unreadable(URL)
    case empty(URL)
}

/// Decodes an animated GIF into an ordered list of CGImage frames with
/// per-frame delays. Pure data — no rendering. `GIFRenderer` (Phase 6 Task 2)
/// consumes this and drives frame swaps on a CVDisplayLink.
public struct GIFFrameSequence: Sendable {
    public struct Frame: Sendable {
        public let image: CGImage
        public let delaySeconds: Double
    }

    public let frames: [Frame]
    public let totalDuration: Double

    public init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw GIFFrameSequenceError.unreadable(url)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw GIFFrameSequenceError.empty(url) }

        var frames: [Frame] = []
        var total: Double = 0
        for index in 0 ..< count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let gifDict = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let unclamped = gifDict?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
            let clamped = gifDict?[kCGImagePropertyGIFDelayTime as String] as? Double
            let raw = unclamped ?? clamped ?? 0.1
            let safe = max(raw, 0.02) // floor at 20ms to avoid 100% CPU
            frames.append(Frame(image: image, delaySeconds: safe))
            total += safe
        }
        guard !frames.isEmpty else { throw GIFFrameSequenceError.empty(url) }
        self.frames = frames
        totalDuration = total
    }

    /// Pick the right frame for a given progress through the loop.
    /// `progress` is wrapped modulo 1.0 (so 1.25 → 0.25, -0.1 → 0.9).
    public func frame(at progress: Double) -> Frame? {
        guard !frames.isEmpty else { return nil }
        var wrapped = progress.truncatingRemainder(dividingBy: 1.0)
        if wrapped < 0 { wrapped += 1.0 }
        let elapsed = wrapped * totalDuration
        var accumulated: Double = 0
        for frame in frames {
            accumulated += frame.delaySeconds
            if elapsed < accumulated { return frame }
        }
        return frames.last
    }
}
