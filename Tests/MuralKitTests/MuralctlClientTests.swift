import Foundation
@testable import Mural
import XCTest

@MainActor
final class MuralctlClientTests: XCTestCase {
    private var socketPath: String!
    private var socket: ControlSocket?

    override func setUp() async throws {
        socketPath = NSTemporaryDirectory() + "muralctl-test-\(UUID().uuidString).sock"
    }

    override func tearDown() async throws {
        socket?.stop()
        socket = nil
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    func test_client_round_trips_pause() async throws {
        socket = ControlSocket(path: socketPath) { command in
            switch command {
            case .pause:
                .success("paused")
            default:
                .failure("unexpected")
            }
        }
        try socket?.start()

        let client = Client(socketPath: socketPath)
        let response = try await client.send(.pause)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.message, "paused")
    }

    func test_client_round_trips_status_with_payload() async throws {
        socket = ControlSocket(path: socketPath) { command in
            switch command {
            case .status:
                .success(statusJSON: "{\"displays\":[]}")
            default:
                .failure("unexpected")
            }
        }
        try socket?.start()

        let client = Client(socketPath: socketPath)
        let response = try await client.send(.status)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.statusJSON, "{\"displays\":[]}")
    }

    func test_client_connection_failure_throws_connectionFailed() async throws {
        let bogusPath = "/tmp/definitely-not-a-real-mural-socket-\(UUID().uuidString).sock"
        let client = Client(socketPath: bogusPath)
        do {
            _ = try await client.send(.pause)
            XCTFail("expected connectionFailed")
        } catch let error as ClientError {
            guard case .connectionFailed = error else {
                XCTFail("got \(error)")
                return
            }
        }
    }
}
