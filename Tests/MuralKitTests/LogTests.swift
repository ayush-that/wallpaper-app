import XCTest
@testable import Mural

final class LogTests: XCTestCase {
    func test_log_subsystem_is_namespaced_under_bundle_id() {
        // The unit-test runner's Bundle.main.bundleIdentifier is not
        // "app.mural.Mural", so we test with an injected bundleID override.
        let subsystem = Log.subsystem(for: "Windowing", bundleID: "app.mural.Mural")
        XCTAssertEqual(subsystem, "app.mural.Mural.Windowing")
    }

    func test_log_subsystem_uses_default_bundleID_when_omitted() {
        // Verify the format pattern with the runtime bundle ID.
        let subsystem = Log.subsystem(for: "Windowing")
        XCTAssertTrue(subsystem.hasSuffix(".Windowing"))
    }
}
