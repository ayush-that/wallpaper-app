import Foundation
@testable import Mural
import XCTest

final class GIFFrameSequenceTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "2frame", withExtension: "gif", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/2frame.gif - regenerate with ffmpeg"
        )
    }

    func test_decode_returns_at_least_two_frames() throws {
        let sequence = try GIFFrameSequence(url: fixtureURL())
        XCTAssertGreaterThanOrEqual(sequence.frames.count, 2)
    }

    func test_total_duration_is_positive() throws {
        let sequence = try GIFFrameSequence(url: fixtureURL())
        XCTAssertGreaterThan(sequence.totalDuration, 0)
    }

    func test_per_frame_delay_is_clamped_to_minimum() throws {
        // Some GIFs encode 0 delay (effectively "as fast as possible"). The decoder
        // clamps that to a sensible minimum so playback doesn't hit 100% CPU.
        let sequence = try GIFFrameSequence(url: fixtureURL())
        for frame in sequence.frames {
            XCTAssertGreaterThanOrEqual(
                frame.delaySeconds,
                0.02,
                "frame delays must be clamped to ≥ 20ms"
            )
        }
    }

    func test_frame_at_progress_zero_returns_first_frame() throws {
        let sequence = try GIFFrameSequence(url: fixtureURL())
        let frame = try XCTUnwrap(sequence.frame(at: 0))
        XCTAssertTrue(
            frame.image === sequence.frames[0].image,
            "progress 0 should return the very first frame"
        )
    }

    func test_frame_at_progress_one_wraps_to_last_frame() throws {
        let sequence = try GIFFrameSequence(url: fixtureURL())
        // 1.0 truncatingRemainder 1.0 = 0.0, so by construction wraps to frame 0.
        let frame = try XCTUnwrap(sequence.frame(at: 1.0))
        XCTAssertTrue(frame.image === sequence.frames[0].image)
    }

    func test_frame_at_progress_handles_negative_progress_gracefully() throws {
        // Defensive: GIFRenderer shouldn't crash if the display link delivers a
        // negative interval (rare but possible after sleep/wake).
        let sequence = try GIFFrameSequence(url: fixtureURL())
        XCTAssertNotNil(sequence.frame(at: -0.25))
    }

    func test_decode_invalid_file_throws() {
        let badURL = URL(fileURLWithPath: "/dev/null")
        XCTAssertThrowsError(try GIFFrameSequence(url: badURL))
    }
}
