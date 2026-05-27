import Foundation
@testable import Mural
import XCTest

final class LivelyPropertiesCodecTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: type(of: self)).url(
                forResource: "lively-props",
                withExtension: "json",
                subdirectory: "Fixtures"
            ),
            "missing Tests/Fixtures/lively-props.json"
        )
        return try Data(contentsOf: url)
    }

    func test_decodes_all_eight_control_types() throws {
        let controls = try LivelyPropertiesCodec.decode(fixtureData())
        XCTAssertEqual(controls.count, 8)
        let names = Set(controls.map(\.name))
        XCTAssertEqual(names, Set([
            "speed", "tint", "smooth", "label", "engine",
            "asset", "title", "reset"
        ]))
    }

    func test_output_is_sorted_alphabetically_by_name() throws {
        let controls = try LivelyPropertiesCodec.decode(fixtureData())
        let names = controls.map(\.name)
        XCTAssertEqual(names, names.sorted())
    }

    func test_slider_fields_round_trip_from_json() throws {
        let controls = try LivelyPropertiesCodec.decode(fixtureData())
        let speed = try XCTUnwrap(controls.first(where: { $0.name == "speed" }))
        guard case let .slider(name, label, value, min, max, step) = speed else {
            return XCTFail("expected .slider, got \(speed)")
        }
        XCTAssertEqual(name, "speed")
        XCTAssertEqual(label, "Speed")
        XCTAssertEqual(value, 1.0)
        XCTAssertEqual(min, 0)
        XCTAssertEqual(max, 2)
        XCTAssertEqual(step, 0.1)
    }

    func test_color_decodes_hex_string_verbatim() throws {
        let controls = try LivelyPropertiesCodec.decode(fixtureData())
        let tint = try XCTUnwrap(controls.first(where: { $0.name == "tint" }))
        guard case let .color(_, _, value) = tint else { return XCTFail() }
        XCTAssertEqual(value, "#ff8800")
    }

    func test_checkbox_decodes_bool() throws {
        let controls = try LivelyPropertiesCodec.decode(fixtureData())
        let smooth = try XCTUnwrap(controls.first(where: { $0.name == "smooth" }))
        guard case let .checkbox(_, _, value) = smooth else { return XCTFail() }
        XCTAssertTrue(value)
    }

    func test_dropdown_decodes_items_and_selected_index() throws {
        let controls = try LivelyPropertiesCodec.decode(fixtureData())
        let engine = try XCTUnwrap(controls.first(where: { $0.name == "engine" }))
        guard case let .dropdown(_, _, items, value) = engine else { return XCTFail() }
        XCTAssertEqual(items, ["webgl", "canvas"])
        XCTAssertEqual(value, 0)
    }

    func test_label_falls_back_to_name_when_text_field_missing() throws {
        let data = Data(#"{ "info": { "type": "label", "value": "hi" } }"#.utf8)
        let controls = try LivelyPropertiesCodec.decode(data)
        XCTAssertEqual(controls.first?.name, "info")
    }

    func test_unsupported_type_is_silently_dropped() throws {
        // Mixed valid + invalid: invalid entries get skipped, valid ones decode.
        let data = Data(#"""
        {
            "x": { "type": "slider", "value": 1, "min": 0, "max": 2, "step": 0.1, "text": "X" },
            "weird": { "type": "totally-not-a-thing", "value": 42 }
        }
        """#.utf8)
        let controls = try LivelyPropertiesCodec.decode(data)
        XCTAssertEqual(controls.count, 1)
        XCTAssertEqual(controls.first?.name, "x")
    }

    func test_top_level_array_throws_notADictionary() throws {
        let data = Data("[1, 2, 3]".utf8)
        XCTAssertThrowsError(try LivelyPropertiesCodec.decode(data)) { error in
            guard case LivelyPropertiesCodec.DecodeError.notADictionary = error else {
                return XCTFail("expected .notADictionary; got \(error)")
            }
        }
    }

    func test_integer_value_in_slider_is_normalized_to_double() throws {
        // JSON 1 (int) → slider value 1.0
        let data = Data(#"""
        { "intish": { "type": "slider", "value": 5, "min": 0, "max": 10, "step": 1, "text": "Int" } }
        """#.utf8)
        let controls = try LivelyPropertiesCodec.decode(data)
        guard case let .slider(_, _, value, _, _, _) = try XCTUnwrap(controls.first) else {
            return XCTFail()
        }
        XCTAssertEqual(value, 5.0)
    }

    func test_property_control_codable_round_trips_through_swift_json() throws {
        let original = PropertyControl.slider(
            name: "speed",
            label: "Speed",
            value: 1.5,
            min: 0,
            max: 2,
            step: 0.1
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PropertyControl.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
