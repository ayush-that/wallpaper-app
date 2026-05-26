import SwiftUI
import UniformTypeIdentifiers

public struct LibraryView: View {
    @ObservedObject public var vm: LibraryViewModel
    public var onUseAsWallpaper: (Wallpaper) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 256, maximum: 320), spacing: 16, alignment: .top)
    ]

    public init(vm: LibraryViewModel, onUseAsWallpaper: @escaping (Wallpaper) -> Void) {
        self.vm = vm
        self.onUseAsWallpaper = onUseAsWallpaper
    }

    public var body: some View {
        ScrollView {
            if vm.wallpapers.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(vm.wallpapers) { wallpaper in
                        WallpaperCard(
                            wallpaper: wallpaper,
                            thumbnailURL: vm.thumbnail(for: wallpaper),
                            isSelected: vm.selected?.id == wallpaper.id
                        )
                        .onTapGesture {
                            vm.select(wallpaper)
                            onUseAsWallpaper(wallpaper)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { vm.importError != nil },
                set: { isPresented in
                    if !isPresented { vm.importError = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.importError ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop a video, image, .zip, or .pkg here")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let collector = URLCollector()
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { collector.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            MainActor.assumeIsolated {
                vm.importURLs(collector.snapshot())
            }
        }
        return true
    }
}

private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    func snapshot() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }
}
