import XCTest
@testable import AppShareKit

final class AppShareKitTests: XCTestCase {
    func testComposerProducesImage() throws {
        #if canImport(UIKit)
        let payload = AppSharePayload(appName: "Demo", prompt: "Test", logo: nil, qrcode: nil, officeURL: nil, contentImage: nil)
        let image = ShareImageComposer().composeImage(from: payload, scale: 1)
        XCTAssertEqual(image.size.width, 1024, accuracy: 0.5)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertEqual(try XCTUnwrap(image.cgImage).width, 1024)
        XCTAssertEqual(CGFloat(try XCTUnwrap(image.cgImage).height), image.size.height, accuracy: 0.5)
        let longPayload = AppSharePayload(appName: "Demo", prompt: String(repeating: "A detailed classroom experiment description. ", count: 80), logo: nil, qrcode: nil, officeURL: nil, contentImage: nil)
        let longImage = ShareImageComposer().composeImage(from: longPayload, scale: 1)
        XCTAssertEqual(longImage.size.width, image.size.width)
        XCTAssertGreaterThan(longImage.size.height, image.size.height)
        #else
        throw XCTSkip("UIKit is required for AppShareKit tests")
        #endif
    }
}
