#if canImport(UIKit)
import Combine
import CoreGraphics
import UIKit
import XCTest
@testable import ScienceLabUI

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabExportTests: XCTestCase {
    private struct TestFailure: LocalizedError {
        var errorDescription: String? { "Test save failure" }
    }

    private func image(orientation: UIImage.Orientation = .up, scale: CGFloat = 2) -> UIImage {
        let pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255,
            0, 0, 255, 255, 0, 0, 0, 0,
            255, 255, 0, 255, 255, 0, 255, 255
        ]
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue))
        let cgImage = CGImage(width: 2, height: 3, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: provider,
                              decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }

    private func rgba(_ image: CGImage) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        result.withUnsafeMutableBytes { bytes in
            let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return result
    }

    func testPNGPreservesPixelDimensionsAndTransparency() throws {
        let (data, width, height) = try ScienceLabExportPNG.data(for: image())
        XCTAssertEqual(data.prefix(8), Data([137, 80, 78, 71, 13, 10, 26, 10]))
        XCTAssertEqual(width, 2)
        XCTAssertEqual(height, 3)
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(decoded.width, 2)
        XCTAssertEqual(decoded.height, 3)
        let pixels = rgba(decoded)
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        XCTAssertEqual(alpha.filter { $0 == 0 }.count, 1)
        XCTAssertEqual(alpha.filter { $0 == 255 }.count, 5)
    }

    func testDarkFieldPresentationMetadataPreservesScientificPNGPixelsAndActualUIKitTrait() async throws {
        let source = image()
        let before = try ScienceLabExportPNG.data(for: source).0
        source.scienceLabExportAppearance = .dark
        XCTAssertEqual(try ScienceLabExportPNG.data(for: source).0, before,
                       "Presentation appearance must never recolor scientific pixels or lose alpha")
        let session = ScienceLabExportSession(image: source, title: "Dark detector", onSave: nil)
        defer { session.cancel() }
        let controller = ScienceLabExportPresenter.makeController(session: session)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.overrideUserInterfaceStyle, .dark)
        let dark = expectation(for: NSPredicate { _, _ in controller.view.traitCollection.userInterfaceStyle == .dark }, evaluatedWith: nil)
        await fulfillment(of: [dark], timeout: 3)
        XCTAssertEqual(controller.view.traitCollection.userInterfaceStyle, .dark)
        XCTAssertEqual(try XCTUnwrap(UIImage(data: before)).scienceLabExportAppearance, .system,
                       "The in-memory presentation preference is not invented PNG science metadata")
    }

    func testOrdinaryNativePreviewInheritsItsPresentingControllerAppearance() async {
        let source = image()
        XCTAssertEqual(source.scienceLabExportAppearance, .system)
        let session = ScienceLabExportSession(image: source, title: "Adaptive experiment", onSave: nil)
        defer { session.cancel() }
        let controller = ScienceLabExportPresenter.makeController(session: session)
        let parent = UIViewController()
        parent.overrideUserInterfaceStyle = .light
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        parent.addChild(controller)
        parent.view.addSubview(controller.view)
        controller.didMove(toParent: parent)
        parent.view.layoutIfNeeded()
        XCTAssertEqual(controller.overrideUserInterfaceStyle, .unspecified)
        XCTAssertEqual(controller.view.traitCollection.userInterfaceStyle, .light)
        parent.overrideUserInterfaceStyle = .dark
        let changed = expectation(for: NSPredicate { _, _ in controller.view.traitCollection.userInterfaceStyle == .dark }, evaluatedWith: nil)
        await fulfillment(of: [changed], timeout: 3)
        XCTAssertEqual(controller.view.traitCollection.userInterfaceStyle, .dark)
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }

    func testPNGNormalizesRotatedOrientationWithoutDownsampling() throws {
        for orientation in [UIImage.Orientation.left, .right, .leftMirrored, .rightMirrored] {
            let (data, width, height) = try ScienceLabExportPNG.data(for: image(orientation: orientation, scale: 3))
            let decoded = try XCTUnwrap(UIImage(data: data))
            XCTAssertEqual(width, 3)
            XCTAssertEqual(height, 2)
            XCTAssertEqual(decoded.cgImage?.width, 3)
            XCTAssertEqual(decoded.cgImage?.height, 2)
            XCTAssertEqual(decoded.imageOrientation, .up)
        }
    }

    func testPNGAppliesUpsideDownOrientationToPixelContent() throws {
        let source = image(orientation: .down)
        let original = rgba(try XCTUnwrap(source.cgImage))
        let (data, _, _) = try ScienceLabExportPNG.data(for: source)
        let decoded = rgba(try XCTUnwrap(UIImage(data: data)?.cgImage))
        for pixel in 0..<6 {
            XCTAssertEqual(Array(decoded[(pixel * 4)..<(pixel * 4 + 4)]),
                           Array(original[((5 - pixel) * 4)..<((5 - pixel) * 4 + 4)]))
        }
    }

    func testInvalidImageProducesAnActionableFailure() {
        XCTAssertThrowsError(try ScienceLabExportPNG.data(for: UIImage()))
    }

    func testPreparedFileUsesSafeNameAndIsRemovedOnCancel() async throws {
        let session = ScienceLabExportSession(image: image(), title: String(repeating: "实验", count: 100) + "/结果:测试")
        await session.prepareForPreview()
        XCTAssertEqual(session.phase, .preview)
        let file = try XCTUnwrap(session.file)
        XCTAssertEqual(file.url.pathExtension, "png")
        XCTAssertLessThanOrEqual(file.url.lastPathComponent.utf8.count, 184)
        XCTAssertFalse(file.url.lastPathComponent.contains("/"))
        XCTAssertFalse(file.url.lastPathComponent.contains(":"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.url.path))
        let decoded = try XCTUnwrap(UIImage(contentsOfFile: file.url.path))
        XCTAssertEqual(decoded.cgImage?.width, file.pixelWidth)
        XCTAssertEqual(decoded.cgImage?.height, file.pixelHeight)
        session.cancel()
        XCTAssertEqual(session.phase, .cancelled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
        XCTAssertNil(session.file)
    }

    func testSaveDeduplicatesAndCanRetryAfterFailure() async throws {
        var calls = 0
        var completion: ScienceLabExportSaveCompletion?
        let session = ScienceLabExportSession(image: image(), title: "Test", onSave: { saved, callback in
            calls += 1
            XCTAssertEqual(saved.cgImage?.width, 2)
            XCTAssertEqual(saved.cgImage?.height, 3)
            completion = callback
        })
        await session.prepareForPreview()
        defer { session.cancel() }
        session.save()
        session.save()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(session.phase, .processing(.save))
        XCTAssertFalse(session.canAct)
        let failed = expectation(description: "save failure")
        var observer = session.$phase.sink { if case .failed(.save, _) = $0 { failed.fulfill() } }
        completion?(.failure(TestFailure()))
        await fulfillment(of: [failed], timeout: 1)
        observer.cancel()
        await session.retry()
        XCTAssertEqual(calls, 2)
        let saved = expectation(description: "save success")
        observer = session.$phase.sink { if $0 == .success(.save) { saved.fulfill() } }
        completion?(.success(()))
        await fulfillment(of: [saved], timeout: 1)
        observer.cancel()
        XCTAssertTrue(session.canAct)
    }

    func testCancelIgnoresLateSaveCompletion() async {
        var completion: ScienceLabExportSaveCompletion?
        let session = ScienceLabExportSession(image: image(), title: "Test", onSave: { _, callback in completion = callback })
        await session.prepareForPreview()
        session.save()
        session.cancel()
        let changed = expectation(description: "cancelled export must stay cancelled")
        changed.isInverted = true
        let observer = session.$phase.dropFirst().sink { _ in changed.fulfill() }
        completion?(.success(()))
        await fulfillment(of: [changed], timeout: 0.05)
        observer.cancel()
        XCTAssertEqual(session.phase, .cancelled)
    }

    func testSharingCancelAndErrorReturnToUsablePreview() async throws {
        let session = ScienceLabExportSession(image: image(), title: "Test")
        await session.prepareForPreview()
        defer { session.cancel() }
        XCTAssertNotNil(session.beginShare())
        XCTAssertNil(session.beginShare())
        session.finishShare(completed: false, error: nil)
        XCTAssertEqual(session.phase, .preview)
        XCTAssertTrue(session.canAct)
        XCTAssertNotNil(session.beginShare())
        session.finishShare(completed: false, error: TestFailure())
        XCTAssertEqual(session.phase, .failed(.share, "Test save failure"))
        await session.retry()
        XCTAssertEqual(session.phase, .preview)
        XCTAssertNotNil(session.beginShare())
        session.finishShare(completed: true, error: nil)
        XCTAssertEqual(session.phase, .success(.share))
    }

    func testActivityDismissalDelegateFinishesOnlyOnceAndPreservesPreviewFile() async throws {
        let session = ScienceLabExportSession(image: image(), title: "Dismissal")
        await session.prepareForPreview()
        defer { session.cancel() }
        let file = try XCTUnwrap(session.beginShare())
        var completions = 0
        let delegate = ScienceLabActivityDismissalDelegate { completed, error in
            completions += 1
            session.finishShare(completed: completed, error: error)
        }
        // Exercise the actual UIKit delegate entry point; the host UI test
        // separately proves a user's real sheet gesture dismisses the sheet.
        let presentation = UIPresentationController(presentedViewController: UIViewController(), presenting: nil)
        delegate.presentationControllerDidDismiss(presentation)
        let usable = expectation(for: NSPredicate { _, _ in session.canAct }, evaluatedWith: nil)
        await fulfillment(of: [usable], timeout: 3)
        XCTAssertEqual(session.phase, .preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        delegate.complete(completed: true, error: nil)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(session.phase, .preview)
    }

    func testPreparationFailureCanRetry() async {
        var attempts = 0
        let session = ScienceLabExportSession(image: image(), title: "Test", fileBuilder: { image, title in
            attempts += 1
            if attempts == 1 { throw TestFailure() }
            return try await ScienceLabExportPNG.prepare(image: image, title: title)
        })
        await session.prepareForPreview()
        XCTAssertEqual(session.phase, .failed(.prepare, "Test save failure"))
        await session.retry()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(session.phase, .preview)
        session.cancel()
    }

    func testCancelDuringPreparationRemovesLateFileAndDeduplicatesWork() async throws {
        let prepared = try await ScienceLabExportPNG.prepare(image: image(), title: "Test")
        var continuation: CheckedContinuation<ScienceLabExportFile, Error>?
        var calls = 0
        let started = expectation(description: "preparation started")
        let session = ScienceLabExportSession(image: image(), title: "Test", fileBuilder: { _, _ in
            calls += 1
            return try await withCheckedThrowingContinuation { pending in
                continuation = pending
                started.fulfill()
            }
        })
        let first = Task { await session.prepareForPreview() }
        await fulfillment(of: [started], timeout: 1)
        await session.prepareForPreview()
        XCTAssertEqual(calls, 1)
        session.cancel()
        continuation?.resume(returning: prepared)
        await first.value
        XCTAssertEqual(session.phase, .cancelled)
        XCTAssertNil(session.file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.url.path))
    }
}
#endif
