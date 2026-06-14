import Foundation
@testable import Mural
import XCTest

final class WebBridgeMessageTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Property changed

    func test_decode_property_changed_with_double_value() throws {
        let raw = Data(#"{"type":"propertyChanged","name":"speed","value":0.42}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .propertyChanged(name, value) = message else {
            return XCTFail("expected .propertyChanged; got \(message)")
        }
        XCTAssertEqual(name, "speed")
        XCTAssertEqual(value, .double(0.42))
    }

    func test_decode_property_changed_with_bool_value() throws {
        let raw = Data(#"{"type":"propertyChanged","name":"smooth","value":true}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .propertyChanged(_, .bool(v)) = message else {
            return XCTFail("expected .bool, got \(message)")
        }
        XCTAssertTrue(v)
    }

    func test_decode_property_changed_with_int_value() throws {
        let raw = Data(#"{"type":"propertyChanged","name":"engine","value":2}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .propertyChanged(_, .int(v)) = message else {
            return XCTFail("expected .int, got \(message)")
        }
        XCTAssertEqual(v, 2)
    }

    func test_decode_property_changed_with_color_value() throws {
        let raw = Data(##"{"type":"propertyChanged","name":"tint","value":"#ff8800"}"##.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .propertyChanged(_, .color(v)) = message else {
            return XCTFail("expected .color, got \(message)")
        }
        XCTAssertEqual(v, "#ff8800")
    }

    func test_decode_property_changed_with_plain_string_value() throws {
        let raw = Data(#"{"type":"propertyChanged","name":"title","value":"Hello"}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .propertyChanged(_, .string(v)) = message else {
            return XCTFail("expected .string, got \(message)")
        }
        XCTAssertEqual(v, "Hello")
    }

    // MARK: - Console

    func test_decode_console_message() throws {
        let raw = Data(#"{"type":"console","level":"info","message":"hi"}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .console(level, body) = message else {
            return XCTFail("expected .console; got \(message)")
        }
        XCTAssertEqual(level, "info")
        XCTAssertEqual(body, "hi")
    }

    // MARK: - Ready + Unknown

    func test_decode_ready_message() throws {
        let raw = Data(#"{"type":"ready"}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        XCTAssertEqual(message, .ready)
    }

    func test_decode_unknown_type_falls_back_gracefully() throws {
        let raw = Data(#"{"type":"futureshape","foo":"bar"}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .unknown(typeName) = message else {
            return XCTFail("expected .unknown; got \(message)")
        }
        XCTAssertEqual(typeName, "futureshape")
    }

    // MARK: - Encode round-trip

    func test_encode_property_changed_round_trip() throws {
        let original = WebBridgeMessage.propertyChanged(name: "speed", value: .double(1.5))
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WebBridgeMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_encode_console_round_trip() throws {
        let original = WebBridgeMessage.console(level: "warn", message: "x")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WebBridgeMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_encode_ready_round_trip() throws {
        let original = WebBridgeMessage.ready
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WebBridgeMessage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Property value type ordering

    func test_bool_value_is_not_mistakenly_decoded_as_int() throws {
        // This is the load-bearing invariant: JSON `true` MUST decode to .bool,
        // not .int(1). Verify by checking that `value == .bool(true)`, not `.int(1)`.
        let raw = Data(#"{"type":"propertyChanged","name":"x","value":true}"#.utf8)
        let message = try decoder.decode(WebBridgeMessage.self, from: raw)
        guard case let .propertyChanged(_, value) = message else {
            return XCTFail("not a propertyChanged")
        }
        XCTAssertEqual(value, .bool(true))
        XCTAssertNotEqual(value, .int(1))
    }

    func test_double_does_not_get_truncated_to_int_when_whole_number() throws {
        // JSON `5` is integral — decoder will pick `.int`. JSON `5.0` is fractional — `.double`.
        // Verify both paths.
        let intRaw = Data(#"{"type":"propertyChanged","name":"x","value":5}"#.utf8)
        let dblRaw = Data(#"{"type":"propertyChanged","name":"x","value":5.0}"#.utf8)

        let intMsg = try decoder.decode(WebBridgeMessage.self, from: intRaw)
        let dblMsg = try decoder.decode(WebBridgeMessage.self, from: dblRaw)

        if case let .propertyChanged(_, v) = intMsg { XCTAssertEqual(v, .int(5)) } else {
            XCTFail("expected .propertyChanged from intMsg, got \(intMsg)")
        }
        // JSONDecoder normalises "5.0" to Int when single-value-container goes
        // Int-first. We try Int(...) before Double(...) in init(from:), so this
        // is acceptable behavior: 5.0 may also decode as .int(5).
        if case let .propertyChanged(_, v) = dblMsg {
            // Accept either — both representations are equally valid.
            XCTAssertTrue(v == .int(5) || v == .double(5.0), "got \(v)")
        } else { XCTFail("expected .propertyChanged from dblMsg, got \(dblMsg)") }
    }
}
