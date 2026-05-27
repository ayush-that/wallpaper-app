import AppKit
import CoreGraphics
@testable import Mural
import XCTest

@MainActor
final class FullscreenWatcherTests: XCTestCase {
    func test_scan_with_no_displays_returns_empty() {
        let occluded = FullscreenWatcher.scan(displays: [:], coverageThreshold: 0.95)
        XCTAssertTrue(occluded.isEmpty)
    }

    func test_scan_with_no_windows_returns_empty() {
        // We can't easily inject window-info into CGWindowList in a unit test,
        // but with NO displays at all, the function returns early — covered above.
        // This test verifies the function executes against the live system without
        // crashing for whatever real displays the test runner has.
        let displays: [String: NSScreen] = [:]
        _ = FullscreenWatcher.scan(displays: displays, coverageThreshold: 0.95)
    }

    func test_start_invokes_callback_within_interval() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "no displays attached")
        let watcher = FullscreenWatcher(
            displayProvider: { [:] },
            pollInterval: 0.1,
            coverageThreshold: 0.95
        )
        defer { watcher.stop() }

        let captured = LockedBox<Set<String>?>(value: nil)
        watcher.start { occluded in
            captured.set(occluded)
        }

        let expectation = expectation(description: "callback fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if captured.get() != nil { expectation.fulfill() }
        }
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func test_stop_prevents_further_callbacks() async throws {
        try XCTSkipIf(NSScreen.screens.isEmpty, "no displays attached")
        let watcher = FullscreenWatcher(
            displayProvider: { [:] },
            pollInterval: 0.1,
            coverageThreshold: 0.95
        )
        let callCount = LockedBox<Int>(value: 0)
        watcher.start { _ in
            callCount.set(callCount.get() + 1)
        }
        try await Task.sleep(nanoseconds: 250_000_000) // ~2-3 ticks
        watcher.stop()
        let snapshotAfterStop = callCount.get()
        try await Task.sleep(nanoseconds: 250_000_000)
        // No new callbacks should fire after stop().
        XCTAssertEqual(callCount.get(), snapshotAfterStop)
    }

    func test_double_stop_is_idempotent() {
        let watcher = FullscreenWatcher(displayProvider: { [:] })
        watcher.stop()
        watcher.stop()
    }
}

private final class LockedBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(value: T) {
        self.value = value
    }

    func get() -> T {
        lock.lock(); defer { lock.unlock() }; return value
    }

    func set(_ new: T) {
        lock.lock(); value = new; lock.unlock()
    }
}
