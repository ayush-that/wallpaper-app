@testable import Mural
import XCTest

final class AudioBroadcasterTests: XCTestCase {
    func test_subscribers_receive_published_bins() {
        let broadcaster = AudioBroadcaster()
        let received = LockedBox<[[Float]]>(value: [])
        let token = broadcaster.subscribe { bins in
            received.mutate { $0.append(bins) }
        }

        broadcaster.publish([0.1, 0.2, 0.3])
        broadcaster.publish([0.4, 0.5, 0.6])

        XCTAssertEqual(received.get(), [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]])
        _ = token
    }

    func test_unsubscribe_stops_delivery() {
        let broadcaster = AudioBroadcaster()
        let count = LockedBox<Int>(value: 0)
        let token = broadcaster.subscribe { _ in count.mutate { $0 += 1 } }

        broadcaster.publish([1.0])
        broadcaster.unsubscribe(token)
        broadcaster.publish([2.0])

        XCTAssertEqual(count.get(), 1)
    }

    func test_multiple_subscribers_all_receive() {
        let broadcaster = AudioBroadcaster()
        let a = LockedBox<Int>(value: 0)
        let b = LockedBox<Int>(value: 0)
        _ = broadcaster.subscribe { _ in a.mutate { $0 += 1 } }
        _ = broadcaster.subscribe { _ in b.mutate { $0 += 1 } }

        broadcaster.publish([1.0])
        broadcaster.publish([2.0])
        broadcaster.publish([3.0])

        XCTAssertEqual(a.get(), 3)
        XCTAssertEqual(b.get(), 3)
    }

    func test_subscriber_count_reflects_active_subscriptions() {
        let broadcaster = AudioBroadcaster()
        XCTAssertEqual(broadcaster.subscriberCount, 0)
        let a = broadcaster.subscribe { _ in }
        let b = broadcaster.subscribe { _ in }
        XCTAssertEqual(broadcaster.subscriberCount, 2)
        broadcaster.unsubscribe(a)
        XCTAssertEqual(broadcaster.subscriberCount, 1)
        broadcaster.unsubscribe(b)
        XCTAssertEqual(broadcaster.subscriberCount, 0)
    }

    func test_publish_with_no_subscribers_is_a_noop() {
        let broadcaster = AudioBroadcaster()
        broadcaster.publish([1.0, 2.0]) // must not crash
    }
}

private final class LockedBox<T>: @unchecked Sendable {
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

    func mutate(_ transform: (inout T) -> Void) {
        lock.lock(); defer { lock.unlock() }
        transform(&value)
    }
}
