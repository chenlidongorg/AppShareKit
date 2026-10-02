import Foundation
import XCTest
@testable import ScienceLabUI

final class ScienceLabGeometryTests: XCTestCase {
    func testClampsDraggedPanelToAllFourEdges() {
        let container = CGSize(width: 400, height: 300)
        let panel = CGSize(width: 200, height: 100)
        let leading = ScienceLabGeometry.clampedFrame(origin: CGPoint(x: -500, y: -500), panelSize: panel, in: container)
        let trailing = ScienceLabGeometry.clampedFrame(origin: CGPoint(x: 900, y: 900), panelSize: panel, in: container)
        XCTAssertEqual(leading, CGRect(x: 10, y: 10, width: 200, height: 100))
        XCTAssertEqual(trailing, CGRect(x: 190, y: 190, width: 200, height: 100))
    }

    func testOversizedPanelIsResizedBeforeClamping() {
        let frame = ScienceLabGeometry.clampedFrame(
            origin: CGPoint(x: 99, y: 99),
            panelSize: CGSize(width: 1000, height: 1000),
            in: CGSize(width: 240, height: 160)
        )
        XCTAssertEqual(frame, CGRect(x: 10, y: 10, width: 220, height: 140))
    }

    func testMinimizedPanelHasHeaderOnlyHeight() {
        let size = ScienceLabGeometry.panelSize(in: CGSize(width: 400, height: 500), mode: .minimized)
        XCTAssertEqual(size.height, ScienceLabGeometry.readoutHeaderHeight)
        XCTAssertEqual(size.width, 224)
    }

    func testExpandedPanelLeavesAnimationVisible() {
        let stage = CGSize(width: 390, height: 580)
        let panel = ScienceLabGeometry.panelSize(in: stage, mode: .expanded)
        XCTAssertLessThanOrEqual(panel.height, stage.height * 0.52)
        XCTAssertLessThan(panel.width * panel.height, stage.width * stage.height * 0.5)
    }

    func testMaximizedPanelIsExactlyInsideStageInsets() {
        let stage = CGSize(width: 390, height: 580)
        let panel = ScienceLabGeometry.panelSize(in: stage, mode: .maximized)
        let frame = ScienceLabGeometry.frame(at: .init(x: 0.37, y: 0.82), panelSize: panel, in: stage)
        XCTAssertEqual(frame, ScienceLabGeometry.availableBounds(in: stage))
    }

    func testEveryModeFitsTinyAndCompactStages() {
        let stages = [
            CGSize.zero,
            CGSize(width: 8, height: 8),
            CGSize(width: 160, height: 90),
            CGSize(width: 740, height: 190),
            CGSize(width: 320, height: 580)
        ]
        for stage in stages {
            for mode in ScienceLabReadoutMode.allCases {
                for accessibility in [false, true] {
                    let size = ScienceLabGeometry.panelSize(in: stage, mode: mode, accessibilitySize: accessibility)
                    let frame = ScienceLabGeometry.frame(at: .init(x: 1, y: 1), panelSize: size, in: stage)
                    XCTAssertGreaterThanOrEqual(frame.minX, 0)
                    XCTAssertGreaterThanOrEqual(frame.minY, 0)
                    XCTAssertLessThanOrEqual(frame.maxX, stage.width)
                    XCTAssertLessThanOrEqual(frame.maxY, stage.height)
                    XCTAssertGreaterThanOrEqual(frame.width, 0)
                    XCTAssertGreaterThanOrEqual(frame.height, 0)
                }
            }
        }
    }

    func testDragCommitsNormalizedLocation() {
        let stage = CGSize(width: 400, height: 300)
        let panel = CGSize(width: 200, height: 100)
        let result = ScienceLabGeometry.position(
            after: CGSize(width: -90, height: 90),
            from: .topTrailing,
            panelSize: panel,
            in: stage
        )
        XCTAssertEqual(result.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.y, 0.5, accuracy: 0.0001)
    }

    func testRotationPreservesProportionalPosition() {
        let position = ScienceLabNormalizedPosition(x: 0.3, y: 0.7)
        for stage in [CGSize(width: 380, height: 600), CGSize(width: 760, height: 260)] {
            let panel = ScienceLabGeometry.panelSize(in: stage, mode: .expanded)
            let bounds = ScienceLabGeometry.availableBounds(in: stage)
            let frame = ScienceLabGeometry.frame(at: position, panelSize: panel, in: stage)
            XCTAssertEqual((frame.minX - bounds.minX) / (bounds.width - panel.width), 0.3, accuracy: 0.0001)
            XCTAssertEqual((frame.minY - bounds.minY) / (bounds.height - panel.height), 0.7, accuracy: 0.0001)
        }
    }

    func testMaximizingDoesNotEraseRestorablePosition() {
        let position = ScienceLabNormalizedPosition(x: 0.28, y: 0.69)
        let stage = CGSize(width: 390, height: 580)
        let maximized = ScienceLabGeometry.panelSize(in: stage, mode: .maximized)
        let preserved = ScienceLabGeometry.position(
            after: CGSize(width: 400, height: -400),
            from: position,
            panelSize: maximized,
            in: stage
        )
        XCTAssertEqual(preserved, position)
    }

    func testMinimizeRestoreKeepsNormalizedAnchor() {
        let position = ScienceLabNormalizedPosition(x: 0.2, y: 0.8)
        let stage = CGSize(width: 440, height: 600)
        for mode in [ScienceLabReadoutMode.minimized, .expanded] {
            let panel = ScienceLabGeometry.panelSize(in: stage, mode: mode)
            let afterZeroDrag = ScienceLabGeometry.position(after: .zero, from: position, panelSize: panel, in: stage)
            XCTAssertEqual(afterZeroDrag.x, position.x, accuracy: 0.0001)
            XCTAssertEqual(afterZeroDrag.y, position.y, accuracy: 0.0001)
        }
    }

    func testCompactLandscapeReservesVisibleStage() {
        let layout = ScienceLabGeometry.layout(for: CGSize(width: 740, height: 300))
        XCTAssertTrue(layout.usesCompactChrome)
        XCTAssertEqual(layout.stageHeight, 184)
        XCTAssertGreaterThan(layout.stageHeight, layout.headerHeight + layout.dockHeight)
    }

    func testDynamicTypeUsesCompactChromeWithoutShrinkingType() {
        let layout = ScienceLabGeometry.layout(for: CGSize(width: 390, height: 650), accessibilitySize: true)
        XCTAssertTrue(layout.usesCompactChrome)
        XCTAssertGreaterThan(layout.stageHeight, 500)
        XCTAssertGreaterThanOrEqual(layout.dockHeight, 44)
        XCTAssertGreaterThanOrEqual(layout.headerHeight, 44)
    }

    func testLayoutNeverUsesMoreThanAvailableHeightWhenChromeFits() {
        for height in stride(from: 116, through: 1100, by: 13) {
            let metrics = ScienceLabGeometry.layout(for: CGSize(width: 390, height: CGFloat(height)))
            let used = metrics.stageHeight + metrics.headerHeight + metrics.dockHeight
                + metrics.spacing * 2 + metrics.verticalPadding * 2
            XCTAssertEqual(used, CGFloat(height), accuracy: 0.0001)
        }
    }

    func testInvalidGeometryNeverEscapesAsNaNOrNegativeSize() {
        let frame = ScienceLabGeometry.frame(
            at: .init(x: .nan, y: .infinity),
            panelSize: CGSize(width: -100, height: .infinity),
            in: CGSize(width: .nan, height: -20),
            translation: CGSize(width: .infinity, height: .nan)
        )
        XCTAssertEqual(frame, .zero)
        let layout = ScienceLabGeometry.layout(for: CGSize(width: -10, height: .infinity))
        XCTAssertEqual(layout.stageHeight, 0)
    }
}
