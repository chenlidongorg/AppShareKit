#if canImport(SwiftUI) && canImport(UIKit) && canImport(SceneKit)
import SwiftUI
import UIKit
import SceneKit
import Combine
import XCTest
@testable import ScienceLabUI

@available(iOS 15.0, macCatalyst 15.0, *)
final class ScienceLabStagePolicyTests: XCTestCase {
    @MainActor
    func testOmittingPolicyStillInstallsTheExistingBoundedObservationContainer() async throws {
        let made = expectation(description: "default stage actually created")
        let record = NativeWorldRecord()
        record.onMake = { _ in made.fulfill() }
        let parent = UIHostingController(rootView: PolicyHost(control: PolicyControl(), record: record,
                                                             usesDefaultPolicy: true))
        let window = present(parent, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true; window.rootViewController = nil }
        await fulfillment(of: [made], timeout: 3)
        let controller = try XCTUnwrap(findObservationController(in: parent))
        let view = try XCTUnwrap(record.latestView)
        XCTAssertTrue(view.isDescendant(of: controller.view))
        XCTAssertEqual(controller.view.gestureRecognizers?.count, 3)
        XCTAssertTrue(controller.view.clipsToBounds)
        XCTAssertEqual(view.transform, .identity)
    }

    @MainActor
    func testToolManagedNativeCameraAndRecognizersSurviveChromeUpdatesAndWindowResize() async throws {
        let made = expectation(description: "native world stage actually created")
        let control = PolicyControl(policy: .toolManaged)
        let record = NativeWorldRecord()
        record.onMake = { _ in made.fulfill() }
        let parent = UIHostingController(rootView: PolicyHost(control: control, record: record))
        let window = present(parent, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true; window.rootViewController = nil }
        await fulfillment(of: [made], timeout: 3)
        let view = try XCTUnwrap(record.latestView)
        let camera = try XCTUnwrap(view.pointOfView)
        let nativePinch = try XCTUnwrap(record.latestPinch)
        let nativeTap = try XCTUnwrap(record.latestTap)
        camera.position = SCNVector3(1, 2, 9)
        camera.camera?.orthographicScale = 4.25
        let previousUpdates = record.updateCount
        control.isRunning = true
        // Chrome-only changes need not update an unchanged representable.
        // Change a real scientific input as well: the actual native geometry
        // must update while the existing world camera remains untouched.
        control.objectRadius = 0.75
        let updated = expectation(for: NSPredicate { _, _ in record.updateCount > previousUpdates }, evaluatedWith: nil)
        await fulfillment(of: [updated], timeout: 3)
        let object = try XCTUnwrap(view.scene?.rootNode.childNode(withName: "scientificObject", recursively: true))
        XCTAssertEqual((object.geometry as? SCNSphere)?.radius, 0.75)
        let originalSize = view.bounds.size
        window.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        parent.view.frame = window.bounds
        window.layoutIfNeeded()
        parent.view.layoutIfNeeded()
        let resized = expectation(for: NSPredicate { _, _ in view.bounds.size != originalSize }, evaluatedWith: nil)
        await fulfillment(of: [resized], timeout: 3)

        XCTAssertNil(findObservationController(in: parent), "native cameras must have no shared observation ancestor")
        XCTAssertTrue(record.latestView === view)
        XCTAssertEqual(record.makeCount, 1, "ordinary chrome/layout updates must preserve the native world")
        XCTAssertTrue(view.pointOfView === camera)
        XCTAssertEqual(camera.position.x, 1)
        XCTAssertEqual(camera.position.y, 2)
        XCTAssertEqual(camera.position.z, 9)
        XCTAssertEqual(camera.camera?.orthographicScale, 4.25)
        XCTAssertTrue(view.allowsCameraControl)
        XCTAssertTrue(view.isMultipleTouchEnabled)
        XCTAssertTrue(view.gestureRecognizers?.contains(where: { $0 === nativePinch }) == true)
        XCTAssertTrue(view.gestureRecognizers?.contains(where: { $0 === nativeTap }) == true)
        XCTAssertTrue(nativePinch.isEnabled)
        XCTAssertTrue(nativeTap.isEnabled)
        XCTAssertEqual(view.transform, .identity)
        let renderedBounds = view.convert(view.bounds, to: parent.view)
        XCTAssertEqual(renderedBounds.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(renderedBounds.origin.y, 0, accuracy: 0.5)
        XCTAssertEqual(renderedBounds.width, parent.view.bounds.width, accuracy: 0.5)
        XCTAssertEqual(renderedBounds.height, parent.view.bounds.height, accuracy: 0.5)
        let objectPoint = view.projectPoint(SCNVector3Zero)
        let hit = view.hitTest(CGPoint(x: CGFloat(objectPoint.x), y: CGFloat(objectPoint.y)), options: nil).first
        XCTAssertEqual(hit?.node.name, "scientificObject", "object hit testing must still use the native camera")
    }

    @MainActor
    func testChangingToToolManagedReallyDismantlesOldObservationLifetimeWithoutAffectingNewWorld() async throws {
        let firstMade = expectation(description: "bounded stage created")
        let nativeMade = expectation(description: "native world created after policy change")
        let cancelled = expectation(description: "old observation deferred cancellation")
        let control = PolicyControl()
        let record = NativeWorldRecord()
        record.onMake = { _ in
            if record.makeCount == 1 { firstMade.fulfill() } else { nativeMade.fulfill() }
        }
        let parent = UIHostingController(rootView: PolicyHost(control: control, record: record))
        let window = present(parent, size: CGSize(width: 390, height: 844))
        defer { window.isHidden = true; window.rootViewController = nil }
        await fulfillment(of: [firstMade], timeout: 3)
        var controller: StageController<NativeWorldStage>? = try XCTUnwrap(findObservationController(in: parent))
        weak var oldController = controller
        let oldInteraction = try XCTUnwrap(record.latestInteraction)
        var cancellations = 0
        let subscription = oldInteraction.$cancellationGeneration.dropFirst().sink { _ in
            cancellations += 1
            XCTAssertFalse(oldInteraction.canReleaseObject)
            XCTAssertTrue(oldController?.isDismantling == true)
            XCTAssertNil(oldController?.view.superview, "old graph removal must precede publication")
            cancelled.fulfill()
        }
        control.policy = .toolManaged
        await fulfillment(of: [nativeMade, cancelled], timeout: 3)
        let nativeView = try XCTUnwrap(record.latestView)
        let nativeInteraction = try XCTUnwrap(record.latestInteraction)
        XCTAssertNil(findObservationController(in: parent))
        XCTAssertFalse(nativeInteraction === oldInteraction)
        XCTAssertEqual(nativeInteraction.cancellationGeneration, 0)
        XCTAssertTrue(nativeInteraction.canReleaseObject)
        XCTAssertEqual(nativeView.transform, .identity)
        XCTAssertEqual(cancellations, 1)
        controller = nil
        let released = expectation(for: NSPredicate { _, _ in oldController == nil }, evaluatedWith: nil)
        await fulfillment(of: [released], timeout: 3)
        XCTAssertTrue(nativeView.window === window)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    private func present(_ parent: UIViewController, size: CGSize) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        parent.view.layoutIfNeeded()
        return window
    }

    @MainActor
    private func findObservationController(in root: UIViewController) -> StageController<NativeWorldStage>? {
        if let stage = root as? StageController<NativeWorldStage> { return stage }
        for child in root.children {
            if let stage = findObservationController(in: child) { return stage }
        }
        return nil
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private final class PolicyControl: ObservableObject {
    @Published var policy: ScienceLabStageInteractionPolicy
    @Published var isRunning = false
    @Published var objectRadius: CGFloat = 0.5
    init(policy: ScienceLabStageInteractionPolicy = .bounded2D) { self.policy = policy }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct PolicyHost: View {
    @ObservedObject var control: PolicyControl
    let record: NativeWorldRecord
    var usesDefaultPolicy = false
    var body: some View {
        Group {
            if usesDefaultPolicy {
                ScienceLabShell(title: "World", isRunning: control.isRunning,
                                onToggleRun: {}, onReset: {}, onCapture: {}, onParameters: {},
                                stage: { _ in NativeWorldStage(record: record, objectRadius: control.objectRadius) },
                                controls: { Text("Parameter") }, readouts: { Text("Scientific result") },
                                knowledge: { Text("Explanation") })
            } else {
                ScienceLabShell(title: "World", isRunning: control.isRunning,
                                stageInteractionPolicy: control.policy,
                                onToggleRun: {}, onReset: {}, onCapture: {}, onParameters: {},
                                stage: { _ in NativeWorldStage(record: record, objectRadius: control.objectRadius) },
                                controls: { Text("Parameter") }, readouts: { Text("Scientific result") },
                                knowledge: { Text("Explanation") })
            }
        }
        .environment(\.scenePhase, .active)
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private final class NativeWorldRecord {
    weak var latestView: SCNView?
    weak var latestPinch: UIPinchGestureRecognizer?
    weak var latestTap: UITapGestureRecognizer?
    var latestInteraction: ScienceLabStageInteraction?
    var makeCount = 0
    var updateCount = 0
    var onMake: ((SCNView) -> Void)?
}

/// A real native scene with its own camera, hit-test callback and recognizers.
/// No touch events or observation-camera state are synthesized by these tests.
@available(iOS 15.0, macCatalyst 15.0, *)
private struct NativeWorldStage: UIViewRepresentable {
    let record: NativeWorldRecord
    let objectRadius: CGFloat
    @Environment(\.scienceLabStageInteraction) private var interaction
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.position = SCNVector3(0, 0, 7)
        view.scene?.rootNode.addChildNode(camera)
        let object = SCNNode(geometry: SCNSphere(radius: objectRadius))
        object.name = "scientificObject"
        view.scene?.rootNode.addChildNode(object)
        view.pointOfView = camera
        view.allowsCameraControl = true
        view.isMultipleTouchEnabled = true
        view.addGestureRecognizer(context.coordinator.pinch)
        view.addGestureRecognizer(context.coordinator.tap)
        record.latestView = view
        record.latestPinch = context.coordinator.pinch
        record.latestTap = context.coordinator.tap
        record.latestInteraction = interaction
        record.makeCount += 1
        record.onMake?(view)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        let object = view.scene?.rootNode.childNode(withName: "scientificObject", recursively: true)
        (object?.geometry as? SCNSphere)?.radius = objectRadius
        record.updateCount += 1
        record.latestInteraction = interaction
    }
    final class Coordinator: NSObject {
        lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
        lazy var tap = UITapGestureRecognizer(target: self, action: #selector(select(_:)))
        @objc private func zoom(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view as? SCNView, let camera = view.pointOfView?.camera else { return }
            if recognizer.state == .changed, recognizer.scale.isFinite, recognizer.scale > 0 {
                camera.orthographicScale /= Double(recognizer.scale)
                recognizer.scale = 1
            }
        }
        @objc private func select(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? SCNView else { return }
            _ = view.hitTest(recognizer.location(in: view), options: nil).first
        }
    }
}
#endif
