import Foundation
import Network

public enum ClientError: Error, LocalizedError {
    case connectionFailed(Error)
    case noResponse
    case decode(Error)

    public var errorDescription: String? {
        switch self {
        case let .connectionFailed(underlying):
            "could not reach Mural: \(underlying.localizedDescription) (is the app running?)"
        case .noResponse:
            "Mural closed the connection without replying"
        case let .decode(underlying):
            "could not decode Mural's response: \(underlying.localizedDescription)"
        }
    }
}

/// One-shot Unix-domain-socket client for the `Command` / `CommandResponse`
/// protocol exposed by `ControlSocket`. Lives in `MuralKit` so both the app's
/// test bundle and the `muralctl` CLI target can build against it.
public struct Client {
    /// Default Unix-socket location. Kept in sync with `ControlSocket.defaultPath`
    /// but defined here so the `muralctl` target can use it without pulling in
    /// the main-actor server.
    public static let defaultSocketPath = "\(NSHomeDirectory())/Library/Application Support/Mural/control.sock"

    public var socketPath: String

    public init(socketPath: String = Client.defaultSocketPath) {
        self.socketPath = socketPath
    }

    public func send(_ command: Command) async throws -> CommandResponse {
        let payload = try JSONEncoder().encode(command)
        return try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<CommandResponse, Error>
        ) in
            let endpoint = NWEndpoint.unix(path: socketPath)
            let connection = NWConnection(to: endpoint, using: .tcp)
            let box = ClientResumeBox(continuation)
            let buffer = ClientDataBox()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error {
                            box.resume(throwing: ClientError.connectionFailed(error))
                            connection.cancel()
                        } else {
                            readLoop(connection: connection, buffer: buffer, box: box)
                        }
                    })
                case let .failed(error):
                    box.resume(throwing: ClientError.connectionFailed(error))
                    connection.cancel()
                case let .waiting(error):
                    // Unix sockets never recover from `.waiting` (the file just
                    // isn't there yet) — treat it as immediate failure so the
                    // CLI doesn't hang when Mural isn't running.
                    box.resume(throwing: ClientError.connectionFailed(error))
                    connection.cancel()
                case .cancelled:
                    if let data = buffer.snapshot, !data.isEmpty {
                        decodeAndResume(data: data, box: box)
                    } else if !box.didResume {
                        box.resume(throwing: ClientError.noResponse)
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

private func readLoop(connection: NWConnection, buffer: ClientDataBox, box: ClientResumeBox) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
        if let error {
            box.resume(throwing: ClientError.connectionFailed(error))
            connection.cancel()
            return
        }
        if let data { buffer.append(data) }
        if isComplete {
            if let snapshot = buffer.snapshot, !snapshot.isEmpty {
                decodeAndResume(data: snapshot, box: box)
            } else if !box.didResume {
                box.resume(throwing: ClientError.noResponse)
            }
            connection.cancel()
        } else {
            readLoop(connection: connection, buffer: buffer, box: box)
        }
    }
}

private func decodeAndResume(data: Data, box: ClientResumeBox) {
    do {
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        box.resume(returning: response)
    } catch {
        box.resume(throwing: ClientError.decode(error))
    }
}

/// Ensures a continuation is resumed exactly once even if multiple
/// NWConnection callbacks race (e.g. `.cancelled` after `.failed`).
final class ClientResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<CommandResponse, Error>

    init(_ continuation: CheckedContinuation<CommandResponse, Error>) {
        self.continuation = continuation
    }

    var didResume: Bool {
        lock.lock()
        defer { lock.unlock() }
        return resumed
    }

    func resume(returning value: CommandResponse) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        lock.unlock()
        continuation.resume(throwing: error)
    }
}

/// Append-only byte buffer protected by a lock so the Network.framework
/// callback queue can write to it from any thread.
final class ClientDataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
    }

    var snapshot: Data? {
        lock.lock()
        defer { lock.unlock() }
        return data.isEmpty ? nil : data
    }
}
