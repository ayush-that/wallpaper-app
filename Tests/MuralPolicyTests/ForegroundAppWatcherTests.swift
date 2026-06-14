@testable import Mural
import XCTest

@MainActor
final class ForegroundAppWatcherTests: XCTestCase {
    func test_start_fires_callback_immediately_with_current_frontmost() {
        let watcher = ForegroundAppWatcher()
        defer { watcher.stop() }
        let captured = LockedBox<Bool>(value: false)
        watcher.start { _ in
            captured.set(true)
        }
        // Synchronous initial fire, no async hop.
        XCTAssertTrue(captured.get(), "start() must fire onChange synchronously with current frontmost bundleID")
    }

    func test_stop_is_idempotent() {
        let watcher = ForegroundAppWatcher()
        watcher.stop()
        watcher.stop()
    }

    func test_stop_before_start_is_a_noop() {
        let watcher = ForegroundAppWatcher()
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
