#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabReadoutPanel<Readouts: View>: View {
    let stageSize: CGSize
    let isVisible: Bool
    let labels: ScienceLabLabels
    let initialHeaderOffset: CGFloat
    private let readouts: () -> Readouts
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: ScienceLabReadoutMode
    @State private var minimizedPosition = ScienceLabNormalizedPosition.topTrailing
    @State private var maximizedPosition: ScienceLabNormalizedPosition?
    @State private var hasPlacedInitialHeader = false
    @GestureState private var drag: ReadoutDrag? = nil

    private struct ReadoutDrag {
        let geometry: ScienceLabDragGeometry
        let translation: CGSize
    }

    private struct DragIdentity: Hashable {
        let geometry: ScienceLabDragGeometry
        let isActive: Bool
        let mode: ScienceLabReadoutMode
    }

    init(
        stageSize: CGSize,
        isVisible: Bool = true,
        labels: ScienceLabLabels,
        initialMode: ScienceLabReadoutMode,
        initialHeaderOffset: CGFloat = 54,
        @ViewBuilder readouts: @escaping () -> Readouts
    ) {
        self.stageSize = stageSize
        self.isVisible = isVisible
        self.labels = labels
        self.initialHeaderOffset = initialHeaderOffset
        self._mode = State(initialValue: initialMode)
        self.readouts = readouts
    }

    private var position: ScienceLabNormalizedPosition {
        displayedMode == .maximized
            ? maximizedPosition ?? ScienceLabGeometry.defaultMaximizedPosition(in: stageSize)
            : minimizedPosition
    }

    private func setPosition(_ position: ScienceLabNormalizedPosition) {
        if displayedMode == .maximized { maximizedPosition = position }
        else { minimizedPosition = position }
    }

    private var panelSize: CGSize {
        ScienceLabGeometry.panelSize(
            in: stageSize,
            mode: mode,
            accessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var displayedMode: ScienceLabReadoutMode {
        ScienceLabGeometry.displayMode(for: mode, in: stageSize, accessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }

    private var dragGeometry: ScienceLabDragGeometry {
        ScienceLabDragGeometry(container: stageSize, panel: panelSize)
    }

    private var translation: CGSize {
        guard let drag else { return .zero }
        return ScienceLabGeometry.dragTranslation(drag.translation, startedIn: drag.geometry, current: dragGeometry, isActive: scenePhase == .active)
    }

    private var panelFrame: CGRect {
        ScienceLabGeometry.frame(
            at: position,
            panelSize: panelSize,
            in: stageSize,
            translation: translation
        )
    }

    var body: some View {
        let frame = panelFrame
        // Keep presentation state on this stable owner while removing hidden
        // glass from rendering, hit testing and the accessibility hierarchy.
        ZStack {
            if isVisible {
                VStack(spacing: 0) {
                    header
                        .frame(height: min(ScienceLabGeometry.readoutHeaderHeight, frame.height))
                    if displayedMode != .minimized && frame.height > ScienceLabGeometry.readoutHeaderHeight {
                        Divider()
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 10) {
                                readouts()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("scienceLab.readouts.content")
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .background {
                    // Keep controls and scrolling above the decorative glass.
                    // Wrapping the entire panel in glass intercepts child
                    // button touches on iPadOS 27; the backdrop has no input.
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.clear)
                        .modifier(ScienceLabSurface(cornerRadius: 18))
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("scienceLab.readouts")
            }
        }
        .onAppear {
            guard !hasPlacedInitialHeader else { return }
            hasPlacedInitialHeader = true
            // Start below the overlaid top controls; subsequent moves belong
            // to the user and remain normalized through changes in size.
            minimizedPosition = ScienceLabGeometry.position(after: CGSize(width: 0, height: initialHeaderOffset),
                                                   from: .topTrailing, panelSize: panelSize, in: stageSize)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(labels.readouts)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            // Only the handle/title region owns a drag. Never install a drag
            // on the canvas, scrolling content, or interactive parameter views.
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .updating($drag) { value, state, _ in
                        state = ReadoutDrag(geometry: state?.geometry ?? dragGeometry, translation: value.translation)
                    }
                    .onEnded { value in
                        setPosition(ScienceLabGeometry.position(
                            after: value.translation,
                            from: position,
                            panelSize: panelSize,
                            in: stageSize
                        ))
                    }
            )
            // Replacing the handle cancels its active gesture. GestureState
            // resets without committing an obsolete global-coordinate delta.
            .id(DragIdentity(geometry: dragGeometry, isActive: scenePhase == .active, mode: displayedMode))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(labels.readouts))
            .accessibilityValue(Text(modeDescription))
            .accessibilityHint(Text(labels.moveHint))
            .accessibilityAction(named: Text(labels.resetPosition)) { resetPosition() }
            .accessibilityAction(named: Text(labels.centerPosition)) { centerPosition() }
            .accessibilityAction(named: Text(displayedMode == .maximized ? labels.minimize : labels.maximize)) {
                changeMode(to: displayedMode == .maximized ? .minimized : .maximized)
            }
            .accessibilityIdentifier("scienceLab.readouts.dragHandle")

            Button {
                changeMode(to: displayedMode == .maximized ? .minimized : .maximized)
            } label: {
                Image(systemName: displayedMode == .maximized ? "minus" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(displayedMode == .maximized ? labels.minimize : labels.maximize))
            .accessibilityIdentifier("scienceLab.readouts.toggle")
        }
    }

    private var modeDescription: String {
        switch displayedMode {
        case .minimized: return labels.minimized
        case .expanded: return labels.expanded
        case .maximized: return labels.maximized
        }
    }

    private func changeMode(to mode: ScienceLabReadoutMode) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { self.mode = mode }
    }

    private func resetPosition() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            if displayedMode == .maximized { maximizedPosition = nil }
            else {
                minimizedPosition = ScienceLabGeometry.position(after: CGSize(width: 0, height: initialHeaderOffset),
                                                               from: .topTrailing, panelSize: panelSize, in: stageSize)
            }
        }
    }

    private func centerPosition() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            setPosition(ScienceLabNormalizedPosition(x: 0.5, y: 0.5))
        }
    }
}
#endif
