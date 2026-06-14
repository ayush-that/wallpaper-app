import Foundation
import Network
import OSLog

/// In-process Unix domain socket that the `muralctl` CLI talks to. One request,
/// one response, close. Restarts cleanly across launches (the socket file is
/// removed at `start()` time).
@MainActor
public final class ControlSocket {
    public typealias Handler = @Sendable (Command) async -> CommandResponse

    public static let defaultPath = Client.defaultSocketPath

    private let log = Log.logger("ControlSocket")
    private let path: String
    private let handler: Handler
    private var listener: NWListener?

    public init(path: String = ControlSocket.defaultPath, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    public func start() throws {
        try? FileManager.default.removeItem(atPath: path)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let endpoint = NWEndpoint.unix(path: path)
        // NOTE: `acceptLocalOnly = true` silently blocks `newConnectionHandler`
        // from firing for `.unix` endpoints; the listener reaches `.ready` but
        // never accepts. The unix socket file itself (created at a per-user
        // path) is the access boundary, not this flag.
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = endpoint

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handle(connection)
            }
        }
        listener.start(queue: .main)
        self.listener = listener
        let listeningPath = path
        log.info("ControlSocket listening at \(listeningPath, privacy: .public)")
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        try? FileManager.default.removeItem(atPath: path)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection
            .receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                Task { @MainActor [weak self] in
                    guard let self else {
                        connection.cancel()
                        return
                    }
                    if let error {
                        log
                            .error("ControlSocket receive error: \(error.localizedDescription, privacy: .public)")
                        connection.cancel()
                        return
                    }
                    var buffer = accumulated
                    if let data { buffer.append(data) }
                    if !isComplete, !Self.looksLikeCompleteJSON(buffer) {
                        receive(connection, accumulated: buffer)
                        return
                    }
                    let handler = handler
                    Task {
                        let response: CommandResponse
                        do {
                            let command = try JSONDecoder().decode(Command.self, from: buffer)
                            response = await handler(command)
                        } catch {
                            response = .failure("decode: \(error.localizedDescription)")
                        }
                        let payload = (try? JSONEncoder().encode(response)) ?? Data("{\"ok\":false}".utf8)
                        connection.send(content: payload, completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    }
                }
            }
    }

    /// Cheap heuristic: if the buffer's last non-whitespace byte is `}`, treat
    /// it as a complete JSON document. The CLI sends one-shot payloads, so this
    /// is enough to avoid waiting for an explicit EOF on `isComplete`.
    private static func looksLikeCompleteJSON(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.hasSuffix("}")
    }
}
