import Foundation
@testable import Mural
import XCTest

@MainActor
final class PropertiesViewModelTests: XCTestCase {
    private final class RecordingSink: PropertiesSink {
        var calls: [(String, WebBridgePropertyValue)] = []
        func apply(propertyName: String, value: WebBridgePropertyValue) {
            calls.append((propertyName, value))
        }
    }

    private var tmp: URL!
    private var store: PropertyOverrideStore!

    override func setUp() async throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        store = PropertyOverrideStore(root: tmp)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private let arrangement = DisplayArrangementHash(displayUUIDs: ["A"])

    func test_init_seeds_values_from_control_defaults() {
        let sink = RecordingSink()
        let vm = PropertiesViewModel(
            wallpaperID: UUID(),
            displayUUID: "A",
            arrangement: arrangement,
            controls: [
                .slider(name: "speed", label: "Speed", value: 1.25, min: 0, max: 2, step: 0.1),
                .checkbox(name: "smooth", label: "Smooth", value: true),
                .color(name: "tint", label: "Tint", value: "#ff8800")
            ],
            sink: sink,
            store: store
        )
        XCTAssertEqual(vm.values["speed"], .double(1.25))
        XCTAssertEqual(vm.values["smooth"], .bool(true))
        XCTAssertEqual(vm.values["tint"], .color("#ff8800"))
    }

    func test_init_pushes_defaults_into_sink() {
        let sink = RecordingSink()
        _ = PropertiesViewModel(
            wallpaperID: UUID(),
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.slider(name: "speed", label: "Speed", value: 1.0, min: 0, max: 2, step: 0.1)],
            sink: sink,
            store: store
        )
        XCTAssertEqual(sink.calls.count, 1)
        XCTAssertEqual(sink.calls.first?.0, "speed")
    }

    func test_init_layers_persisted_overrides_on_top_of_defaults() throws {
        let wallpaper = UUID()
        try store.set(
            .double(1.75),
            for: "speed",
            wallpaperID: wallpaper,
            displayUUID: "A",
            arrangement: arrangement
        )
        let vm = PropertiesViewModel(
            wallpaperID: wallpaper,
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.slider(name: "speed", label: "Speed", value: 0.0, min: 0, max: 2, step: 0.1)],
            sink: nil,
            store: store
        )
        XCTAssertEqual(vm.values["speed"], .double(1.75))
    }

    func test_set_updates_values_immediately() {
        let sink = RecordingSink()
        let vm = PropertiesViewModel(
            wallpaperID: UUID(),
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.slider(name: "speed", label: "Speed", value: 1.0, min: 0, max: 2, step: 0.1)],
            sink: sink,
            store: store
        )
        vm.set(.double(0.5), for: "speed")
        XCTAssertEqual(vm.values["speed"], .double(0.5))
    }

    func test_set_calls_sink_immediately() {
        let sink = RecordingSink()
        let vm = PropertiesViewModel(
            wallpaperID: UUID(),
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.slider(name: "speed", label: "Speed", value: 1.0, min: 0, max: 2, step: 0.1)],
            sink: sink,
            store: store
        )
        let baselineCalls = sink.calls.count
        vm.set(.double(0.42), for: "speed")
        XCTAssertEqual(sink.calls.count - baselineCalls, 1)
        XCTAssertEqual(sink.calls.last?.0, "speed")
        XCTAssertEqual(sink.calls.last?.1, .double(0.42))
    }

    func test_flush_to_disk_persists_values() {
        let wallpaper = UUID()
        let vm = PropertiesViewModel(
            wallpaperID: wallpaper,
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.slider(name: "speed", label: "Speed", value: 1.0, min: 0, max: 2, step: 0.1)],
            sink: nil,
            store: store
        )
        vm.set(.double(1.5), for: "speed")
        vm.flushToDisk()
        let onDisk = store.read(
            wallpaperID: wallpaper,
            displayUUID: "A",
            arrangement: arrangement
        )
        XCTAssertEqual(onDisk["speed"], .double(1.5))
    }

    func test_debounced_write_persists_within_a_second() async throws {
        let wallpaper = UUID()
        let vm = PropertiesViewModel(
            wallpaperID: wallpaper,
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.slider(name: "speed", label: "Speed", value: 1.0, min: 0, max: 2, step: 0.1)],
            sink: nil,
            store: store
        )
        vm.set(.double(0.9), for: "speed")
        // Debounce is 120ms — wait 400ms to be safe.
        try await Task.sleep(nanoseconds: 400_000_000)
        let onDisk = store.read(
            wallpaperID: wallpaper,
            displayUUID: "A",
            arrangement: arrangement
        )
        XCTAssertEqual(onDisk["speed"], .double(0.9))
    }

    func test_button_control_default_is_string_value() {
        let vm = PropertiesViewModel(
            wallpaperID: UUID(),
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.button(name: "reset", label: "Reset", value: "reset")],
            sink: nil,
            store: store
        )
        XCTAssertEqual(vm.values["reset"], .string("reset"))
    }

    func test_label_control_default_is_string_value() {
        let vm = PropertiesViewModel(
            wallpaperID: UUID(),
            displayUUID: "A",
            arrangement: arrangement,
            controls: [.label(name: "info", value: "About this wallpaper")],
            sink: nil,
            store: store
        )
        XCTAssertEqual(vm.values["info"], .string("About this wallpaper"))
    }
}
