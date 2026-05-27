@testable import Mural
import Sparkle
import XCTest

@MainActor
final class UpdateManagerTests: XCTestCase {
    func test_init_does_not_crash() {
        _ = UpdateManager()
    }

    func test_updater_has_default_check_interval_enabled() {
        let manager = UpdateManager()
        XCTAssertTrue(manager.updater.automaticallyChecksForUpdates)
    }

    func test_automatic_downloads_are_disabled_by_default() {
        let manager = UpdateManager()
        XCTAssertFalse(manager.updater.automaticallyDownloadsUpdates)
    }

    func test_controller_exposes_a_valid_updater() {
        let manager = UpdateManager()
        XCTAssertNotNil(manager.updater)
    }
}
