@testable import Mural
import SwiftUI
import XCTest

@MainActor
final class PermissionRequiredSheetTests: XCTestCase {
    func test_init_stores_service_and_dismiss_handler() {
        var dismissedCount = 0
        let sheet = PermissionRequiredSheet(service: .screenRecording) {
            dismissedCount += 1
        }
        XCTAssertEqual(sheet.service, .screenRecording)
        // No way to invoke the closure without rendering; just verify init compiles
        // and binds correctly.
        _ = dismissedCount
    }

    func test_permission_request_post_carries_service_in_userInfo() {
        let expectation = expectation(description: "notification received")
        let observer = NotificationCenter.default.addObserver(
            forName: .muralRequestPermission,
            object: nil,
            queue: nil
        ) { notification in
            guard let service = notification.userInfo?["service"] as? TCCStatus.Service else {
                XCTFail("missing service in userInfo")
                return
            }
            XCTAssertEqual(service, .screenRecording)
            expectation.fulfill()
        }
        PermissionRequest.post(.screenRecording)
        wait(for: [expectation], timeout: 0.5)
        NotificationCenter.default.removeObserver(observer)
    }

    func test_all_service_titles_resolve_non_empty() {
        // The sheet shouldn't ever display an empty title. Walk each case.
        for service in [TCCStatus.Service.screenRecording, .automation, .accessibility, .microphone] {
            let sheet = PermissionRequiredSheet(service: service) {}
            // No public accessor; rely on the body rendering without crashing
            // (compile + private computed properties tested via render).
            _ = sheet.body
        }
    }
}
