@testable import Mural
import XCTest

@MainActor
final class RemoteSessionWatcherTests: XCTestCase {
    func test_is_remote_does_not_crash() {
        let watcher = RemoteSessionWatcher()
        _ = watcher.isRemote()
    }

    func test_start_fires_callback_immediately_with_current_state() {
        let watcher = RemoteSessionWatcher()
        defer { watcher.stop() }

        let captured = LockedBox<Bool?>(value: nil)
        watcher.start { isRemote in
            captured.set(isRemote)
        }
        // start() fires onChange synchronously.
        XCTAssertNotNil(captured.get())
    }

    func test_initial_callback_matches_isRemote_synchronous_query() {
        let watcher = RemoteSessionWatcher()
        defer { watcher.stop() }
        let captured = LockedBox<Bool?>(value: nil)
        watcher.start { isRemote in
            captured.set(isRemote)
        }
        XCTAssertEqual(captured.get(), watcher.isRemote())
    }

    func test_no_transition_no_extra_callbacks() async throws {
        let watcher = RemoteSessionWatcher(pollInterval: 0.05)
        let callCount = LockedBox<Int>(value: 0)
        watcher.start { _ in callCount.set(callCount.get() + 1) }
        try await Task.sleep(nanoseconds: 200_000_000) // ~4 polls
        watcher.stop()
        // Only the initial synchronous fire — no transitions in this test window.
        XCTAssertEqual(callCount.get(), 1, "callback should fire only on transitions after the initial fire")
    }

    func test_stop_is_idempotent() {
        let watcher = RemoteSessionWatcher()
        watcher.stop()
        watcher.stop()
    }

    func test_stop_before_start_is_a_noop() {
        let watcher = RemoteSessionWatcher()
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
