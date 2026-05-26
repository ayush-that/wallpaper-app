import AppKit
@testable import Mural
import XCTest

@MainActor
final class StatusBarDropTargetTests: XCTestCase {
    func test_accepts_supported_video_extensions() {
        let target = StatusBarDropTarget(onDrop: { _ in })
        XCTAssertTrue(target.shouldAccept(filename: "/tmp/clip.mp4"))
        XCTAssertTrue(target.shouldAccept(filename: "/tmp/clip.MOV"))
        XCTAssertTrue(target.shouldAccept(filename: "/tmp/clip.webm"))
        XCTAssertTrue(target.shouldAccept(filename: "/tmp/clip.mkv"))
    }

    func test_rejects_unsupported_extensions() {
        let target = StatusBarDropTarget(onDrop: { _ in })
        XCTAssertFalse(target.shouldAccept(filename: "/tmp/photo.jpg"))
        XCTAssertFalse(target.shouldAccept(filename: "/tmp/data.csv"))
        XCTAssertFalse(target.shouldAccept(filename: "/tmp/noext"))
    }

    func test_simulate_drop_invokes_callback_with_first_video() {
        var captured: URL?
        let target = StatusBarDropTarget(onDrop: { captured = $0 })
        target.simulate(drop: [
            URL(fileURLWithPath: "/tmp/photo.jpg"),
            URL(fileURLWithPath: "/tmp/clip.mp4"),
            URL(fileURLWithPath: "/tmp/other.mov")
        ])
        XCTAssertEqual(captured?.path, "/tmp/clip.mp4")
    }

    func test_simulate_drop_with_no_video_is_a_noop() {
        var captured: URL?
        let target = StatusBarDropTarget(onDrop: { captured = $0 })
        target.simulate(drop: [URL(fileURLWithPath: "/tmp/photo.jpg")])
        XCTAssertNil(captured)
    }
}
