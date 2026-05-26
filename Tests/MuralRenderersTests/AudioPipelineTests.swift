@testable import Mural
import XCTest

@MainActor
final class AudioPipelineTests: XCTestCase {
    func test_pipeline_exposes_ring_and_broadcaster() {
        let pipeline = AudioPipeline()
        XCTAssertEqual(pipeline.ring.capacity, 4096)
        XCTAssertEqual(pipeline.broadcaster.subscriberCount, 0)
    }

    func test_publishForTests_dispatches_to_subscribers() {
        let pipeline = AudioPipeline()
        let captured = LockedBox<[Float]?>(value: nil)
        _ = pipeline.broadcaster.subscribe { bins in
            captured.set(bins)
        }
        pipeline.publishForTests(bins: [0.5, 0.5])
        // `publish` is synchronous — no timer or queue hop here.
        XCTAssertEqual(captured.get(), [0.5, 0.5])
    }

    func test_stop_before_start_does_not_crash() async {
        let pipeline = AudioPipeline()
        await pipeline.stop() // must not crash
    }

    func test_start_when_permission_denied_throws_or_no_ops() async {
        // Same shape as SystemAudioCaptureTests — TCC dependent; accept either
        // outcome. The assertion is just "no crash".
        let pipeline = AudioPipeline()
        do {
            try await pipeline.start()
            await pipeline.stop()
        } catch {
            // Expected on machines without Screen Recording permission.
        }
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
}
