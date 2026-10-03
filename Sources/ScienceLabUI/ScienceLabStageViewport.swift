#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A dedicated UIKit stage container, rather than a transparent touch-catching
/// overlay. SwiftUI chrome/readouts are siblings above it and do not descend
/// from this container, so their touches never enter these recognizers.
@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabStageViewport<Content: View>: UIViewControllerRepresentable {
    let size: CGSize
    let resetGeneration: UInt
    @Binding var viewport: ScienceLabViewportState
    let content: Content
    @Environment(\.scenePhase) private var scenePhase

    func makeUIViewController(context: Context) -> StageController<Content> {
        StageController(content: content, environment: context.environment,
                        interaction: ScienceLabStageInteraction(), viewport: viewport.resized(to: size), onChange: publish)
    }

    func updateUIViewController(_ controller: StageController<Content>, context: Context) {
        controller.update(content: content, environment: context.environment,
                          size: size, resetGeneration: resetGeneration,
                          isActive: scenePhase == .active, onChange: publish)
    }

    private func publish(_ state: ScienceLabViewportState) {
        if viewport != state { viewport = state }
    }

    static func dismantleUIViewController(_ controller: StageController<Content>, coordinator: ()) {
        controller.prepareForDismantle()
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
final class StageController<Content: View>: UIViewController, UIGestureRecognizerDelegate {
    private let hosting: UIHostingController<AnyView>
    private let interaction: ScienceLabStageInteraction
    private var camera: ScienceLabViewportGestureState
    private var onChange: (ScienceLabViewportState) -> Void
    private var resetGeneration: UInt = 0
    private var isActive = true
    private var isSequenceCancelled = false
    private var isInterrupting = false
    private var updateGeneration: UInt = 0
    private(set) var isDismantling = false
    private var receivedTouches: [ObjectIdentifier: UITouch] = [:]
    private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(viewportGestureChanged(_:)))
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(viewportGestureChanged(_:)))
    private lazy var intent = StageTwoFingerIntentRecognizer(target: self, action: #selector(intentChanged(_:)))

    init(content: Content, environment: EnvironmentValues, interaction: ScienceLabStageInteraction,
         viewport: ScienceLabViewportState, onChange: @escaping (ScienceLabViewportState) -> Void) {
        self.hosting = UIHostingController(rootView: Self.root(content, environment: environment,
                                                             size: viewport.size, interaction: interaction))
        self.interaction = interaction
        self.camera = ScienceLabViewportGestureState(viewport: viewport)
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func root(_ content: Content, environment: EnvironmentValues, size: CGSize,
                             interaction: ScienceLabStageInteraction) -> AnyView {
        // Merge before forwarding: a whole-environment modifier closer to the
        // content would overwrite a separately wrapped interaction modifier.
        var stageEnvironment = environment
        stageEnvironment.scienceLabStageInteraction = interaction
        return AnyView(content.frame(width: size.width, height: size.height)
            .environment(\.self, stageEnvironment)
            // The original shell has already expanded the stage through the
            // safe area. Do not inset the nested hosting root a second time.
            .ignoresSafeArea())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard !isDismantling else { return }
        view.backgroundColor = .clear
        view.clipsToBounds = true
        addChild(hosting)
        hosting.view.backgroundColor = .clear
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        intent.willRecognize = { [weak self] centroid, count in
            guard let self else { return }
            if count == 2 { self.begin(at: centroid) }
            else if count > 2 { self.cancelSequence() }
        }
        for recognizer in [intent, pinch, pan] {
            recognizer.delegate = self
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            view.addGestureRecognizer(recognizer)
        }
        applyCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isDismantling else { return }
        applyCamera()
    }

    func update(content: Content, environment: EnvironmentValues, size: CGSize,
                resetGeneration: UInt, isActive: Bool, onChange: @escaping (ScienceLabViewportState) -> Void) {
        guard !isDismantling else { return }
        // Every new proposal supersedes the previous environment/content
        // snapshot, including a foreground update overtaking queued background.
        updateGeneration &+= 1
        self.onChange = onChange
        let newSize = ScienceLabGeometry.sanitized(size)
        let resized = newSize != camera.viewport.size
        let reset = resetGeneration != self.resetGeneration
        let leavingActive = self.isActive && !isActive
        if resized || reset || leavingActive {
            let generation = updateGeneration
            // Geometry/scene updates happen within SwiftUI's render pass.
            // Keep the old hosting root intact until the cancellation publisher
            // has synchronously invalidated any scientific drag on the next
            // main turn, before UIKit cancels its touch sequence.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isDismantling, self.updateGeneration == generation else { return }
                self.interrupt()
                if resized { self.camera.resize(to: newSize) }
                if reset { self.camera.reset() }
                self.applyUpdate(content: content, environment: environment, size: newSize,
                                 resetGeneration: resetGeneration, isActive: isActive)
                self.onChange(self.camera.viewport)
            }
            return
        }
        applyUpdate(content: content, environment: environment, size: newSize,
                    resetGeneration: resetGeneration, isActive: isActive)
    }

    private func applyUpdate(content: Content, environment: EnvironmentValues, size: CGSize,
                             resetGeneration: UInt, isActive: Bool) {
        guard !isDismantling else { return }
        self.resetGeneration = resetGeneration
        self.isActive = isActive
        hosting.rootView = Self.root(content, environment: environment, size: size, interaction: interaction)
        if isViewLoaded {
            for recognizer in [intent, pinch, pan] { recognizer.isEnabled = isActive }
            applyCamera()
        }
    }

    func interrupt() {
        guard !isDismantling else { return }
        isInterrupting = true
        interaction.invalidateObjectInteraction()
        camera.cancel()
        receivedTouches.removeAll()
        isSequenceCancelled = false
        if isViewLoaded {
            // Disable child hit testing only after synchronous cancellation.
            // Ancestor viewport gestures are independent from this subtree.
            hosting.view.isUserInteractionEnabled = false
            for recognizer in [intent, pinch, pan] {
                recognizer.isEnabled = false
                recognizer.isEnabled = isActive
            }
            hosting.view.isUserInteractionEnabled = true
            applyCamera()
        }
        interaction.finishViewportInteraction()
        isInterrupting = false
    }

    /// UIViewControllerRepresentable invokes dismantle while its parent graph
    /// is being mutated. Publishing there reenters that graph and crashes on
    /// supported older runtimes. First close every callback without publishing.
    func prepareForDismantle() {
        guard !isDismantling else { return }
        isDismantling = true
        isActive = false
        updateGeneration &+= 1
        interaction.preventObjectRelease()
        onChange = { _ in }
        if isViewLoaded {
            intent.willRecognize = nil
            for recognizer in [intent, pinch, pan] {
                recognizer.removeTarget(self, action: nil)
                recognizer.delegate = nil
            }
        }
        // Strongly retain both controller and scientific hosting subtree until
        // the render transaction has returned. Scientific cancellation is real,
        // but it must not publish during destruction of the parent ViewGraph.
        DispatchQueue.main.async { [self] in
            // Newer UIKit may keep the representable's native wrapper attached
            // until after this turn. Detach our viewport before publishing its
            // cancellation, while retaining the scientific child for rollback.
            if isViewLoaded { view.removeFromSuperview() }
            interaction.invalidateObjectInteraction()
            camera.cancel()
            receivedTouches.removeAll()
            if isViewLoaded {
                for recognizer in [intent, pinch, pan] {
                    recognizer.isEnabled = false
                    view.removeGestureRecognizer(recognizer)
                }
                hosting.view.isUserInteractionEnabled = false
                hosting.willMove(toParent: nil)
                hosting.view.removeFromSuperview()
                hosting.removeFromParent()
            }
            interaction.finishViewportInteraction()
        }
    }

    private func begin(at centroid: CGPoint) {
        guard !isDismantling, !camera.isInteracting, isActive, !isSequenceCancelled, !isInterrupting else { return }
        interaction.beginViewportInteraction()
        camera.begin(at: centroid)
        hosting.view.isUserInteractionEnabled = false
    }

    private func applyCamera() {
        guard !isDismantling else { return }
        let state = camera.viewport
        // bounds stay at the original stage dimensions; UIKit's conversion
        // into the hosting root inverses this affine transform for local drags.
        hosting.view.bounds = CGRect(origin: .zero, size: state.size)
        hosting.view.center = CGPoint(x: state.size.width / 2 + state.offset.width,
                                      y: state.size.height / 2 + state.offset.height)
        hosting.view.transform = CGAffineTransform(scaleX: state.scale, y: state.scale)
    }

    private func currentCentroid() -> CGPoint? {
        guard !isDismantling else { return nil }
        receivedTouches = receivedTouches.filter { ![.ended, .cancelled].contains($0.value.phase) }
        guard receivedTouches.count == 2 else { return nil }
        let points = receivedTouches.values.map { $0.location(in: view) }
        return CGPoint(x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2)
    }

    private func updateCamera() {
        guard !isDismantling, !isSequenceCancelled, !isInterrupting, let centroid = currentCentroid() else { return }
        begin(at: centroid)
        camera.update(scaleFactor: pinch.scale, centroid: centroid)
        applyCamera()
        onChange(camera.viewport)
    }

    private func finish(cancelled: Bool) {
        guard !isDismantling, !isInterrupting else { return }
        if cancelled { camera.cancel() } else { camera.finish() }
        applyCamera()
        onChange(camera.viewport)
        receivedTouches.removeAll()
        isSequenceCancelled = false
        hosting.view.isUserInteractionEnabled = true
        interaction.finishViewportInteraction()
    }

    private func cancelSequence() {
        guard !isDismantling, !isSequenceCancelled else { return }
        isSequenceCancelled = true
        camera.cancel()
        applyCamera()
        onChange(camera.viewport)
        // Keep the intent recognizer and child interaction block alive until
        // every finger has lifted. A third finger never becomes a fresh pinch.
    }

    @objc private func viewportGestureChanged(_ recognizer: UIGestureRecognizer) {
        guard !isDismantling else { return }
        switch recognizer.state {
        case .began, .changed: updateCamera()
        case .cancelled: if camera.isInteracting { cancelSequence() }
        case .failed: break // The other valid recognizer may have succeeded.
        case .ended:
            // The intent recognizer keeps scientific hit testing disabled while
            // a remaining finger is down. It commits when the sequence ends.
            if intent.state != .began && intent.state != .changed { finish(cancelled: isSequenceCancelled) }
        default: break
        }
    }

    @objc private func intentChanged(_ recognizer: StageTwoFingerIntentRecognizer) {
        guard !isDismantling else { return }
        switch recognizer.state {
        case .began, .changed:
            if recognizer.contactCount > 2 { cancelSequence() }
            else { updateCamera() }
        case .ended: finish(cancelled: isSequenceCancelled)
        case .cancelled: finish(cancelled: true)
        default: break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard !isDismantling, isActive, let touchedView = touch.view,
              touchedView === view || touchedView.isDescendant(of: hosting.view),
              view.bounds.contains(touch.location(in: view)) else { return false }
        if gestureRecognizer === pinch {
            receivedTouches[ObjectIdentifier(touch)] = touch
            if let centroid = currentCentroid() { begin(at: centroid) }
            else if receivedTouches.count > 2 { cancelSequence() }
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        guard !isDismantling else { return false }
        if [intent, pinch, pan].contains(where: { $0 === other }) { return true }
        // A second finger arriving after an already-established single drag
        // can still cancel the child subtree and take over camera observation.
        return gestureRecognizer !== intent && other.view?.isDescendant(of: hosting.view) == true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        guard !isDismantling else { return false }
        // Only the early intent gate takes precedence over stage-owned science
        // gestures. It fails immediately on the first single-finger movement.
        return gestureRecognizer === intent && other.view?.isDescendant(of: hosting.view) == true
    }
}

/// Recognizes two fingers before any movement, so a plot's DragGesture cannot
/// mutate scientific data during a new pinch. A real single-finger movement
/// fails the gate and proceeds normally; no timer delays the scientific drag.
@available(iOS 15.0, macCatalyst 15.0, *)
private final class StageTwoFingerIntentRecognizer: UIGestureRecognizer {
    private var touches: [ObjectIdentifier: UITouch] = [:]
    private var initialPoint: CGPoint?
    var contactCount: Int { touches.count }
    var willRecognize: ((CGPoint, Int) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { self.touches[ObjectIdentifier(touch)] = touch }
        if self.touches.count == 1 { initialPoint = self.touches.values.first?.location(in: view) }
        else if self.touches.count >= 2 {
            let points = self.touches.values.map { $0.location(in: view) }
            let centroid = CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                                   y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
            // Cancellation reaches scientific subscribers before recognizing
            // this gate forces their UIKit recognizers to fail/cancel.
            willRecognize?(centroid, self.touches.count)
            // Hold recognition until the final lift even for an unsupported
            // third contact; the owner locks/reverts the entire sequence.
            state = state == .possible ? .began : .changed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible, let first = self.touches.values.first, let initialPoint {
            let point = first.location(in: view)
            if hypot(point.x - initialPoint.x, point.y - initialPoint.y) >= 0.5 { state = .failed }
        } else if state == .began || state == .changed { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { self.touches.removeValue(forKey: ObjectIdentifier(touch)) }
        if self.touches.isEmpty { state = state == .possible ? .failed : .ended }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .possible ? .failed : .cancelled
    }

    override func reset() {
        super.reset()
        touches.removeAll()
        initialPoint = nil
    }
}
#endif
