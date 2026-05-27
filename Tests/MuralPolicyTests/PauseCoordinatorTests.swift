@testable import Mural
import XCTest

@MainActor
final class PauseCoordinatorTests: XCTestCase {
    final class FakeRenderer: WallpaperRenderer {
        var paused = false
        var pauseCount = 0
        var resumeCount = 0

        func attach(to _: WallpaperHost) {}

        func detach() {}

        func pause() {
            paused = true
            pauseCount += 1
        }

        func resume() {
            paused = false
            resumeCount += 1
        }
    }

    /// `WallpaperRenderer` is `AnyObject` but not `Sendable`, so a
    /// `[String: WallpaperRenderer]` cannot be captured by a `@Sendable`
    /// closure under strict concurrency. The lookup table is read-only after
    /// `makeCoordinator` returns, so an `@unchecked Sendable` box is safe.
    private final class LookupBox: @unchecked Sendable {
        let table: [String: WallpaperRenderer]

        init(_ table: [String: WallpaperRenderer]) {
            self.table = table
        }
    }

    private func makeCoordinator(renderers: [String: FakeRenderer]) -> PauseCoordinator {
        let box = LookupBox(renderers as [String: WallpaperRenderer])
        return PauseCoordinator { uuid in box.table[uuid] }
    }

    func test_adding_first_reason_pauses_the_renderer() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.add(.onBattery, for: "A")
        await Task.yield()
        await waitForMainHop()
        XCTAssertTrue(renderer.paused)
        XCTAssertEqual(renderer.pauseCount, 1)
    }

    func test_adding_second_reason_does_not_call_pause_again() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.fullscreenOccluded, for: "A")
        await waitForMainHop()
        XCTAssertEqual(renderer.pauseCount, 1, "pause must fire only on empty→non-empty edge")
    }

    func test_removing_one_of_two_reasons_keeps_renderer_paused() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.fullscreenOccluded, for: "A")
        coordinator.remove(.onBattery, for: "A")
        await waitForMainHop()
        XCTAssertTrue(renderer.paused)
        XCTAssertEqual(renderer.resumeCount, 0)
    }

    func test_removing_last_reason_resumes_the_renderer() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.fullscreenOccluded, for: "A")
        coordinator.remove(.onBattery, for: "A")
        coordinator.remove(.fullscreenOccluded, for: "A")
        await waitForMainHop()
        XCTAssertFalse(renderer.paused)
        XCTAssertEqual(renderer.resumeCount, 1)
    }

    func test_reasons_per_display_are_independent() async {
        let rendererA = FakeRenderer()
        let rendererB = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": rendererA, "B": rendererB])
        coordinator.add(.fullscreenOccluded, for: "A")
        await waitForMainHop()
        XCTAssertTrue(rendererA.paused)
        XCTAssertFalse(rendererB.paused)
    }

    func test_adding_already_present_reason_is_a_noop() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.onBattery, for: "A")
        await waitForMainHop()
        XCTAssertEqual(renderer.pauseCount, 1)
    }

    func test_removing_absent_reason_is_a_noop() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.remove(.onBattery, for: "A")
        await waitForMainHop()
        XCTAssertEqual(renderer.resumeCount, 0)
        XCTAssertEqual(renderer.pauseCount, 0)
    }

    func test_reasons_reflect_current_state() {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        XCTAssertTrue(coordinator.reasons(for: "A").isEmpty)
        coordinator.add(.onBattery, for: "A")
        XCTAssertEqual(coordinator.reasons(for: "A"), .onBattery)
        coordinator.add(.fullscreenOccluded, for: "A")
        XCTAssertEqual(coordinator.reasons(for: "A"), [.onBattery, .fullscreenOccluded])
        coordinator.remove(.onBattery, for: "A")
        XCTAssertEqual(coordinator.reasons(for: "A"), .fullscreenOccluded)
    }

    func test_clear_drops_all_reasons_and_resumes_renderer() async {
        let renderer = FakeRenderer()
        let coordinator = makeCoordinator(renderers: ["A": renderer])
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.fullscreenOccluded, for: "A")
        coordinator.clear(displayUUID: "A")
        await waitForMainHop()
        XCTAssertFalse(renderer.paused)
        XCTAssertTrue(coordinator.reasons(for: "A").isEmpty)
        XCTAssertEqual(renderer.resumeCount, 1)
    }

    func test_tracked_display_count_reflects_distinct_displays_with_reasons() {
        let coordinator = makeCoordinator(renderers: [:])
        XCTAssertEqual(coordinator.trackedDisplayCount, 0)
        coordinator.add(.onBattery, for: "A")
        coordinator.add(.onBattery, for: "B")
        XCTAssertEqual(coordinator.trackedDisplayCount, 2)
        coordinator.remove(.onBattery, for: "A")
        XCTAssertEqual(coordinator.trackedDisplayCount, 1)
    }

    /// Helper: pump the main run loop briefly so the coordinator's
    /// `Task { @MainActor ... }` invocations land before assertions.
    private func waitForMainHop() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
    }
}
