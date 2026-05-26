@testable import Mural
import XCTest

final class LogFileSinkTests: XCTestCase {
    func test_sink_writes_lines_to_disk() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".log")
        let sink = try LogFileSink(url: tmp)
        sink.write("hello")
        sink.write("world")
        sink.flush()
        let contents = try String(contentsOf: tmp, encoding: .utf8)
        XCTAssertTrue(contents.contains("hello"))
        XCTAssertTrue(contents.contains("world"))
    }

    func test_sink_rotates_when_over_threshold() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".log")
        let sink = try LogFileSink(url: tmp, maxBytes: 1024)
        for _ in 0 ..< 200 {
            sink.write(String(repeating: "x", count: 32))
        }
        sink.flush()
        let rotated = tmp.deletingPathExtension().appendingPathExtension("1.log")
        XCTAssertTrue(FileManager.default.fileExists(atPath: rotated.path))
    }
}
