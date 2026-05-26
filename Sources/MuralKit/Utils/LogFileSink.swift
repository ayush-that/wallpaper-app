import Foundation
import os

public final class LogFileSink {
    private let url: URL
    private let maxBytes: Int
    /// Lock-protected state. OSAllocatedUnfairLock<State> is Sendable
    /// and gives us safe access to the FileHandle from any thread without
    /// making LogFileSink itself Sendable.
    private let state: OSAllocatedUnfairLock<State>

    private struct State {
        var handle: FileHandle
    }

    public init(url: URL, maxBytes: Int = 5_000_000) throws {
        self.url = url
        self.maxBytes = maxBytes
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let h = try FileHandle(forWritingTo: url)
        try h.seekToEnd()
        state = OSAllocatedUnfairLock(initialState: State(handle: h))
    }

    public func write(_ line: String) {
        let stamped = "[\(Date().formatted(.iso8601))] \(line)\n"
        guard let data = stamped.data(using: .utf8) else { return }
        let url = url
        let maxBytes = maxBytes
        state.withLock { state in
            try? state.handle.write(contentsOf: data)
            Self.rotateIfNeededLocked(state: &state, url: url, maxBytes: maxBytes)
        }
    }

    public func flush() {
        state.withLock { state in
            try? state.handle.synchronize()
        }
    }

    private static func rotateIfNeededLocked(state: inout State, url: URL, maxBytes: Int) {
        guard let size = try? state.handle.offset(), size >= maxBytes else { return }
        try? state.handle.close()
        let rotated = url.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: url, to: rotated)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        if let h = try? FileHandle(forWritingTo: url) { state.handle = h }
    }
}
