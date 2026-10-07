import Foundation
import XCTest
@testable import ScienceLabUI

final class ScienceLabViewportTests: XCTestCase {
    private let portrait = CGSize(width: 400, height: 800)

    func testOneTimesCannotExposeSpaceByPanning() {
        let state = ScienceLabViewportState(size: portrait, offset: CGSize(width: 100, height: -300))
        XCTAssertEqual(state.offset, .zero)
        XCTAssertEqual(state.contentPoint(fromViewport: .zero), .zero)
        XCTAssertEqual(state.contentPoint(fromViewport: CGPoint(x: 400, y: 800)), CGPoint(x: 400, y: 800))
    }

    func testCameraCapsArePointSixAndThree() {
        let baseline = ScienceLabViewportState(size: portrait, scale: 2)
        XCTAssertEqual(baseline.transformed(scaleFactor: 100, from: .zero, to: .zero).scale, 3)
        let minimum = baseline.transformed(scaleFactor: 0.01, from: .zero, to: .zero)
        XCTAssertEqual(minimum.scale, 0.6)
        XCTAssertEqual(minimum.offset, .zero)
    }

    func testOffCenterZoomKeepsObservedMarkerUnderFingers() {
        let initial = ScienceLabViewportState(size: portrait)
        let marker = CGPoint(x: 150, y: 300)
        let zoomed = initial.transformed(scaleFactor: 2, from: marker, to: marker)
        XCTAssertEqual(zoomed.offset, CGSize(width: 50, height: 100))
        XCTAssertEqual(zoomed.viewportPoint(fromContent: marker), marker)
    }

    func testMovingPinchCentroidMovesMarkerOnce() {
        let initial = ScienceLabViewportState(size: portrait)
        let zoomed = initial.transformed(scaleFactor: 2, from: CGPoint(x: 150, y: 300), to: CGPoint(x: 180, y: 320))
        XCTAssertEqual(zoomed.viewportPoint(fromContent: CGPoint(x: 150, y: 300)), CGPoint(x: 180, y: 320))
        XCTAssertEqual(zoomed.offset, CGSize(width: 80, height: 120))
    }

    func testPureTwoFingerPanUsesSameCameraMapping() {
        let initial = ScienceLabViewportState(size: portrait, scale: 2)
        let panned = initial.transformed(scaleFactor: 1, from: CGPoint(x: 200, y: 400), to: CGPoint(x: 260, y: 450))
        XCTAssertEqual(panned.scale, 2)
        XCTAssertEqual(panned.offset, CGSize(width: 60, height: 50))
        XCTAssertEqual(panned.contentPoint(fromViewport: CGPoint(x: 260, y: 450)), CGPoint(x: 200, y: 400))
    }

    func testEveryZoomAndPanExtremeKeepsVisibleCornersInsideContent() {
        for scale in [CGFloat(1), 1.1, 2, 3] {
            for offset in [CGSize(width: -99999, height: -99999), CGSize(width: 99999, height: 99999),
                           CGSize(width: -99999, height: 99999), CGSize(width: 99999, height: -99999)] {
                let state = ScienceLabViewportState(size: portrait, scale: scale, offset: offset)
                for corner in [CGPoint.zero, CGPoint(x: 400, y: 0), CGPoint(x: 0, y: 800), CGPoint(x: 400, y: 800)] {
                    let content = state.contentPoint(fromViewport: corner)
                    XCTAssertGreaterThanOrEqual(content.x, -0.00001)
                    XCTAssertGreaterThanOrEqual(content.y, -0.00001)
                    XCTAssertLessThanOrEqual(content.x, 400.00001)
                    XCTAssertLessThanOrEqual(content.y, 800.00001)
                }
            }
        }
    }

    func testMappingRoundTripAtZoomedEdges() {
        let state = ScienceLabViewportState(size: portrait, scale: 3, offset: CGSize(width: 400, height: -800))
        for point in [CGPoint.zero, CGPoint(x: 157, y: 612), CGPoint(x: 400, y: 800)] {
            let actual = state.contentPoint(fromViewport: state.viewportPoint(fromContent: point))
            XCTAssertEqual(actual.x, point.x, accuracy: 0.00001)
            XCTAssertEqual(actual.y, point.y, accuracy: 0.00001)
        }
    }

    func testRotationPreservesCameraAndRelativePan() {
        let original = ScienceLabViewportState(size: portrait, scale: 2, offset: CGSize(width: 100, height: -200))
        let landscape = original.resized(to: CGSize(width: 800, height: 400))
        XCTAssertEqual(landscape.scale, 2)
        XCTAssertEqual(landscape.offset, CGSize(width: 200, height: -100))
        XCTAssertEqual(landscape.resized(to: portrait), original)
    }

    func testInvalidGeometryAndScaleStayFinite() {
        let invalid = ScienceLabViewportState(size: CGSize(width: CGFloat.infinity, height: CGFloat.nan),
                                              scale: CGFloat.nan, offset: CGSize(width: CGFloat.infinity, height: CGFloat.nan))
        XCTAssertTrue(invalid.size.width.isFinite)
        XCTAssertTrue(invalid.size.height.isFinite)
        XCTAssertEqual(invalid.scale, 1)
        XCTAssertEqual(invalid.offset, CGSize.zero)
        let valid = ScienceLabViewportState(size: portrait, scale: 2)
        XCTAssertEqual(valid.transformed(scaleFactor: .nan, from: .zero, to: .zero), valid)
        XCTAssertEqual(valid.transformed(scaleFactor: -2, from: .zero, to: .zero), valid)
        XCTAssertEqual(valid.transformed(scaleFactor: 2, from: .zero, to: CGPoint(x: CGFloat.infinity, y: 30)), valid)
    }

    func testUpdatesUseOriginalGestureBaselineRatherThanCompounding() {
        var gesture = ScienceLabViewportGestureState(viewport: ScienceLabViewportState(size: portrait))
        gesture.begin(at: CGPoint(x: 200, y: 400))
        gesture.update(scaleFactor: 1.5, centroid: CGPoint(x: 220, y: 430))
        gesture.update(scaleFactor: 2, centroid: CGPoint(x: 240, y: 450))
        XCTAssertEqual(gesture.viewport.scale, 2)
        XCTAssertEqual(gesture.viewport.offset, CGSize(width: 40, height: 50))
    }

    func testCancellationRevertsUnfinishedMovementAndDoesNotCommitRelease() {
        let original = ScienceLabViewportState(size: portrait, scale: 1.5, offset: CGSize(width: 20, height: 30))
        var gesture = ScienceLabViewportGestureState(viewport: original)
        gesture.begin(at: CGPoint(x: 200, y: 400))
        gesture.update(scaleFactor: 2, centroid: CGPoint(x: 270, y: 490))
        gesture.cancel()
        XCTAssertEqual(gesture.viewport, original)
        XCTAssertFalse(gesture.isInteracting)
        gesture.update(scaleFactor: 3, centroid: .zero)
        XCTAssertEqual(gesture.viewport, original)
    }

    func testFinishedGestureSurvivesBackgroundCancellation() {
        var gesture = ScienceLabViewportGestureState(viewport: ScienceLabViewportState(size: portrait))
        gesture.begin(at: CGPoint(x: 200, y: 400))
        gesture.update(scaleFactor: 2, centroid: CGPoint(x: 220, y: 430))
        gesture.finish()
        let finished = gesture.viewport
        gesture.cancel()
        XCTAssertEqual(gesture.viewport, finished)
    }

    func testResizeCancelsOldCoordinateSequenceThenPreservesCommittedView() {
        var gesture = ScienceLabViewportGestureState(viewport: ScienceLabViewportState(size: portrait, scale: 2,
                                                                                     offset: CGSize(width: 100, height: -200)))
        gesture.begin(at: CGPoint(x: 200, y: 400))
        gesture.update(scaleFactor: 1.5, centroid: CGPoint(x: 300, y: 500))
        gesture.resize(to: CGSize(width: 800, height: 400))
        XCTAssertEqual(gesture.viewport.scale, 2)
        XCTAssertEqual(gesture.viewport.offset, CGSize(width: 200, height: -100))
        XCTAssertFalse(gesture.isInteracting)
    }

    func testResetCancelsActiveCameraAndRestoresFullStage() {
        var gesture = ScienceLabViewportGestureState(viewport: ScienceLabViewportState(size: portrait, scale: 3))
        gesture.begin(at: .zero)
        gesture.reset()
        XCTAssertEqual(gesture.viewport, ScienceLabViewportState(size: portrait))
        XCTAssertFalse(gesture.isInteracting)
    }

    func testDiagnosticsAreParseableIndependentlyOfLocale() throws {
        let state = ScienceLabViewportState(size: portrait, scale: 1.75, offset: CGSize(width: 12.5, height: -33.25))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(state.accessibilityValue.utf8)) as? [String: Double])
        XCTAssertEqual(object, ["scale": 1.75, "offsetX": 12.5, "offsetY": -33.25])
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import Combine

@available(iOS 15.0, macCatalyst 15.0, *)
final class ScienceLabStageInteractionTests: XCTestCase {
    func testCancellationPublisherObservesViewportIntentBeforeScientificTouchCancellation() {
        let interaction = ScienceLabStageInteraction()
        var observedActive: [Bool] = []
        let subscription = interaction.$cancellationGeneration.dropFirst().sink { _ in
            observedActive.append(interaction.isViewportManipulating)
        }
        interaction.beginViewportInteraction()
        interaction.beginViewportInteraction()
        XCTAssertEqual(observedActive, [true])
        XCTAssertEqual(interaction.cancellationGeneration, 1)
        interaction.finishViewportInteraction()
        XCTAssertFalse(interaction.isViewportManipulating)
        withExtendedLifetime(subscription) {}
    }

    func testResizeAndSceneInvalidationAreCancellationRatherThanViewportRelease() {
        let interaction = ScienceLabStageInteraction()
        interaction.invalidateObjectInteraction()
        XCTAssertEqual(interaction.cancellationGeneration, 1)
        XCTAssertFalse(interaction.isViewportManipulating)
        interaction.beginViewportInteraction()
        interaction.invalidateObjectInteraction()
        XCTAssertEqual(interaction.cancellationGeneration, 3)
        interaction.finishViewportInteraction()
        XCTAssertFalse(interaction.isViewportManipulating)
    }

    @MainActor
    func testActualUIKitConversionMapsZoomedDragIntoOriginalStageCoordinates() {
        let size = CGSize(width: 400, height: 800)
        let camera = ScienceLabViewportState(size: size, scale: 2, offset: CGSize(width: 50, height: 100))
        let controller = StageController(content: Color.clear, environment: EnvironmentValues(),
                                         interaction: ScienceLabStageInteraction(), viewport: camera, onChange: { _ in })
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.layoutIfNeeded()
        let originalRoot = controller.view.subviews[0]
        XCTAssertEqual(originalRoot.bounds.size, size)
        let observedMarker = originalRoot.convert(CGPoint(x: 150, y: 300), to: controller.view)
        XCTAssertEqual(observedMarker.x, 150, accuracy: 0.0001)
        XCTAssertEqual(observedMarker.y, 300, accuracy: 0.0001)
        let scienceLocation = originalRoot.convert(CGPoint(x: 270, y: 520), from: controller.view)
        XCTAssertEqual(scienceLocation.x, 210, accuracy: 0.0001)
        XCTAssertEqual(scienceLocation.y, 410, accuracy: 0.0001)
        XCTAssertEqual(controller.view.gestureRecognizers?.count, 3)
        XCTAssertTrue(controller.view.clipsToBounds)
    }

    @MainActor
    func testNestedHostingForwardsAppearanceSceneAndInteractionWithoutDoubleSafeArea() async {
        let reported = expectation(description: "actual SwiftUI hosting environment")
        let interaction = ScienceLabStageInteraction()
        let size = CGSize(width: 390, height: 844)
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        environment.scenePhase = .active
        environment.dynamicTypeSize = .accessibility2
        // A distinct parent context must not override the native controller's
        // lifetime-scoped cancellation context in the actual hosted child.
        environment.scienceLabStageInteraction = ScienceLabStageInteraction()
        var result: StageEnvironmentProbe.Result?
        let content = StageEnvironmentProbe { value in
            if result == nil { result = value; reported.fulfill() }
        }
        let controller = StageController(content: content, environment: environment, interaction: interaction,
                                         viewport: ScienceLabViewportState(size: size), onChange: { _ in })
        let window = scienceLabTestWindow(frame: CGRect(origin: .zero, size: size))
        let appearance = ScienceLabTestAppearanceController(content: controller)
        window.rootViewController = appearance
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        let nativeAppearance = expectation(for: NSPredicate { _, _ in appearance.nativeDidAppear }, evaluatedWith: nil)
        await fulfillment(of: [nativeAppearance], timeout: 3)
        await fulfillment(of: [reported], timeout: 3)
        XCTAssertEqual(result?.size, size)
        XCTAssertEqual(result?.colorScheme, .dark)
        XCTAssertEqual(result?.scenePhase, .active)
        XCTAssertEqual(result?.dynamicTypeSize, .accessibility2)
        XCTAssertTrue(result?.interaction === interaction)
        window.isHidden = true
        window.rootViewController = nil
    }

    @MainActor
    func testRealSwiftUIStageRemovalDefersCancellationAndReleasesNativeController() async throws {
        let appeared = expectation(description: "scientific child actually hosted")
        let cancelled = expectation(description: "deferred scientific cancellation")
        let control = LifecycleHostControl()
        var stageInteraction: ScienceLabStageInteraction?
        var parent: UIHostingController<LifecycleHost>? = UIHostingController(rootView: LifecycleHost(control: control) { interaction in
            if stageInteraction == nil { stageInteraction = interaction; appeared.fulfill() }
        })
        let window = scienceLabTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        await fulfillment(of: [appeared], timeout: 3)
        let interaction = try XCTUnwrap(stageInteraction)
        var native: StageController<LifecycleStageProbe>? = try XCTUnwrap(findLifecycleController(in: parent!))
        weak var weakNative = native
        var cancellationCount = 0
        let subscription = interaction.$cancellationGeneration.dropFirst().sink { _ in
            cancellationCount += 1
            XCTAssertFalse(interaction.canReleaseObject)
            XCTAssertTrue(weakNative?.isDismantling == true)
            // Actual representable removal has returned before publication.
            XCTAssertNil(weakNative?.view.superview)
            cancelled.fulfill()
        }
        control.isPresented = false
        await fulfillment(of: [cancelled], timeout: 3)
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertTrue(native?.children.isEmpty == true)
        native = nil
        window.isHidden = true
        window.rootViewController = nil
        parent = nil
        let released = expectation(for: NSPredicate { _, _ in weakNative == nil }, evaluatedWith: nil)
        await fulfillment(of: [released], timeout: 3)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testDismantleInvalidatesQueuedResizeBindingAndCleanupIsIdempotent() async {
        let interaction = ScienceLabStageInteraction()
        var bindingWrites = 0
        let controller = StageController(content: Color.clear, environment: EnvironmentValues(),
                                         interaction: interaction,
                                         viewport: ScienceLabViewportState(size: CGSize(width: 390, height: 844)),
                                         onChange: { _ in bindingWrites += 1 })
        controller.loadViewIfNeeded()
        let cancelled = expectation(description: "exactly one delayed cancellation")
        var cancellationCount = 0
        let subscription = interaction.$cancellationGeneration.dropFirst().sink { _ in
            cancellationCount += 1
            cancelled.fulfill()
        }
        // A real production update queues the resized hosting root/binding.
        controller.update(content: Color.clear, environment: EnvironmentValues(), size: CGSize(width: 844, height: 390),
                          resetGeneration: 0, isActive: true, onChange: { _ in bindingWrites += 1 })
        controller.prepareForDismantle()
        controller.prepareForDismantle()
        XCTAssertFalse(interaction.canReleaseObject)
        XCTAssertEqual(cancellationCount, 0, "dismantle must not publish synchronously")
        controller.update(content: Color.clear, environment: EnvironmentValues(), size: CGSize(width: 500, height: 500),
                          resetGeneration: 1, isActive: true, onChange: { _ in bindingWrites += 1 })
        await fulfillment(of: [cancelled], timeout: 3)
        controller.interrupt()
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(bindingWrites, 0)
        XCTAssertTrue(controller.children.isEmpty)
        XCTAssertTrue(controller.view.gestureRecognizers?.isEmpty == true)
        XCTAssertTrue(controller.view.subviews.isEmpty)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testRealStageIdentityReplacementOwnsFreshInteractionLifetime() async throws {
        let firstAppeared = expectation(description: "first stage")
        let newAppeared = expectation(description: "new native stage lifetime")
        let oldCancelled = expectation(description: "old lifetime cancellation")
        let control = LifecycleHostControl()
        var contexts: [ScienceLabStageInteraction] = []
        var parent: UIHostingController<LifecycleHost>? = UIHostingController(rootView: LifecycleHost(control: control) { interaction in
            guard !contexts.contains(where: { $0 === interaction }) else { return }
            contexts.append(interaction)
            if contexts.count == 1 { firstAppeared.fulfill() } else { newAppeared.fulfill() }
        })
        let window = scienceLabTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        await fulfillment(of: [firstAppeared], timeout: 3)
        let old = try XCTUnwrap(contexts.first)
        let subscription = old.$cancellationGeneration.dropFirst().sink { _ in oldCancelled.fulfill() }
        // SwiftUI destroys and creates representables in the same render pass.
        // The old controller's cleanup is still queued when the new one starts.
        control.identity += 1
        await fulfillment(of: [oldCancelled, newAppeared], timeout: 3)
        XCTAssertEqual(contexts.count, 2)
        let current = contexts[1]
        XCTAssertFalse(old === current)
        XCTAssertFalse(old.canReleaseObject)
        XCTAssertTrue(current.canReleaseObject)
        XCTAssertEqual(current.cancellationGeneration, 0)
        old.finishViewportInteraction()
        XCTAssertTrue(current.canReleaseObject)
        XCTAssertEqual(current.cancellationGeneration, 0)
        window.isHidden = true
        window.rootViewController = nil
        parent = nil
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    private func findLifecycleController(in root: UIViewController) -> StageController<LifecycleStageProbe>? {
        if let stage = root as? StageController<LifecycleStageProbe> { return stage }
        for child in root.children {
            if let stage = findLifecycleController(in: child) { return stage }
        }
        return nil
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private final class LifecycleHostControl: ObservableObject {
    @Published var isPresented = true
    @Published var identity = 0
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct LifecycleHost: View {
    @ObservedObject var control: LifecycleHostControl
    let report: (ScienceLabStageInteraction) -> Void
    @State private var camera = ScienceLabViewportState(size: CGSize(width: 390, height: 844))
    var body: some View {
        ZStack {
            if control.isPresented {
                ScienceLabStageViewport(size: CGSize(width: 390, height: 844), resetGeneration: 0,
                                        viewport: $camera, content: LifecycleStageProbe(report: report))
                    .id(control.identity)
            }
        }
        .environment(\.scenePhase, .active)
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct LifecycleStageProbe: View {
    let report: (ScienceLabStageInteraction) -> Void
    @Environment(\.scienceLabStageInteraction) private var interaction
    var body: some View { ObservedLifecycleStageProbe(interaction: interaction, report: report) }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct ObservedLifecycleStageProbe: View {
    @ObservedObject var interaction: ScienceLabStageInteraction
    let report: (ScienceLabStageInteraction) -> Void
    var body: some View { Color.clear.onAppear { report(interaction) } }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct StageEnvironmentProbe: View {
    struct Result {
        let size: CGSize
        let colorScheme: ColorScheme
        let scenePhase: ScenePhase
        let dynamicTypeSize: DynamicTypeSize
        let interaction: ScienceLabStageInteraction
    }
    let report: (Result) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scienceLabStageInteraction) private var interaction
    var body: some View {
        GeometryReader { geometry in
            Color.clear.onAppear {
                report(Result(size: geometry.size, colorScheme: colorScheme, scenePhase: scenePhase,
                              dynamicTypeSize: dynamicTypeSize, interaction: interaction))
            }
        }
    }
}
#endif
