import Foundation
@testable import Mural
import Network
import XCTest

@MainActor
final class ControlSocketTests: XCTestCase {
    private var tmpPath: String!

    override func setUp() async throws {
        tmpPath = NSTemporaryDirectory() + "mural-\(UUID().uuidString).sock"
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    func test_round_trip_one_command() async throws {
        let socket = ControlSocket(path: tmpPath) { command in
            switch command {
            case .pause:
                .success("paused")
            default:
                .failure("unexpected")
            }
        }
        try socket.start()
        defer { socket.stop() }

        let response = try await send(.pause, to: tmpPath)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.message, "paused")
    }

    func test_unknown_command_decoded_returns_failure() async throws {
        let socket = ControlSocket(path: tmpPath) { _ in .success("nope") }
        try socket.start()
        defer { socket.stop() }

        // Send malformed JSON manually.
        let payload = Data("{\"verb\":\"definitely-not-a-thing\"}".utf8)
        let response = try await sendRaw(payload, to: tmpPath)
        XCTAssertFalse(response.ok)
        XCTAssertNotNil(response.message)
    }

    func test_start_removes_stale_socket_file() throws {
        // Pre-create a stale file at the socket path.
        try Data("stale".utf8).write(to: URL(fileURLWithPath: tmpPath))
        let socket = ControlSocket(path: tmpPath) { _ in .success() }
        try socket.start()
        socket.stop()
    }

    // MARK: - Test helpers

    private func send(_ command: Command, to path: String) async throws -> CommandResponse {
        let payload = try JSONEncoder().encode(command)
        return try await sendRaw(payload, to: path)
    }

    private func sendRaw(_ payload: Data, to path: String) async throws -> CommandResponse {
        let box = ResumeBox()
        let buffer = DataBox()
        return try await withCheckedThrowingContinuation { continuation in
            let endpoint = NWEndpoint.unix(path: path)
            let connection = NWConnection(to: endpoint, using: .tcp)
            @Sendable func scheduleReceive() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, _ in
                    if let data { buffer.append(data) }
                    if isComplete {
                        let bytes = buffer.value
                        if let response = try? JSONDecoder().decode(CommandResponse.self, from: bytes) {
                            box.resume { continuation.resume(returning: response) }
                        } else {
                            box.resume {
                                continuation
                                    .resume(throwing: NSError(domain: "ControlSocketTests", code: -1))
                            }
                        }
                        connection.cancel()
                    } else {
                        scheduleReceive()
                    }
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { _ in
                        scheduleReceive()
                    })
                case let .failed(error):
                    box.resume { continuation.resume(throwing: error) }
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: .main)
        }
    }
}

/// Ensures a continuation is resumed at most once even if multiple
/// state-update callbacks fire (e.g. ready -> failed on broken pipe).
private final class ResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func resume(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        block()
    }
}

/// Mutable byte buffer that is safe to share across the Network.framework
/// callback queue (everything runs on `.main` here, so the lock is mostly
/// belt-and-braces).
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        bytes.append(chunk)
    }
}
