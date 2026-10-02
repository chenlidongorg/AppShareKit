import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
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

    func testLargeDynamicTypeUsesMoreReadableDataSpace() {
        let stage = CGSize(width: 390, height: 580)
        let normal = ScienceLabGeometry.panelSize(in: stage, mode: .expanded)
        let accessibility = ScienceLabGeometry.panelSize(in: stage, mode: .expanded, accessibilitySize: true)
        XCTAssertGreaterThan(accessibility.width, normal.width)
        XCTAssertGreaterThan(accessibility.height, normal.height)
        let frame = ScienceLabGeometry.frame(at: .topTrailing, panelSize: accessibility, in: stage)
        XCTAssertLessThanOrEqual(frame.maxX, stage.width)
        XCTAssertLessThanOrEqual(frame.maxY, stage.height)
    }

    func testCompactLandscapeKeepsPanelToggleUsable() {
        for stage in [CGSize(width: 708, height: 184), CGSize(width: 740, height: 190), CGSize(width: 320, height: 180)] {
            for accessibility in [false, true] {
                XCTAssertEqual(ScienceLabGeometry.displayMode(for: .expanded, in: stage, accessibilitySize: accessibility), .minimized)
                let size = ScienceLabGeometry.panelSize(in: stage, mode: .expanded, accessibilitySize: accessibility)
                XCTAssertEqual(size.height, ScienceLabGeometry.readoutHeaderHeight)
                XCTAssertGreaterThanOrEqual(size.height, 44)
                // A 44-point toggle, a drag handle, and horizontal padding.
                XCTAssertGreaterThanOrEqual(size.width, 44 + 44 + 16)
            }
        }
    }

    func testExpandedPanelsHaveAUsableScrollingRegion() {
        for width in [CGFloat(320), 390, 768] {
            for height in [CGFloat(116), 184, 260, 300, 580, 650] {
                for accessibility in [false, true] {
                    let stage = CGSize(width: width, height: height)
                    let mode = ScienceLabGeometry.displayMode(for: .expanded, in: stage, accessibilitySize: accessibility)
                    let size = ScienceLabGeometry.panelSize(in: stage, mode: .expanded, accessibilitySize: accessibility)
                    if mode == .expanded {
                        XCTAssertGreaterThanOrEqual(size.height - ScienceLabGeometry.readoutHeaderHeight,
                                                    accessibility ? 112 : 56)
                    } else {
                        XCTAssertEqual(size.height, ScienceLabGeometry.readoutHeaderHeight)
                    }
                }
            }
        }
    }

    func testRestoringCompactReadoutsExposesData() {
        let stage = CGSize(width: 708, height: 184)
        let restored = ScienceLabGeometry.restoredMode(in: stage)
        XCTAssertEqual(restored, .maximized)
        XCTAssertEqual(ScienceLabGeometry.displayMode(for: restored, in: stage), .maximized)
        let size = ScienceLabGeometry.panelSize(in: stage, mode: restored)
        XCTAssertGreaterThan(size.height - ScienceLabGeometry.readoutHeaderHeight, 0)
        XCTAssertEqual(ScienceLabGeometry.restoredMode(in: CGSize(width: 390, height: 580)), .expanded)
    }

    func testAdaptiveMinimizationPreservesAnchorThroughRotation() {
        let saved = ScienceLabNormalizedPosition(x: 0.28, y: 0.69)
        for stage in [CGSize(width: 390, height: 580), CGSize(width: 708, height: 184), CGSize(width: 390, height: 580)] {
            let panel = ScienceLabGeometry.panelSize(in: stage, mode: .expanded)
            let resolved = ScienceLabGeometry.position(after: .zero, from: saved, panelSize: panel, in: stage)
            XCTAssertEqual(resolved.x, saved.x, accuracy: 0.0001)
            XCTAssertEqual(resolved.y, saved.y, accuracy: 0.0001)
        }
    }

    func testResizeCancelsUncommittedDragAndPreservesSavedAnchor() {
        let saved = ScienceLabNormalizedPosition(x: 0.3, y: 0.7)
        let originalStage = CGSize(width: 390, height: 580)
        let resizedStage = CGSize(width: 708, height: 184)
        let original = ScienceLabDragGeometry(container: originalStage, panel: ScienceLabGeometry.panelSize(in: originalStage, mode: .expanded))
        let resizedPanel = ScienceLabGeometry.panelSize(in: resizedStage, mode: .expanded)
        let resized = ScienceLabDragGeometry(container: resizedStage, panel: resizedPanel)
        let translation = ScienceLabGeometry.dragTranslation(CGSize(width: -90, height: 120), startedIn: original, current: resized)
        XCTAssertEqual(translation, CGSize.zero)
        let preserved = ScienceLabGeometry.position(after: translation, from: saved, panelSize: resizedPanel, in: resizedStage)
        XCTAssertEqual(preserved.x, saved.x, accuracy: 0.0001)
        XCTAssertEqual(preserved.y, saved.y, accuracy: 0.0001)
    }

    func testPanelModeChangeCancelsTransientDrag() {
        let stage = CGSize(width: 390, height: 580)
        let expanded = ScienceLabDragGeometry(container: stage, panel: ScienceLabGeometry.panelSize(in: stage, mode: .expanded))
        let maximized = ScienceLabDragGeometry(container: stage, panel: ScienceLabGeometry.panelSize(in: stage, mode: .maximized))
        XCTAssertEqual(ScienceLabGeometry.dragTranslation(CGSize(width: 20, height: 50), startedIn: expanded, current: maximized), CGSize.zero)
        XCTAssertEqual(ScienceLabGeometry.dragTranslation(CGSize(width: -20, height: 50), startedIn: expanded, current: expanded), CGSize(width: -20, height: 50))
    }

    func testDragTranslationSanitizesInvalidComponents() {
        let context = ScienceLabDragGeometry(container: CGSize(width: 390, height: 580), panel: CGSize(width: 304, height: 244))
        XCTAssertEqual(ScienceLabGeometry.dragTranslation(CGSize(width: CGFloat.infinity, height: CGFloat.nan), startedIn: context, current: context), CGSize.zero)
    }

    func testInactiveSceneCancelsDragWithoutChangingSavedPosition() {
        let stage = CGSize(width: 390, height: 580)
        let panel = ScienceLabGeometry.panelSize(in: stage, mode: .expanded)
        let context = ScienceLabDragGeometry(container: stage, panel: panel)
        let saved = ScienceLabNormalizedPosition(x: 0.4, y: 0.6)
        let cancelled = ScienceLabGeometry.dragTranslation(CGSize(width: 90, height: -70), startedIn: context, current: context, isActive: false)
        XCTAssertEqual(cancelled, CGSize.zero)
        let preserved = ScienceLabGeometry.position(after: cancelled, from: saved, panelSize: panel, in: stage)
        XCTAssertEqual(preserved.x, saved.x, accuracy: 0.0001)
        XCTAssertEqual(preserved.y, saved.y, accuracy: 0.0001)
    }

    func testMaximizedPanelUsesCompactWindowThirdInsteadOfFillingStage() {
        let stage = CGSize(width: 390, height: 580)
        let panel = ScienceLabGeometry.panelSize(in: stage, mode: .maximized)
        let frame = ScienceLabGeometry.frame(at: .init(x: 0.37, y: 0.82), panelSize: panel, in: stage)
        XCTAssertTrue(ScienceLabGeometry.availableBounds(in: stage).contains(frame))
        XCTAssertEqual(panel.width, 360)
        XCTAssertEqual(panel.height, stage.height / 3, accuracy: 0.001)
    }

    func testWideMaximizedPanelHasSixHundredPointWidthLimit() {
        let stage = CGSize(width: 1366, height: 768)
        let panel = ScienceLabGeometry.panelSize(in: stage, mode: .maximized)
        XCTAssertEqual(panel.width, 600)
        XCTAssertEqual(panel.height, 256)
    }

    func testDefaultMaximizedPanelSitsAboveDockAndCanStillMove() {
        for stage in [CGSize(width: 390, height: 778), CGSize(width: 844, height: 350)] {
            let panel = ScienceLabGeometry.panelSize(in: stage, mode: .maximized)
            let position = ScienceLabGeometry.defaultMaximizedPosition(in: stage)
            let original = ScienceLabGeometry.frame(at: position, panelSize: panel, in: stage)
            XCTAssertEqual(original.midX, stage.width / 2, accuracy: 0.001)
            XCTAssertEqual(original.maxY, stage.height - 10 - 48 - 10, accuracy: 0.001)
            let moved = ScienceLabGeometry.position(after: CGSize(width: 30, height: -60), from: position,
                                                   panelSize: panel, in: stage)
            let movedFrame = ScienceLabGeometry.frame(at: moved, panelSize: panel, in: stage)
            XCTAssertNotEqual(movedFrame.origin, original.origin)
            XCTAssertTrue(ScienceLabGeometry.availableBounds(in: stage).contains(movedFrame))
        }
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
            after: .zero,
            from: position,
            panelSize: maximized,
            in: stage
        )
        XCTAssertEqual(preserved.x, position.x, accuracy: 0.0001)
        XCTAssertEqual(preserved.y, position.y, accuracy: 0.0001)
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

    func testLandscapeStageUsesFullAvailableHeight() {
        let layout = ScienceLabGeometry.layout(for: CGSize(width: 740, height: 300))
        XCTAssertTrue(layout.usesCompactChrome)
        XCTAssertEqual(layout.stageHeight, 300)
        XCTAssertGreaterThan(layout.stageHeight, layout.headerHeight + layout.dockHeight)
    }

    func testDynamicTypeUsesCompactChromeWithoutShrinkingType() {
        let layout = ScienceLabGeometry.layout(for: CGSize(width: 390, height: 650), accessibilitySize: true)
        XCTAssertTrue(layout.usesCompactChrome)
        XCTAssertGreaterThan(layout.stageHeight, 500)
        XCTAssertGreaterThanOrEqual(layout.dockHeight, 44)
        XCTAssertGreaterThanOrEqual(layout.headerHeight, 44)
    }

    func testOverlaidChromeNeverReducesStageOrAddsOuterMargins() {
        for height in stride(from: 0, through: 1100, by: 13) {
            let metrics = ScienceLabGeometry.layout(for: CGSize(width: 390, height: CGFloat(height)))
            XCTAssertEqual(metrics.stageHeight, CGFloat(height), accuracy: 0.0001)
            XCTAssertEqual(metrics.horizontalPadding, 0)
            XCTAssertEqual(metrics.verticalPadding, 0)
            XCTAssertEqual(metrics.spacing, 0)
        }
    }

    func testInvalidGeometryNeverEscapesAsNaNOrNegativeSize() {
        let frame = ScienceLabGeometry.frame(
            at: .init(x: CGFloat.nan, y: CGFloat.infinity),
            panelSize: CGSize(width: -100, height: CGFloat.infinity),
            in: CGSize(width: CGFloat.nan, height: -20),
            translation: CGSize(width: CGFloat.infinity, height: CGFloat.nan)
        )
        XCTAssertEqual(frame, CGRect.zero)
        let layout = ScienceLabGeometry.layout(for: CGSize(width: -10, height: CGFloat.infinity))
        XCTAssertEqual(layout.stageHeight, 0)
    }
}
