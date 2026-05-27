import Foundation
@testable import Mural
import XCTest

@MainActor
final class ObservableSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() async throws {
        let suite = "test.observable.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        store = SettingsStore(defaults: defaults)
    }

    func test_seeds_from_store_defaults() {
        let settings = ObservableSettings(store: store, propagateToLoginItem: false)
        XCTAssertEqual(settings.launchAtLogin, false)
        XCTAssertEqual(settings.pauseOnFullscreen, true)
        XCTAssertEqual(settings.pauseOnBattery, true)
        XCTAssertEqual(settings.pauseOnLowPowerMode, true)
        XCTAssertEqual(settings.muteWallpaperAudio, true)
    }

    func test_set_persists_through_store() {
        let settings = ObservableSettings(store: store, propagateToLoginItem: false)
        settings.pauseOnBattery = false
        XCTAssertEqual(store.get(.pauseOnBattery), false)
    }

    func test_new_observable_picks_up_previously_persisted_value() {
        store.set(.muteWallpaperAudio, false)
        let settings = ObservableSettings(store: store, propagateToLoginItem: false)
        XCTAssertEqual(settings.muteWallpaperAudio, false)
    }

    func test_published_change_persists_each_field_independently() {
        let settings = ObservableSettings(store: store, propagateToLoginItem: false)
        settings.launchAtLogin = true
        settings.pauseOnFullscreen = false
        settings.pauseOnBattery = false
        settings.pauseOnLowPowerMode = false
        settings.muteWallpaperAudio = false

        XCTAssertEqual(store.get(.launchAtLogin), true)
        XCTAssertEqual(store.get(.pauseOnFullscreen), false)
        XCTAssertEqual(store.get(.pauseOnBattery), false)
        XCTAssertEqual(store.get(.pauseOnLowPowerMode), false)
        XCTAssertEqual(store.get(.muteWallpaperAudio), false)
    }
}
