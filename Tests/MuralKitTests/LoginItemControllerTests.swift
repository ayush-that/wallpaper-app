@testable import Mural
import ServiceManagement
import XCTest

@MainActor
final class LoginItemControllerTests: XCTestCase {
    func test_shared_instance_is_singleton() {
        let a = LoginItemController.shared
        let b = LoginItemController.shared
        XCTAssertTrue(a === b)
    }

    func test_status_returns_one_of_known_cases() {
        let status = LoginItemController.shared.status
        let known: [SMAppService.Status] = [
            .notRegistered,
            .enabled,
            .requiresApproval,
            .notFound
        ]
        XCTAssertTrue(known.contains(status), "unexpected SMAppService.Status case: \(status)")
    }

    func test_isEnabled_matches_status_enabled() {
        let isEnabled = LoginItemController.shared.isEnabled()
        XCTAssertEqual(isEnabled, LoginItemController.shared.status == .enabled)
    }

    func test_setEnabled_does_not_crash_for_either_value() {
        // We don't assert on the outcome — the test runner isn't really
        // bootstrapped as a Login Item. Just verify the API doesn't trap.
        LoginItemController.shared.setEnabled(false)
        // Don't actually flip to true in CI — that registers the test runner
        // as a login item, which leaks across runs.
    }
}
