import Foundation

/// Verbs that the in-app control socket accepts from the muralctl CLI.
/// Encoded as JSON over a Unix domain socket. The schema is part of the
/// public command-line contract — once shipped, new cases must be additive
/// (decoders need to ignore unknown verbs gracefully).
public enum Command: Codable, Equatable, Sendable {
    case set(wallpaperID: UUID, displayUUID: String?)
    case close(displayUUID: String?)
    case pause
    case resume
    case setProperty(wallpaperID: UUID, displayUUID: String?, name: String, value: WebBridgePropertyValue)
    case importFile(path: String)
    case status

    private enum Verb: String, Codable {
        case set, close, pause, resume, setProperty, importFile, status
    }

    private enum Keys: String, CodingKey {
        case verb, wallpaperID, displayUUID, path, name, value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let verb = try c.decode(Verb.self, forKey: .verb)
        switch verb {
        case .set:
            self = try .set(
                wallpaperID: c.decode(UUID.self, forKey: .wallpaperID),
                displayUUID: c.decodeIfPresent(String.self, forKey: .displayUUID)
            )
        case .close:
            self = try .close(displayUUID: c.decodeIfPresent(String.self, forKey: .displayUUID))
        case .pause:
            self = .pause
        case .resume:
            self = .resume
        case .setProperty:
            self = try .setProperty(
                wallpaperID: c.decode(UUID.self, forKey: .wallpaperID),
                displayUUID: c.decodeIfPresent(String.self, forKey: .displayUUID),
                name: c.decode(String.self, forKey: .name),
                value: c.decode(WebBridgePropertyValue.self, forKey: .value)
            )
        case .importFile:
            self = try .importFile(path: c.decode(String.self, forKey: .path))
        case .status:
            self = .status
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .set(wallpaperID, displayUUID):
            try c.encode(Verb.set, forKey: .verb)
            try c.encode(wallpaperID, forKey: .wallpaperID)
            try c.encodeIfPresent(displayUUID, forKey: .displayUUID)
        case let .close(displayUUID):
            try c.encode(Verb.close, forKey: .verb)
            try c.encodeIfPresent(displayUUID, forKey: .displayUUID)
        case .pause:
            try c.encode(Verb.pause, forKey: .verb)
        case .resume:
            try c.encode(Verb.resume, forKey: .verb)
        case let .setProperty(wallpaperID, displayUUID, name, value):
            try c.encode(Verb.setProperty, forKey: .verb)
            try c.encode(wallpaperID, forKey: .wallpaperID)
            try c.encodeIfPresent(displayUUID, forKey: .displayUUID)
            try c.encode(name, forKey: .name)
            try c.encode(value, forKey: .value)
        case let .importFile(path):
            try c.encode(Verb.importFile, forKey: .verb)
            try c.encode(path, forKey: .path)
        case .status:
            try c.encode(Verb.status, forKey: .verb)
        }
    }
}

public struct CommandResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let message: String?
    public let statusJSON: String?

    public init(ok: Bool, message: String? = nil, statusJSON: String? = nil) {
        self.ok = ok
        self.message = message
        self.statusJSON = statusJSON
    }

    public static func failure(_ message: String) -> CommandResponse {
        CommandResponse(ok: false, message: message, statusJSON: nil)
    }

    public static func success(_ message: String? = nil, statusJSON: String? = nil) -> CommandResponse {
        CommandResponse(ok: true, message: message, statusJSON: statusJSON)
    }
}
