import Foundation

public final class SettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func get<V: Codable & Sendable>(_ key: SettingsKey<V>) -> V {
        guard let data = defaults.data(forKey: key.name),
              let value = try? decoder.decode(V.self, from: data) else {
            return key.default
        }
        return value
    }

    public func set<V: Codable & Sendable>(_ key: SettingsKey<V>, _ value: V) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.name)
    }
}
