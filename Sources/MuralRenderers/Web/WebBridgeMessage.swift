import Foundation

public enum WebBridgeMessage: Codable, Equatable, Sendable {
    case propertyChanged(name: String, value: WebBridgePropertyValue)
    case console(level: String, message: String)
    case ready
    case unknown(type: String)

    private enum Keys: String, CodingKey {
        case type, name, value, level, message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "propertyChanged":
            self = try .propertyChanged(
                name: container.decode(String.self, forKey: .name),
                value: container.decode(WebBridgePropertyValue.self, forKey: .value)
            )
        case "console":
            self = try .console(
                level: container.decode(String.self, forKey: .level),
                message: container.decode(String.self, forKey: .message)
            )
        case "ready":
            self = .ready
        default:
            self = .unknown(type: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .propertyChanged(name, value):
            try container.encode("propertyChanged", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(value, forKey: .value)
        case let .console(level, message):
            try container.encode("console", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(message, forKey: .message)
        case .ready:
            try container.encode("ready", forKey: .type)
        case let .unknown(type):
            try container.encode(type, forKey: .type)
        }
    }
}
