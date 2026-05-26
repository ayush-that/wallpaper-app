@testable import Mural
import XCTest

final class SettingsStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: SettingsStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        store = SettingsStore(defaults: defaults)
    }

    func test_get_returns_default_when_unset() {
        XCTAssertEqual(store.get(SettingsKey.launchAtLogin), false)
    }

    func test_set_then_get_roundtrips() {
        store.set(SettingsKey.launchAtLogin, true)
        XCTAssertEqual(store.get(SettingsKey.launchAtLogin), true)
    }

    func test_codable_value_roundtrips() {
        struct PauseRules: Codable, Equatable, Sendable {
            var onBattery: Bool
            var onFullscreen: Bool
        }
        let key = SettingsKey<PauseRules>(name: "pauseRules", default: .init(onBattery: true, onFullscreen: true))
        let custom = PauseRules(onBattery: false, onFullscreen: true)
        store.set(key, custom)
        XCTAssertEqual(store.get(key), custom)
    }
}
