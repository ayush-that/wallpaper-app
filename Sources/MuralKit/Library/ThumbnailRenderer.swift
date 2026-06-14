import AppKit
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ThumbnailRendererError: Error, Equatable {
    case unreadable
    case encodeFailed
}

/// Stateless thumbnail generator. Produces a PNG on disk from either an
/// image file (via `CGImageSource`) or the first frame of a video (via
/// `AVAssetImageGenerator`). Used by importers to populate the library.
public enum ThumbnailRenderer {
    /// Render a thumbnail from an image file at `imageURL` into `dest` as PNG.
    /// `size` is interpreted as `kCGImageSourceThumbnailMaxPixelSize`, a max
    /// for the longer edge; the result may be smaller (especially when the
    /// source would otherwise be upscaled).
    public static func render(imageURL: URL, to dest: URL, size: CGSize) throws {
        guard let src = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw ThumbnailRendererError.unreadable
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            throw ThumbnailRendererError.unreadable
        }
        try writePNG(cg, to: dest)
    }

    /// Render a thumbnail from the first frame of `videoURL` into `dest` as
    /// PNG. `size` is passed as `AVAssetImageGenerator.maximumSize`, which
    /// preserves aspect and constrains both dimensions.
    public static func render(videoURL: URL, to dest: URL, size: CGSize) throws {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        do {
            let cg = try generator.copyCGImage(at: .zero, actualTime: nil)
            try writePNG(cg, to: dest)
        } catch let error as ThumbnailRendererError {
            throw error
        } catch {
            throw ThumbnailRendererError.unreadable
        }
    }

    private static func writePNG(_ image: CGImage, to dest: URL) throws {
        guard let out = CGImageDestinationCreateWithURL(
            dest as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ThumbnailRendererError.encodeFailed
        }
        CGImageDestinationAddImage(out, image, nil)
        guard CGImageDestinationFinalize(out) else {
            throw ThumbnailRendererError.encodeFailed
        }
    }
}
