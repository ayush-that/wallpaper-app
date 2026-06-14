import Foundation
@testable import Mural
import XCTest

final class PkgArchiveTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sample", withExtension: "pkg", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/sample.pkg - run Tests/FixtureSources/make-pkg.swift"
        )
    }

    func test_opens_archive_and_reports_version() throws {
        let archive = try PkgArchive(url: fixtureURL())
        XCTAssertEqual(archive.version, "PKGV0001")
    }

    func test_lists_both_entries() throws {
        let archive = try PkgArchive(url: fixtureURL())
        let names = archive.entries.map(\.name).sorted()
        XCTAssertEqual(names, ["clip.mp4", "project.json"])
    }

    func test_read_returns_project_json_payload() throws {
        let archive = try PkgArchive(url: fixtureURL())
        let data = try archive.read(name: "project.json")
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"title\":\"Sample\""))
        XCTAssertTrue(json.contains("\"file\":\"clip.mp4\""))
    }

    func test_read_returns_clip_mp4_payload_size() throws {
        let archive = try PkgArchive(url: fixtureURL())
        let data = try archive.read(name: "clip.mp4")
        XCTAssertEqual(data.count, 64)
        XCTAssertEqual(data.first, 0xAB)
        XCTAssertEqual(data.last, 0xAB)
    }

    func test_read_unknown_entry_throws() throws {
        let archive = try PkgArchive(url: fixtureURL())
        XCTAssertThrowsError(try archive.read(name: "does-not-exist")) { error in
            guard case let PkgArchiveError.missingEntry(name) = error else {
                return XCTFail("expected .missingEntry, got \(error)")
            }
            XCTAssertEqual(name, "does-not-exist")
        }
    }

    func test_extract_all_writes_every_entry() throws {
        let archive = try PkgArchive(url: fixtureURL())
        let outDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: outDir) }

        try archive.extractAll(to: outDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outDir.appendingPathComponent("project.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outDir.appendingPathComponent("clip.mp4").path))
    }

    func test_bad_magic_throws() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".pkg")
        defer { try? FileManager.default.removeItem(at: tmp) }
        // 8 magic bytes ("NOTAPKG!") + 4 bytes for entry_count so we hit the magic check first.
        try Data("NOTAPKG!\u{0}\u{0}\u{0}\u{0}".utf8).write(to: tmp)
        XCTAssertThrowsError(try PkgArchive(url: tmp)) { error in
            guard case PkgArchiveError.badMagic = error else {
                return XCTFail("expected .badMagic, got \(error)")
            }
        }
    }

    func test_truncated_file_throws() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".pkg")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data("PKGV0001".utf8).write(to: tmp)
        XCTAssertThrowsError(try PkgArchive(url: tmp)) { error in
            guard case PkgArchiveError.truncated = error else {
                return XCTFail("expected .truncated, got \(error)")
            }
        }
    }
}
