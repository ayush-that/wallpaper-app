@testable import Mural
import XCTest

@MainActor
final class PowerWatcherTests: XCTestCase {
    func test_initial_state_query_does_not_crash() {
        let watcher = PowerWatcher()
        _ = watcher.isOnBattery()
        _ = watcher.isLowPowerMode()
    }

    func test_start_fires_callback_immediately_with_current_state() {
        let watcher = PowerWatcher()
        defer { watcher.stop() }

        let captured = LockedBox<(Bool, Bool)?>(value: nil)
        watcher.start { onBattery, lowPower in
            captured.set((onBattery, lowPower))
        }
        // The callback runs synchronously inside start(); read immediately.
        let snapshot = captured.get()
        XCTAssertNotNil(snapshot, "start() must fire onChange synchronously with current state")
    }

    func test_initial_callback_values_match_synchronous_queries() {
        let watcher = PowerWatcher()
        defer { watcher.stop() }

        let captured = LockedBox<(Bool, Bool)?>(value: nil)
        watcher.start { onBattery, lowPower in
            captured.set((onBattery, lowPower))
        }
        let snapshot = captured.get()
        XCTAssertEqual(snapshot?.0, watcher.isOnBattery())
        XCTAssertEqual(snapshot?.1, watcher.isLowPowerMode())
    }

    func test_stop_is_idempotent() {
        let watcher = PowerWatcher()
        watcher.stop()
        watcher.stop() // must not crash
    }

    func test_stop_before_start_is_a_noop() {
        let watcher = PowerWatcher()
        watcher.stop() // must not crash
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
