#if canImport(UIKit) && canImport(SwiftUI)
import CoreGraphics
import SwiftUI
import UIKit
import XCTest
@testable import ScienceLabUI

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabExportLongPreviewNativeTests: XCTestCase {
    func testLongReportKeepsEnabledShareAndSaveVisibleBeforeAndAfterNativeScroll() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }, "Requires the real app-hosted scene")
        let originalKeyWindow = scene.windows.first { $0.isKeyWindow }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 720, height: 393)] {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let source = longReport(style: style)
                let session = ScienceLabExportSession(image: source, title: "1200-row scientific report", onSave: { _, _ in
                    XCTFail("This visibility test does not request photo-library access")
                })
                await session.prepareForPreview()
                XCTAssertEqual(session.phase, .preview)
                XCTAssertTrue(session.canAct)
                XCTAssertTrue(session.canSave)
                let prepared = try XCTUnwrap(session.file)
                XCTAssertEqual(prepared.pixelWidth, 320)
                XCTAssertEqual(prepared.pixelHeight, 22_000, "The original complete scientific PNG stays intact")
                let controller = ScienceLabExportPresenter.makeController(session: session)
                controller.overrideUserInterfaceStyle = style
                controller.view.tintColor = .systemBlue
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                window.rootViewController = controller
                window.makeKeyAndVisible()
                defer {
                    session.cancel()
                    window.isHidden = true
                    window.rootViewController = nil
                    originalKeyWindow?.makeKeyAndVisible()
                }
                let mounted = expectation(for: NSPredicate { _, _ in
                    controller.view.window === window && controller.view.bounds.size == size
                }, evaluatedWith: nil)
                await fulfillment(of: [mounted], timeout: 3)
                controller.view.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 120_000_000)

                let before = snapshot(controller.view, size: size)
                attach(before, "Long-preview-initial-\(Int(size.width))x\(Int(size.height))-\(style.rawValue)")
                let firstBands = try actionBands(before)
                XCTAssertEqual(firstBands.count, 2, "Both actual Share and Save rows must be visible without report scrolling")
                XCTAssertGreaterThan(try redScientificPixels(before), 40, "The displayed scientific preview must contain real curve pixels")

                let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }
                    .first { $0.contentSize.height > $0.bounds.height * 10 })
                XCTAssertGreaterThan(scroll.contentSize.height, 10_000, "Exercise an actual very long report, not a thumbnail")
                scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom), animated: false)
                controller.view.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 80_000_000)
                let after = snapshot(controller.view, size: size)
                attach(after, "Long-preview-tail-\(Int(size.width))x\(Int(size.height))-\(style.rawValue)")
                XCTAssertNotEqual(before.pngData(), after.pngData(), "The real report scroll changes its visible scientific contents")
                let lastBands = try actionBands(after)
                XCTAssertEqual(lastBands.count, 2)
                XCTAssertEqual(firstBands.map(\.lowerBound), lastBands.map(\.lowerBound), "Action rows remain in the same native viewport positions")
                XCTAssertEqual(firstBands.map(\.upperBound), lastBands.map(\.upperBound))
                XCTAssertTrue(session.canAct)
                XCTAssertTrue(session.canSave)
                XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.url.path))
                XCTAssertEqual(session.file?.pixelHeight, 22_000)
            }
        }
    }

    // A real bitmap fixture has a scientific curve followed by 1200 legible
    // record rows. It intentionally has no blue: blue native ink belongs to
    // the two enabled export controls, not the scientific report or labels.
    private func longReport(style: UIUserInterfaceStyle) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let traits = UITraitCollection(userInterfaceStyle: style)
        return UIGraphicsImageRenderer(size: CGSize(width: 320, height: 22_000), format: format).image { context in
            traits.performAsCurrent {
                UIColor.systemBackground.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 320, height: 22_000))
                let curve = UIBezierPath()
                for i in 0...280 {
                    let point = CGPoint(x: CGFloat(i) + 20, y: 20 + 8 * sin(CGFloat(i) / 24))
                    if i == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
                }
                UIColor(red: 0.92, green: 0.18, blue: 0.16, alpha: 1).setStroke()
                curve.lineWidth = 3
                curve.stroke()
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: UIColor.label]
                for row in 0..<1200 {
                    let text = String(format: "Row %04d · t=%04d s · c=%.3f mol/m3", row + 1, row, Double(row) / 1200)
                    (text as NSString).draw(at: CGPoint(x: 12, y: 130 + CGFloat(row) * 18), withAttributes: attributes)
                }
            }
        }
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func snapshot(_ view: UIView, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        var drew = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            drew = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(drew, "Actual committed native contents are required")
        return image
    }

    private func pixels(_ image: UIImage) throws -> (width: Int, height: Int, bytes: [UInt8]) {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes { storage in
            let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            let context = CGContext(data: storage.baseAddress, width: cg.width, height: cg.height,
                                    bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        }
        return (cg.width, cg.height, bytes)
    }

    private func actionBands(_ image: UIImage) throws -> [ClosedRange<Int>] {
        let bitmap = try pixels(image)
        var bands: [ClosedRange<Int>] = []
        // Cancel belongs to the top navigation bar and is excluded. The
        // report contains no blue; this is actual enabled native action ink.
        for y in max(0, bitmap.height - 200)..<bitmap.height {
            var count = 0
            for x in 0..<bitmap.width {
                let offset = (y * bitmap.width + x) * 4
                let r = Int(bitmap.bytes[offset]), g = Int(bitmap.bytes[offset + 1]), b = Int(bitmap.bytes[offset + 2])
                if b > r + 35 && b > g + 10 { count += 1 }
            }
            if count > 3 {
                if let last = bands.last, y - last.upperBound <= 3 {
                    bands[bands.count - 1] = last.lowerBound...y
                } else { bands.append(y...y) }
            }
        }
        XCTAssertTrue(bands.allSatisfy { $0.count >= 12 }, "Observe actual native button glyphs, not isolated decoration")
        return bands
    }

    private func redScientificPixels(_ image: UIImage) throws -> Int {
        let bitmap = try pixels(image)
        var count = 0
        for offset in stride(from: 0, to: bitmap.bytes.count, by: 4) {
            let r = Int(bitmap.bytes[offset]), g = Int(bitmap.bytes[offset + 1]), b = Int(bitmap.bytes[offset + 2])
            if r > g + 40 && r > b + 40 { count += 1 }
        }
        return count
    }

    private func attach(_ image: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
