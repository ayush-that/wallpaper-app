import ArgumentParser
import Foundation

struct SetCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set a wallpaper as the active wallpaper."
    )
    @Argument(help: "Wallpaper UUID.") var wallpaperID: String
    @Option(name: .shortAndLong, help: "Apply to one display only (UUID).") var display: String?

    func run() async throws {
        guard let uuid = UUID(uuidString: wallpaperID) else {
            FileHandle.standardError.write(Data("muralctl: invalid UUID: \(wallpaperID)\n".utf8))
            throw ExitCode.failure
        }
        try await sendOrExit(.set(wallpaperID: uuid, displayUUID: display))
    }
}

struct CloseCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Stop the current wallpaper."
    )
    @Option(name: .shortAndLong, help: "Only close on this display (UUID).") var display: String?

    func run() async throws {
        try await sendOrExit(.close(displayUUID: display))
    }
}

struct PauseCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pause",
        abstract: "Pause all wallpapers."
    )

    func run() async throws {
        try await sendOrExit(.pause)
    }
}

struct ResumeCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resume",
        abstract: "Resume all wallpapers."
    )

    func run() async throws {
        try await sendOrExit(.resume)
    }
}

struct StatusCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Print current ActiveStatus JSON."
    )

    func run() async throws {
        let response = try await Client().send(.status)
        if let statusJSON = response.statusJSON {
            print(statusJSON)
        } else if let message = response.message {
            print(message)
        }
        if !response.ok { throw ExitCode.failure }
    }
}

struct SetPropCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setprop",
        abstract: "Set a property on a wallpaper."
    )
    @Argument(help: "Wallpaper UUID.") var wallpaperID: String
    @Argument(help: "Property name (key).") var propertyName: String
    @Argument(help: """
    Value. Bare numbers decode as Double; "true"/"false" as Bool; \
    #RRGGBB as Color; anything else as String.
    """)
    var rawValue: String
    @Option(name: .shortAndLong, help: "Apply to one display only (UUID).") var display: String?

    func run() async throws {
        guard let uuid = UUID(uuidString: wallpaperID) else {
            FileHandle.standardError.write(Data("muralctl: invalid UUID: \(wallpaperID)\n".utf8))
            throw ExitCode.failure
        }
        let value = parseValue(rawValue)
        try await sendOrExit(.setProperty(
            wallpaperID: uuid,
            displayUUID: display,
            name: propertyName,
            value: value
        ))
    }

    private func parseValue(_ raw: String) -> WebBridgePropertyValue {
        if let bool = Bool(raw) { return .bool(bool) }
        if raw.hasPrefix("#") { return .color(raw) }
        if let double = Double(raw) { return .double(double) }
        return .string(raw)
    }
}

struct ImportCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Import a file into the library."
    )
    @Argument(help: "Path to a video, image, .zip, or .pkg.") var path: String

    func run() async throws {
        let absolute = (path as NSString).expandingTildeInPath
        try await sendOrExit(.importFile(path: absolute))
    }
}

/// Shared helper: send a command, print its message/statusJSON, exit non-zero on failure.
func sendOrExit(_ command: Command) async throws {
    let response: CommandResponse
    do {
        response = try await Client().send(command)
    } catch {
        FileHandle.standardError.write(Data("muralctl: \(error.localizedDescription)\n".utf8))
        throw ExitCode.failure
    }
    if let message = response.message { print(message) }
    if let statusJSON = response.statusJSON { print(statusJSON) }
    if !response.ok { throw ExitCode.failure }
}
