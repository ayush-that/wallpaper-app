@testable import Mural
import XCTest

@MainActor
final class SystemAudioCaptureTests: XCTestCase {
    func test_preflight_returns_one_of_known_states() {
        let result = SystemAudioCapture.preflight()
        XCTAssertTrue([
            SystemAudioCapture.PreflightResult.granted,
            .denied,
            .unknown
        ].contains(result))
    }

    func test_init_stores_ring_reference() {
        let ring = AudioRingBuffer(capacity: 4096)
        let capture = SystemAudioCapture(ring: ring)
        XCTAssertTrue(capture.ring === ring)
    }

    func test_stop_before_start_does_not_crash() async {
        let ring = AudioRingBuffer(capacity: 4096)
        let capture = SystemAudioCapture(ring: ring)
        await capture.stop()
    }

    func test_start_when_permission_denied_throws_or_no_ops() async {
        // If permission isn't granted on this machine, start() will throw at
        // some point in the SCK setup (either no shareable content or a TCC
        // rejection). We accept either outcome; the assertion is just "no crash".
        let ring = AudioRingBuffer(capacity: 4096)
        let capture = SystemAudioCapture(ring: ring)
        do {
            try await capture.start()
            await capture.stop()
        } catch {
            // Expected on machines without Screen Recording permission for our binary.
        }
    }
}
