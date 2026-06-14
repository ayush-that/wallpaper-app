import Foundation
@testable import Mural
import XCTest

final class WallpaperCodecTests: XCTestCase {
    func test_roundtrips_through_json_with_all_fields_set() throws {
        let id = try XCTUnwrap(UUID(uuidString: "DEADBEEF-DEAD-DEAD-DEAD-DEADDEADBEEF"))
        let original = Wallpaper(
            id: id,
            title: "Rain",
            author: "Anon",
            type: .video,
            entryRelativePath: "asset.mp4",
            thumbnailRelativePath: "thumbnail.png",
            previewRelativePath: "preview.gif",
            tags: ["nature", "calm"],
            license: "CC-BY-4.0",
            sourceImporter: .native,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Wallpaper.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_roundtrips_with_minimal_fields() throws {
        let original = Wallpaper(title: "Minimal", type: .image, entryRelativePath: "frame.png")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Wallpaper.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.type, decoded.type)
        XCTAssertEqual(original.entryRelativePath, decoded.entryRelativePath)
        XCTAssertNil(decoded.previewRelativePath)
        XCTAssertEqual(decoded.tags, [])
    }

    func test_decoding_unknown_type_throws() throws {
        let json = #"{"id":"DEADBEEF-DEAD-DEAD-DEAD-DEADDEADBEEF","title":"x","author":"","#
            + #""type":"hologram","entryRelativePath":"a","thumbnailRelativePath":"t.png","#
            + #""tags":[],"sourceImporter":"native","createdAt":"2024-01-01T00:00:00Z"}"#
        let bad = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(Wallpaper.self, from: bad))
    }

    func test_wallpaper_type_raw_values_are_stable() {
        // Lock these. Every later phase and on-disk format relies on these strings.
        XCTAssertEqual(WallpaperType.image.rawValue, "image")
        XCTAssertEqual(WallpaperType.gif.rawValue, "gif")
        XCTAssertEqual(WallpaperType.video.rawValue, "video")
        XCTAssertEqual(WallpaperType.web.rawValue, "web")
        XCTAssertEqual(WallpaperType.shader.rawValue, "shader")
        XCTAssertEqual(WallpaperType.urlPage.rawValue, "url")
        XCTAssertEqual(WallpaperType.appWindow.rawValue, "app")
    }
}
