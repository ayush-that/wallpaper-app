@testable import Mural
import XCTest

final class LogTests: XCTestCase {
    func test_subsystem_namespaces_category_under_bundle_id() {
        let subsystem = Log.subsystem(for: "Windowing")
        XCTAssertTrue(subsystem.hasSuffix(".Windowing"))
        XCTAssertFalse(subsystem.isEmpty)
    }
}
