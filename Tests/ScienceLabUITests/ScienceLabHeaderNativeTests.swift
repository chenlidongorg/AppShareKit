#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import ScienceLabUI

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabHeaderNativeTests: XCTestCase {
    func testActualHelpAdvancedMoreGlyphsShareOneHorizontalRowInBothTraitsAndWindows() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for size in [CGSize(width: 393, height: 852), CGSize(width: 852, height: 393), CGSize(width: 320, height: 568)] {
            for style in [UIUserInterfaceStyle.light, .dark] {
              for fullBleedParent in [false, true] {
                let content = fullBleedParent ? AnyView(HeaderFixture().ignoresSafeArea()) : AnyView(HeaderFixture())
                let parent = UIHostingController(rootView: content)
                parent.overrideUserInterfaceStyle = style
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                window.rootViewController = parent
                window.makeKeyAndVisible()
                defer { window.isHidden = true; window.rootViewController = nil }
                let appeared = expectation(for: NSPredicate { _, _ in parent.view.window === window && parent.view.bounds.width == size.width }, evaluatedWith: nil)
                await fulfillment(of: [appeared], timeout: 3)
                parent.view.layoutIfNeeded()
                // A rendered display frame is required; synchronous layout alone
                // can still precede SwiftUI's first committed contents.
                try await Task.sleep(nanoseconds: 120_000_000)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                format.opaque = true
                var drew = false
                let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    drew = parent.view.drawHierarchy(in: parent.view.bounds, afterScreenUpdates: true)
                }
                XCTAssertTrue(drew)
                let attachment = XCTAttachment(image: image)
                attachment.name = "Shared-actual-header-\(Int(size.width))x\(Int(size.height))-\(style == .dark ? "dark" : "light")-\(fullBleedParent ? "fullBleed" : "safeContainer")"
                attachment.lifetime = .keepAlways
                add(attachment)
                if size.width == 393 && style == .light {
                    func tree(_ view: UIView, depth: Int = 0) -> String {
                        let frame = view.convert(view.bounds, to: parent.view)
                        return String(repeating: " ", count: depth) + "\(type(of: view)) frame=\(frame) safe=\(view.safeAreaInsets)" + "\n" + view.subviews.map { tree($0, depth: depth + 1) }.joined()
                    }
                    let nativeTree = XCTAttachment(string: tree(parent.view))
                    nativeTree.name = "Shared-actual-native-view-tree"
                    nativeTree.lifetime = .keepAlways
                    add(nativeTree)
                }
                let cg = try XCTUnwrap(image.cgImage)
                var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
                pixels.withUnsafeMutableBytes { storage in
                    let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                    let context = CGContext(data: storage.baseAddress, width: cg.width, height: cg.height,
                                            bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
                    context.draw(cg, in: CGRect(origin: .zero, size: size))
                }
                // Derive positions from actual rendered label ink. System
                // corner avoidance can legitimately change horizontal origins.
                func ink(_ x: Int, _ y: Int) -> Bool {
                    let offset = (y * cg.width + x) * 4
                    let channels = pixels[offset...offset + 2]
                    return style == .dark ? channels.min()! > 220 : channels.max()! < 65
                }
                let top = try XCTUnwrap((0..<180).first { y in
                    (0..<cg.width).filter { ink($0, y) }.count > 6
                })
                let band = top..<min(top + 65, cg.height)
                var columns: [(lo: Int, hi: Int)] = []
                for x in 0..<cg.width where band.contains(where: { ink(x, $0) }) {
                    if let last = columns.last, x - last.hi <= 8 {
                        columns[columns.count - 1] = (last.lo, x)
                    } else { columns.append((x, x)) }
                }
                XCTAssertGreaterThanOrEqual(columns.count, 4, "Observe focus and three actual header glyphs")
                let glyphColumns = Array(columns.suffix(3))
                let xs = glyphColumns.map { ($0.lo + $0.hi) / 2 }
                let centers = try glyphColumns.map { bounds -> Double in
                    let rows = band.filter { y in (bounds.lo...bounds.hi).contains(where: { ink($0, y) }) }
                    let lo = try XCTUnwrap(rows.min())
                    let hi = try XCTUnwrap(rows.max())
                    let count = rows.reduce(0) { n, y in n + (bounds.lo...bounds.hi).filter { ink($0, y) }.count }
                    XCTAssertGreaterThan(count, 12, "Must observe an actual native glyph")
                    return Double(lo + hi) / 2
                }
                let proof = XCTAttachment(string: "Native header glyph centers x=\(xs), y=\(centers), size=\(size), trait=\(style.rawValue)")
                proof.name = "Shared-native-header-measurement-\(fullBleedParent ? "fullBleed" : "safeContainer")"
                proof.lifetime = .keepAlways
                add(proof)
                XCTAssertEqual(centers[0], centers[1], accuracy: 1.5, "Help and advanced controls must align")
                XCTAssertEqual(centers[1], centers[2], accuracy: 1.5, "More must align on the same actual native row")
                window.isHidden = true
                window.rootViewController = nil
              }
            }
        }
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct HeaderFixture: View {
    @State private var parametersPresented = false
    var body: some View {
        ScienceLabShell(title: "Experiment", isRunning: false,
                        onToggleRun: {}, onReset: {}, onCapture: {}, onParameters: {},
                        stage: { _ in Color(uiColor: .systemBackground) },
                        controls: { Text("Parameters") }, readouts: { Text("Output") },
                        knowledge: { Text("Explanation") })
            .sheet(isPresented: $parametersPresented) { Text("Advanced parameters") }
    }
}
#endif
