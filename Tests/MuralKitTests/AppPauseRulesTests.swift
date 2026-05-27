@testable import Mural
import XCTest

final class AppPauseRulesTests: XCTestCase {
    func test_match_returns_rule_for_known_bundle_id() {
        let rules = AppPauseRules(rules: [
            AppPauseRule(bundleID: "com.foo.Bar"),
            AppPauseRule(bundleID: "com.baz.Qux")
        ])
        let match = rules.match(bundleID: "com.foo.Bar")
        XCTAssertEqual(match?.bundleID, "com.foo.Bar")
    }

    func test_match_returns_nil_for_unknown_bundle_id() {
        let rules = AppPauseRules(rules: [
            AppPauseRule(bundleID: "com.foo.Bar")
        ])
        XCTAssertNil(rules.match(bundleID: "com.other.App"))
    }

    func test_match_is_nil_safe() {
        let rules = AppPauseRules(rules: [
            AppPauseRule(bundleID: "com.foo.Bar")
        ])
        XCTAssertNil(rules.match(bundleID: nil))
    }

    func test_empty_rules_match_returns_nil() {
        let rules = AppPauseRules()
        XCTAssertNil(rules.match(bundleID: "anything"))
    }

    func test_default_settings_key_includes_known_meeting_apps() {
        let defaults = SettingsKey.appPauseRules.default
        let ids = defaults.rules.map(\.bundleID)
        XCTAssertTrue(ids.contains("us.zoom.xos"))
        XCTAssertTrue(ids.contains("com.apple.iWork.Keynote"))
    }

    func test_rules_codable_round_trip() throws {
        let original = AppPauseRules(rules: [
            AppPauseRule(bundleID: "com.foo.Bar", pauseAll: true),
            AppPauseRule(bundleID: "com.baz.Qux", pauseAll: false)
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppPauseRules.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_settings_store_roundtrips_app_pause_rules() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let store = SettingsStore(defaults: defaults)
        let rules = AppPauseRules(rules: [AppPauseRule(bundleID: "com.test.App")])
        store.set(.appPauseRules, rules)
        let loaded = store.get(.appPauseRules)
        XCTAssertEqual(loaded, rules)
    }
}
