import XCTest
@testable import AppShareKit

final class AppShareKitTests: XCTestCase {
    func testComposerProducesImage() throws {
        #if canImport(UIKit)
        let payload = AppSharePayload(appName: "Demo", prompt: "Test", logo: nil, qrcode: nil, officeURL: nil)
        let image = ShareImageComposer().composeImage(from: payload, scale: 1)
        XCTAssertEqual(image.size.width, 1024, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 1400, accuracy: 0.5)
        #else
        throw XCTSkip("UIKit is required for AppShareKit tests")
        #endif
    }
}
