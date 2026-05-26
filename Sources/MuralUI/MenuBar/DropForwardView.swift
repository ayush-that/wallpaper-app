import AppKit

/// Transparent overlay attached on top of the status-bar button. Accepts
/// dragged file URLs and forwards them to `StatusBarDropTarget`, but
/// returns nil from `hitTest` so clicks fall through to the button
/// (otherwise the menu would never open).
@MainActor
final class DropForwardView: NSView {
    private let target: StatusBarDropTarget

    init(frame: NSRect, target: StatusBarDropTarget) {
        self.target = target
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        target.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        target.performDragOperation(sender)
    }

    /// Pass clicks through to the underlying NSStatusBarButton.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
