import Foundation

/// Canonical on-disk record for one wallpaper in the user's library. All paths
/// are relative to the wallpaper's bundle directory so the library stays
/// portable. `id` is immutable identity; mutable fields support import flows
/// that build the record incrementally.
public struct Wallpaper: Equatable, Hashable, Codable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var author: String
    public var type: WallpaperType
    public var entryRelativePath: String
    public var thumbnailRelativePath: String
    public var previewRelativePath: String?
    public var tags: [String]
    public var license: String?
    public var sourceImporter: WallpaperImporterSource
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        type: WallpaperType,
        entryRelativePath: String,
        thumbnailRelativePath: String = "thumbnail.png",
        previewRelativePath: String? = nil,
        tags: [String] = [],
        license: String? = nil,
        sourceImporter: WallpaperImporterSource = .native,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.type = type
        self.entryRelativePath = entryRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.previewRelativePath = previewRelativePath
        self.tags = tags
        self.license = license
        self.sourceImporter = sourceImporter
        self.createdAt = createdAt
    }
}
