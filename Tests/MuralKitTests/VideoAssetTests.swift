import Foundation
@testable import Mural
import XCTest

final class VideoAssetTests: XCTestCase {
    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(
            bundle.url(forResource: "red-1s", withExtension: "mp4", subdirectory: "Fixtures"),
            "missing Tests/Fixtures/red-1s.mp4 — run the generator from the plan"
        )
    }

    func test_video_asset_accepts_mp4_extension() throws {
        let url = try fixtureURL()
        let asset = try VideoAsset(url: url)
        XCTAssertEqual(asset.url, url)
        XCTAssertEqual(asset.fileExtension, "mp4")
    }

    func test_supported_extensions_include_common_formats() {
        let supported = VideoAsset.supportedExtensions
        for ext in ["mp4", "mov", "m4v", "webm", "mkv"] {
            XCTAssertTrue(supported.contains(ext), "expected to support \(ext)")
        }
    }

    func test_unsupported_extension_throws() {
        let url = URL(fileURLWithPath: "/tmp/something.jpg")
        XCTAssertThrowsError(try VideoAsset(url: url)) { err in
            guard case let VideoAssetError.unsupportedExtension(ext) = err else {
                return XCTFail("expected unsupportedExtension; got \(err)")
            }
            XCTAssertEqual(ext, "jpg")
        }
    }

    func test_scale_mode_round_trips_through_codable() throws {
        for mode in ScaleMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let back = try JSONDecoder().decode(ScaleMode.self, from: data)
            XCTAssertEqual(mode, back)
        }
    }

    func test_scale_mode_videoGravity_mapping_is_total() {
        // Each ScaleMode must have a non-nil mapping to AVLayerVideoGravity.
        for mode in ScaleMode.allCases {
            _ = mode.videoGravity // just verify no crash / non-optional
        }
    }
}
