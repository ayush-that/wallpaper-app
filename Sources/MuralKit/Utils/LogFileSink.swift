import Foundation

public final class LogFileSink: @unchecked Sendable {
    private let url: URL
    private let maxBytes: Int
    private let queue = DispatchQueue(label: "mural.log.sink")
    private var handle: FileHandle

    public init(url: URL, maxBytes: Int = 5_000_000) throws {
        self.url = url
        self.maxBytes = maxBytes
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    public func write(_ line: String) {
        queue.async { [self] in
            let stamped = "[\(Self.iso8601())] \(line)\n"
            if let data = stamped.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
            rotateIfNeeded()
        }
    }

    public func flush() { queue.sync { try? handle.synchronize() } }

    private func rotateIfNeeded() {
        guard let size = try? handle.offset(), size >= maxBytes else { return }
        try? handle.close()
        let rotated = url.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: url, to: rotated)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        if let h = try? FileHandle(forWritingTo: url) { handle = h }
    }

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoLock = NSLock()

    private static func iso8601() -> String {
        isoLock.lock()
        defer { isoLock.unlock() }
        return iso.string(from: Date())
    }
}
