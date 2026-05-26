@testable import Mural
import XCTest

final class TCCStatusTests: XCTestCase {
    func test_settings_url_for_screen_recording_matches_known_anchor() {
        let url = TCCStatus.systemSettingsURL(for: .screenRecording)
        XCTAssertEqual(
            url.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
    }

    func test_settings_url_for_automation_matches_known_anchor() {
        let url = TCCStatus.systemSettingsURL(for: .automation)
        XCTAssertEqual(
            url.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        )
    }
}
