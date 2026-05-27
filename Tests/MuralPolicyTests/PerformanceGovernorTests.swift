import Foundation
@testable import Mural
import XCTest

@MainActor
final class PerformanceGovernorTests: XCTestCase {
    func test_nominal_state_clears_ceilings_and_sets_shader_to_60fps() {
        var lastVideo: (Double?, CGSize?) = (-1, .zero)
        var lastShaderFPS = -1
        PerformanceGovernor.apply(
            state: .nominal,
            videoApply: { lastVideo = ($0, $1) },
            shaderApply: { lastShaderFPS = $0 }
        )
        XCTAssertNil(lastVideo.0)
        XCTAssertNil(lastVideo.1)
        XCTAssertEqual(lastShaderFPS, 60)
    }

    func test_fair_state_clears_ceilings_and_sets_shader_to_60fps() {
        var lastVideo: (Double?, CGSize?) = (-1, .zero)
        var lastShaderFPS = -1
        PerformanceGovernor.apply(
            state: .fair,
            videoApply: { lastVideo = ($0, $1) },
            shaderApply: { lastShaderFPS = $0 }
        )
        XCTAssertNil(lastVideo.0)
        XCTAssertNil(lastVideo.1)
        XCTAssertEqual(lastShaderFPS, 60)
    }

    func test_serious_state_clamps_video_and_drops_shader_to_30fps() {
        var lastVideo: (Double?, CGSize?) = (nil, nil)
        var lastShaderFPS = -1
        PerformanceGovernor.apply(
            state: .serious,
            videoApply: { lastVideo = ($0, $1) },
            shaderApply: { lastShaderFPS = $0 }
        )
        XCTAssertEqual(lastVideo.0, 4_000_000)
        XCTAssertEqual(lastVideo.1, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(lastShaderFPS, 30)
    }

    func test_critical_state_clamps_video_and_drops_shader_to_15fps() {
        var lastVideo: (Double?, CGSize?) = (nil, nil)
        var lastShaderFPS = -1
        PerformanceGovernor.apply(
            state: .critical,
            videoApply: { lastVideo = ($0, $1) },
            shaderApply: { lastShaderFPS = $0 }
        )
        XCTAssertEqual(lastVideo.0, 1_000_000)
        XCTAssertEqual(lastVideo.1, CGSize(width: 1280, height: 720))
        XCTAssertEqual(lastShaderFPS, 15)
    }

    func test_start_invokes_appliers_immediately_with_current_state() {
        var videoCalled = false
        var shaderCalled = false
        let governor = PerformanceGovernor(
            videoApply: { _, _ in videoCalled = true },
            shaderApply: { _ in shaderCalled = true }
        )
        defer { governor.stop() }
        governor.start()
        XCTAssertTrue(videoCalled, "start() must invoke videoApply immediately")
        XCTAssertTrue(shaderCalled, "start() must invoke shaderApply immediately")
    }

    func test_stop_is_idempotent() {
        let governor = PerformanceGovernor(videoApply: { _, _ in }, shaderApply: { _ in })
        governor.stop()
        governor.stop()
    }

    func test_stop_before_start_is_a_noop() {
        let governor = PerformanceGovernor(videoApply: { _, _ in }, shaderApply: { _ in })
        governor.stop()
    }
}
