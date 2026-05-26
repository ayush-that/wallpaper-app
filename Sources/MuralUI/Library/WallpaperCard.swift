import SwiftUI

public struct WallpaperCard: View {
    public let wallpaper: Wallpaper
    public let thumbnailURL: URL
    public let isSelected: Bool

    public init(wallpaper: Wallpaper, thumbnailURL: URL, isSelected: Bool) {
        self.wallpaper = wallpaper
        self.thumbnailURL = thumbnailURL
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.2)
                case let .success(image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Color.gray.opacity(0.2)
                        .overlay(
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.secondary)
                        )
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 256, height: 144)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            )

            Text(wallpaper.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(wallpaper.type.rawValue.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 256)
    }
}
