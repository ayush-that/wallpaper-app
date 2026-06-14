import AppKit

/// Testable drop-acceptance policy. The actual `NSDraggingDestination`
/// callbacks live on `DropForwardView`, which delegates here.
@MainActor
public final class StatusBarDropTarget: NSObject, NSDraggingDestination {
    private let onDrop: (URL) -> Void

    public init(onDrop: @escaping (URL) -> Void) {
        self.onDrop = onDrop
    }

    public func shouldAccept(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return VideoAsset.supportedExtensions.contains(ext)
    }

    /// Test seam - bypass the AppKit drag pasteboard.
    public func simulate(drop urls: [URL]) {
        guard let first = urls.first(where: { shouldAccept(filename: $0.path) }) else { return }
        onDrop(first)
    }

    // MARK: NSDraggingDestination

    public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.types?.contains(.fileURL) == true ? .copy : []
    }

    public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return false
        }
        guard let accepted = urls.first(where: { shouldAccept(filename: $0.path) }) else {
            return false
        }
        onDrop(accepted)
        return true
    }
}
