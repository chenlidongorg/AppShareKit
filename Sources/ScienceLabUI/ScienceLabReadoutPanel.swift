#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabReadoutPanel<Readouts: View>: View {
    let stageSize: CGSize
    let labels: ScienceLabLabels
    private let readouts: () -> Readouts
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: ScienceLabReadoutMode
    @State private var position = ScienceLabNormalizedPosition.topTrailing
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
        labels: ScienceLabLabels,
        initialMode: ScienceLabReadoutMode,
        @ViewBuilder readouts: @escaping () -> Readouts
    ) {
        self.stageSize = stageSize
        self.labels = labels
        self._mode = State(initialValue: initialMode)
        self.readouts = readouts
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

    private var restoredMode: ScienceLabReadoutMode {
        ScienceLabGeometry.restoredMode(in: stageSize, accessibilitySize: dynamicTypeSize.isAccessibilitySize)
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
                .accessibilityIdentifier("scienceLab.readouts.content")
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(ScienceLabSurface(cornerRadius: 18))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
        .position(x: frame.midX, y: frame.midY)
        .accessibilityIdentifier("scienceLab.readouts")
        .onAppear {
            guard !hasPlacedInitialHeader else { return }
            hasPlacedInitialHeader = true
            // Start below the overlaid top controls; subsequent moves belong
            // to the user and remain normalized through changes in size.
            position = ScienceLabGeometry.position(after: CGSize(width: 0, height: 54),
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
                        position = ScienceLabGeometry.position(
                            after: value.translation,
                            from: position,
                            panelSize: panelSize,
                            in: stageSize
                        )
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
            .accessibilityAction(named: Text(displayedMode == .minimized ? labels.restore : labels.minimize)) {
                changeMode(to: displayedMode == .minimized ? restoredMode : .minimized)
            }
            .accessibilityAction(named: Text(displayedMode == .maximized ? labels.restore : labels.maximize)) {
                changeMode(to: displayedMode == .maximized ? .expanded : .maximized)
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
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { position = .topTrailing }
    }

    private func centerPosition() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            position = ScienceLabNormalizedPosition(x: 0.5, y: 0.5)
        }
    }
}
#endif
