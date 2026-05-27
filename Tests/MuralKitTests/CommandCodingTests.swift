import Foundation
@testable import Mural
import XCTest

final class CommandCodingTests: XCTestCase {
    private func roundTrip(_ command: Command) throws -> Command {
        let data = try JSONEncoder().encode(command)
        return try JSONDecoder().decode(Command.self, from: data)
    }

    func test_set_round_trips() throws {
        let id = UUID()
        let cmd = Command.set(wallpaperID: id, displayUUID: "A")
        let back = try roundTrip(cmd)
        XCTAssertEqual(back, cmd)
    }

    func test_set_without_display_uuid_round_trips() throws {
        let cmd = Command.set(wallpaperID: UUID(), displayUUID: nil)
        XCTAssertEqual(try roundTrip(cmd), cmd)
    }

    func test_close_with_and_without_display_uuid() throws {
        XCTAssertEqual(try roundTrip(.close(displayUUID: "A")), .close(displayUUID: "A"))
        XCTAssertEqual(try roundTrip(.close(displayUUID: nil)), .close(displayUUID: nil))
    }

    func test_pause_resume_status_round_trip() throws {
        XCTAssertEqual(try roundTrip(.pause), .pause)
        XCTAssertEqual(try roundTrip(.resume), .resume)
        XCTAssertEqual(try roundTrip(.status), .status)
    }

    func test_set_property_round_trips_with_all_value_kinds() throws {
        let id = UUID()
        for value: WebBridgePropertyValue in [
            .bool(true),
            .int(42),
            .double(1.5),
            .string("hello"),
            .color("#ff8800")
        ] {
            let cmd = Command.setProperty(
                wallpaperID: id,
                displayUUID: "A",
                name: "speed",
                value: value
            )
            XCTAssertEqual(try roundTrip(cmd), cmd)
        }
    }

    func test_import_file_round_trips() throws {
        XCTAssertEqual(
            try roundTrip(.importFile(path: "/tmp/test.mp4")),
            .importFile(path: "/tmp/test.mp4")
        )
    }

    func test_decoding_unknown_verb_throws() throws {
        let bad = Data(#"{"verb":"unknown-verb"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Command.self, from: bad))
    }

    func test_response_failure_factory_sets_ok_false() {
        let response = CommandResponse.failure("boom")
        XCTAssertFalse(response.ok)
        XCTAssertEqual(response.message, "boom")
        XCTAssertNil(response.statusJSON)
    }

    func test_response_success_factory_sets_ok_true() {
        let response = CommandResponse.success("done")
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.message, "done")
    }

    func test_response_round_trips_through_json() throws {
        let original = CommandResponse.success("ok", statusJSON: "{\"a\":1}")
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(CommandResponse.self, from: data)
        XCTAssertEqual(back, original)
    }
}
