@testable import Mural
import XCTest

final class AudioRingBufferTests: XCTestCase {
    func test_write_then_read_returns_same_samples() {
        let ring = AudioRingBuffer(capacity: 8)
        ring.write([1.0, 2.0, 3.0, 4.0])
        XCTAssertEqual(ring.read(count: 4), [1.0, 2.0, 3.0, 4.0])
    }

    func test_read_more_than_filled_returns_what_we_have() {
        let ring = AudioRingBuffer(capacity: 8)
        ring.write([1.0, 2.0])
        XCTAssertEqual(ring.read(count: 4), [1.0, 2.0])
    }

    func test_overwrites_oldest_when_capacity_exceeded() {
        let ring = AudioRingBuffer(capacity: 4)
        ring.write([1.0, 2.0, 3.0, 4.0])
        ring.write([5.0, 6.0])
        // After two writes, ring holds [3,4,5,6] in chronological order.
        XCTAssertEqual(ring.read(count: 4), [3.0, 4.0, 5.0, 6.0])
    }

    func test_full_overwrite_keeps_only_newest_window() {
        let ring = AudioRingBuffer(capacity: 4)
        ring.write([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
        XCTAssertEqual(ring.read(count: 4), [5.0, 6.0, 7.0, 8.0])
    }

    func test_latest_pads_front_with_zeros_when_underfilled() {
        let ring = AudioRingBuffer(capacity: 8)
        ring.write([1.0, 2.0])
        XCTAssertEqual(ring.latest(count: 4), [0.0, 0.0, 1.0, 2.0])
    }

    func test_latest_returns_exact_window_when_full() {
        let ring = AudioRingBuffer(capacity: 8)
        ring.write([1.0, 2.0, 3.0, 4.0, 5.0])
        XCTAssertEqual(ring.latest(count: 4), [2.0, 3.0, 4.0, 5.0])
    }

    func test_latest_all_zeros_when_buffer_empty() {
        let ring = AudioRingBuffer(capacity: 8)
        XCTAssertEqual(ring.latest(count: 4), [0.0, 0.0, 0.0, 0.0])
    }

    func test_empty_write_is_noop() {
        let ring = AudioRingBuffer(capacity: 8)
        ring.write([])
        XCTAssertEqual(ring.read(count: 4), [])
    }

    func test_concurrent_writes_do_not_corrupt_capacity() {
        // Light concurrent-fuzz: 1000 small writes from 4 dispatch queues.
        let ring = AudioRingBuffer(capacity: 1024)
        let group = DispatchGroup()
        for _ in 0 ..< 4 {
            group.enter()
            DispatchQueue.global().async {
                for _ in 0 ..< 250 {
                    ring.write([0.1, 0.2, 0.3, 0.4])
                }
                group.leave()
            }
        }
        group.wait()
        // Total writes = 4 × 250 × 4 = 4000 samples written; capacity 1024 → ring full.
        let snapshot = ring.read(count: 1024)
        XCTAssertEqual(snapshot.count, 1024)
        // All values come from {0.1, 0.2, 0.3, 0.4}, no torn writes.
        for value in snapshot {
            XCTAssertTrue(
                [0.1, 0.2, 0.3, 0.4].contains(value),
                "ring buffer corrupted under concurrent write: \(value)"
            )
        }
    }
}
