import Foundation

public enum VideoAssetError: Error, Equatable {
    case unsupportedExtension(String)
    case unreadable(URL)
}

public struct VideoAsset: Equatable, Hashable, Codable, Sendable {
    public let url: URL

    public static let supportedExtensions: Set<String> = [
        "mp4", "mov", "m4v", "webm", "mkv", "avi", "ogv"
    ]

    public var fileExtension: String {
        url.pathExtension.lowercased()
    }

    public init(url: URL) throws {
        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            throw VideoAssetError.unsupportedExtension(ext)
        }
        self.url = url
    }
}
