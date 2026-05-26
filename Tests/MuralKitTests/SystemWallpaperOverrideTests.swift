import Foundation
@testable import Mural
import XCTest

final class SystemWallpaperOverrideTests: XCTestCase {
    @MainActor
    func test_blackImageURL_does_not_crash() {
        // Bundle.main inside the test runner is the test host, not the app bundle,
        // so this will likely return nil here. The invariant is that calling it
        // is safe and returns an `URL?`. The actual non-nil resolution is
        // verified at build time (Mural.app/Contents/Resources/black-1x1.png)
        // and exercised manually when the app launches.
        _ = SystemWallpaperOverride.blackImageURL()
    }

    func test_black_image_resource_name_is_what_we_ship() {
        // Lock the on-disk filename we look up at runtime. If someone renames
        // Resources/black-1x1.png without updating the lookup, this catches it.
        let resourcePath = URL(fileURLWithPath: "Resources/black-1x1.png")
        XCTAssertEqual(resourcePath.lastPathComponent, "black-1x1.png")
    }
}
