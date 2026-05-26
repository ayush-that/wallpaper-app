import Foundation
@testable import Mural
import XCTest

final class PkgWallpaperImporterTests: XCTestCase {
    private var libraryRoot: URL!

    override func setUpWithError() throws {
        libraryRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: libraryRoot)
    }

    private func samplePkg() throws -> URL {
        try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "sample", withExtension: "pkg", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/sample.pkg"
        )
    }

    func test_imports_video_project_with_metadata() throws {
        let importer = PkgWallpaperImporter(libraryRoot: libraryRoot)
        let wallpaper = try importer.importArchive(at: samplePkg())

        XCTAssertEqual(wallpaper.title, "Sample")
        XCTAssertEqual(wallpaper.type, .video)
        XCTAssertEqual(wallpaper.entryRelativePath, "clip.mp4")
        XCTAssertEqual(wallpaper.sourceImporter, .wallpaperEngine)

        let pkgDir = libraryRoot.appendingPathComponent(wallpaper.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("clip.mp4").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("project.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pkgDir.appendingPathComponent("wallpaper.json").path))
        // Thumbnail synthesis from a 64-byte all-0xAB "clip.mp4" will fail
        // silently — that's expected and not a test concern.
    }

    func test_unsupported_project_type_throws() throws {
        // Build a tiny .pkg whose project.json declares type=scene
        let sceneProject = #"{"type":"scene","file":"x"}"#.data(using: .utf8)!
        let badPkg = try makePkg(entries: [("project.json", sceneProject)])
        defer { try? FileManager.default.removeItem(at: badPkg) }

        let importer = PkgWallpaperImporter(libraryRoot: libraryRoot)
        XCTAssertThrowsError(try importer.importArchive(at: badPkg)) { error in
            guard case let PkgWallpaperImporterError.unsupportedProjectType(typeName) = error else {
                return XCTFail("expected .unsupportedProjectType, got \(error)")
            }
            XCTAssertEqual(typeName, "scene")
        }
    }

    func test_missing_project_json_throws() throws {
        let onlyClip = try makePkg(entries: [("clip.mp4", Data(repeating: 0x00, count: 4))])
        defer { try? FileManager.default.removeItem(at: onlyClip) }

        let importer = PkgWallpaperImporter(libraryRoot: libraryRoot)
        XCTAssertThrowsError(try importer.importArchive(at: onlyClip)) { error in
            guard case PkgWallpaperImporterError.missingProjectJson = error else {
                return XCTFail("expected .missingProjectJson, got \(error)")
            }
        }
    }

    /// Build a tiny in-process .pkg the same way make-pkg.swift does, so we
    /// can test edge cases without committing more fixtures.
    private func makePkg(entries: [(String, Data)]) throws -> URL {
        func u32(_ value: UInt32) -> Data {
            var le = value.littleEndian
            return Data(bytes: &le, count: 4)
        }
        var dataBlock = Data()
        var offsets: [(UInt32, UInt32)] = []
        for (_, payload) in entries {
            offsets.append((UInt32(dataBlock.count), UInt32(payload.count)))
            dataBlock.append(payload)
        }
        var header = Data()
        header.append(u32(UInt32(entries.count)))
        for (i, (name, _)) in entries.enumerated() {
            let nameBytes = name.data(using: .utf8)!
            header.append(u32(UInt32(nameBytes.count)))
            header.append(nameBytes)
            header.append(u32(offsets[i].0))
            header.append(u32(offsets[i].1))
        }
        let pkg = "PKGV0001".data(using: .ascii)! + header + dataBlock
        let url = libraryRoot.appendingPathComponent("\(UUID().uuidString).pkg")
        try pkg.write(to: url)
        return url
    }
}
