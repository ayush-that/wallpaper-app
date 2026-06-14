import Combine
import Foundation
import OSLog

@MainActor
public final class PropertiesViewModel: ObservableObject {
    private let log = Log.logger("PropertiesVM")
    public let controls: [PropertyControl]
    public let wallpaperID: UUID
    public let displayUUID: String
    public let arrangement: DisplayArrangementHash

    private let store: PropertyOverrideStore
    private weak var sink: PropertiesSink?
    private var debounceTimer: DispatchSourceTimer?

    @Published public private(set) var values: [String: WebBridgePropertyValue] = [:]

    public init(
        wallpaperID: UUID,
        displayUUID: String,
        arrangement: DisplayArrangementHash,
        controls: [PropertyControl],
        sink: PropertiesSink?,
        store: PropertyOverrideStore = PropertyOverrideStore()
    ) {
        self.wallpaperID = wallpaperID
        self.displayUUID = displayUUID
        self.arrangement = arrangement
        self.controls = controls
        self.sink = sink
        self.store = store

        // Layer persisted overrides on top of control defaults.
        var initial = store.read(
            wallpaperID: wallpaperID,
            displayUUID: displayUUID,
            arrangement: arrangement
        )
        for control in controls where initial[control.name] == nil {
            initial[control.name] = Self.defaultValue(for: control)
        }
        values = initial

        // Push initial values into the renderer so it reflects the persisted state.
        for (name, value) in initial {
            sink?.apply(propertyName: name, value: value)
        }
    }

    /// Update one property: in-memory immediately, sink immediately, disk debounced.
    public func set(_ value: WebBridgePropertyValue, for name: String) {
        values[name] = value
        sink?.apply(propertyName: name, value: value)
        scheduleDebouncedWrite()
    }

    /// Convenience for SwiftUI bindings - read with a fallback when the key is
    /// somehow missing (shouldn't happen post-init but defensive).
    public func value(for name: String, fallback: WebBridgePropertyValue) -> WebBridgePropertyValue {
        values[name] ?? fallback
    }

    private func scheduleDebouncedWrite() {
        debounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .milliseconds(120))
        timer.setEventHandler { [weak self] in
            self?.flushToDisk()
        }
        timer.resume()
        debounceTimer = timer
    }

    /// Write current values to disk. Public for tests; usually called via the
    /// debounce timer above.
    public func flushToDisk() {
        do {
            try store.write(
                values,
                wallpaperID: wallpaperID,
                displayUUID: displayUUID,
                arrangement: arrangement
            )
        } catch {
            log.error("Override write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func defaultValue(for control: PropertyControl) -> WebBridgePropertyValue {
        switch control {
        case let .slider(_, _, value, _, _, _): .double(value)
        case let .color(_, _, value): .color(value)
        case let .checkbox(_, _, value): .bool(value)
        case let .dropdown(_, _, _, value): .int(value)
        case let .folderDropdown(_, _, _, _, value): .string(value)
        case let .textbox(_, _, value): .string(value)
        case let .button(_, _, value): .string(value)
        case let .label(_, value): .string(value)
        }
    }
}
