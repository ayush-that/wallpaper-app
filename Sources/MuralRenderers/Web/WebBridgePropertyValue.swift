import Foundation

public enum WebBridgePropertyValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case color(String) // hex e.g. "#ff8800"; convenience tag, not a separate JSON shape

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) {
            self = .bool(v); return
        }
        if let v = try? container.decode(Int.self) {
            self = .int(v); return
        }
        if let v = try? container.decode(Double.self) {
            self = .double(v); return
        }
        if let v = try? container.decode(String.self) {
            self = v.hasPrefix("#") ? .color(v) : .string(v)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown WebBridgePropertyValue shape"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(v): try container.encode(v)
        case let .int(v): try container.encode(v)
        case let .double(v): try container.encode(v)
        case let .string(v): try container.encode(v)
        case let .color(v): try container.encode(v)
        }
    }
}
