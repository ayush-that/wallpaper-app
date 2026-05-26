import Foundation
import OSLog

public enum PkgArchiveError: Error, Equatable {
    case badMagic
    case truncated
    case unsupportedVersion(String)
    case missingEntry(String)
}

public struct PkgEntry: Equatable, Sendable {
    public let name: String
    public let offset: UInt32
    public let length: UInt32
}

/// Reader for the `.pkg` binary archive format (magic PKGV0001..PKGV0009).
/// Length-prefixed entry table followed by a concatenated data block; no
/// compression in scope. Memory-maps the file for cheap reads.
public final class PkgArchive {
    private let log = Log.logger("PkgArchive")
    public let url: URL
    public let version: String // "PKGV0001" .. "PKGV0009"
    public let entries: [PkgEntry]
    private let dataBlockOffset: UInt64
    private let fileData: Data

    public init(url: URL) throws {
        self.url = url
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 12 else { throw PkgArchiveError.truncated } // 8 magic + 4 count
        let magic = String(data: data.prefix(8), encoding: .ascii) ?? ""
        guard magic.hasPrefix("PKGV") else { throw PkgArchiveError.badMagic }
        let versionDigits = String(magic.dropFirst(4))
        guard let versionNumber = Int(versionDigits), (1 ... 9).contains(versionNumber) else {
            throw PkgArchiveError.unsupportedVersion(magic)
        }
        version = magic
        fileData = data

        var cursor = 8
        guard let entryCount: UInt32 = Self.readU32(data, at: cursor) else {
            throw PkgArchiveError.truncated
        }
        cursor += 4

        var parsed: [PkgEntry] = []
        parsed.reserveCapacity(Int(entryCount))
        for _ in 0 ..< entryCount {
            guard let nameLen: UInt32 = Self.readU32(data, at: cursor) else {
                throw PkgArchiveError.truncated
            }
            cursor += 4
            let nameEnd = cursor + Int(nameLen)
            guard nameEnd <= data.count else { throw PkgArchiveError.truncated }
            let name = String(data: data.subdata(in: cursor ..< nameEnd), encoding: .utf8) ?? ""
            cursor = nameEnd
            guard let offset: UInt32 = Self.readU32(data, at: cursor) else {
                throw PkgArchiveError.truncated
            }
            cursor += 4
            guard let length: UInt32 = Self.readU32(data, at: cursor) else {
                throw PkgArchiveError.truncated
            }
            cursor += 4
            parsed.append(PkgEntry(name: name, offset: offset, length: length))
        }
        entries = parsed
        dataBlockOffset = UInt64(cursor)
    }

    public func read(name: String) throws -> Data {
        guard let entry = entries.first(where: { $0.name == name }) else {
            throw PkgArchiveError.missingEntry(name)
        }
        let start = Int(dataBlockOffset) + Int(entry.offset)
        let end = start + Int(entry.length)
        guard end <= fileData.count else { throw PkgArchiveError.truncated }
        return fileData.subdata(in: start ..< end)
    }

    public func extractAll(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for entry in entries {
            let dest = directory.appendingPathComponent(entry.name)
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try read(name: entry.name).write(to: dest)
        }
    }

    private static func readU32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { dst in
            data.copyBytes(to: dst, from: offset ..< offset + 4)
        }
        return UInt32(littleEndian: value)
    }
}
