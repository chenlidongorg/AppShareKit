#if canImport(SwiftUI)
import SwiftUI

/// A stage-first layout with two centered primary controls and a movable
/// readout overlay. All science, capture, and controller state stays with the
/// host. There is deliberately no scroll container around the stage.
@available(iOS 15.0, macCatalyst 15.0, *)
public struct ScienceLabShell<Stage: View, Controls: View, Readouts: View, Knowledge: View>: View {
    private let title: String
    private let showsTitle: Bool
    private let isRunning: Bool
    private let isCaptureConfirmed: Bool
    private let primaryAction: ScienceLabPrimaryAction
    private let palette: ScienceLabPalette
    private let labels: ScienceLabLabels
    private let initialReadoutMode: ScienceLabReadoutMode
    private let onToggleRun: () -> Void
    private let onReset: () -> Void
    private let onCapture: () -> Void
    private let onParameters: () -> Void
    private let stage: (CGSize) -> Stage
    private let controls: () -> Controls
    private let readouts: () -> Readouts
    private let knowledge: () -> Knowledge
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeSheet: Sheet?

    private enum Sheet: String, Identifiable {
        case commonParameters, knowledge
        var id: String { rawValue }
    }

    public init(
        title: String,
        showsTitle: Bool = true,
        isRunning: Bool,
        isCaptureConfirmed: Bool = false,
        primaryAction: ScienceLabPrimaryAction = .simulation,
        palette: ScienceLabPalette = .standard,
        labels: ScienceLabLabels = .init(),
        initialReadoutMode: ScienceLabReadoutMode = .expanded,
        onToggleRun: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onCapture: @escaping () -> Void,
        onParameters: @escaping () -> Void,
        @ViewBuilder stage: @escaping (CGSize) -> Stage,
        @ViewBuilder controls: @escaping () -> Controls,
        @ViewBuilder readouts: @escaping () -> Readouts,
        @ViewBuilder knowledge: @escaping () -> Knowledge
    ) {
        self.title = title
        self.showsTitle = showsTitle
        self.isRunning = isRunning
        self.isCaptureConfirmed = isCaptureConfirmed
        self.primaryAction = primaryAction
        self.palette = palette
        self.labels = labels
        self.initialReadoutMode = initialReadoutMode
        self.onToggleRun = onToggleRun
        self.onReset = onReset
        self.onCapture = onCapture
        self.onParameters = onParameters
        self.stage = stage
        self.controls = controls
        self.readouts = readouts
        self.knowledge = knowledge
    }

    public var body: some View {
        GeometryReader { geometry in
            let metrics = ScienceLabGeometry.layout(
                for: geometry.size,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            ScienceLabGlassGroup {
                VStack(spacing: metrics.spacing) {
                    header
                        .frame(height: metrics.headerHeight)
                    stageArea
                        .frame(height: metrics.stageHeight)
                        .layoutPriority(1)
                    dock(compact: metrics.usesCompactChrome)
                        .frame(height: metrics.dockHeight)
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
            }
        }
        .background(palette.canvas)
        .environment(\.scienceLabPalette, palette)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .commonParameters:
                ScienceLabSheet(title: labels.commonParameters, doneLabel: labels.done, prefersLarge: false, identifier: "scienceLab.commonParameters.sheet") {
                    controls()
                }
                .environment(\.scienceLabPalette, palette)
            case .knowledge:
                ScienceLabSheet(title: labels.knowledge, doneLabel: labels.done, prefersLarge: true, identifier: "scienceLab.knowledge.sheet") {
                    knowledge()
                }
                .environment(\.scienceLabPalette, palette)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if showsTitle {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            iconButton(label: labels.knowledge, icon: "info.circle", identifier: "scienceLab.knowledge") {
                activeSheet = .knowledge
            }
            Menu {
                Button(action: onCapture) {
                    Label(isCaptureConfirmed ? labels.captureConfirmed : labels.capture,
                          systemImage: isCaptureConfirmed ? "checkmark" : "camera")
                }
                .accessibilityIdentifier("scienceLab.capture")
                Button(action: onReset) {
                    Label(labels.reset, systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("scienceLab.reset")
            } label: {
                Image(systemName: isCaptureConfirmed ? "checkmark.circle" : "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isCaptureConfirmed ? palette.positive : Color.primary)
                    .frame(width: 44, height: 44)
                    .modifier(ScienceLabSurface(cornerRadius: 14, interactive: true))
            }
            .accessibilityLabel(Text(labels.moreActions))
            .accessibilityValue(Text(isCaptureConfirmed ? labels.captureConfirmed : ""))
            .accessibilityIdentifier("scienceLab.moreActions")
            // The advanced entry remains the trailing-most top control.
            iconButton(label: labels.advancedParameters, icon: "slider.horizontal.3", identifier: "scienceLab.advancedParameters", action: onParameters)
        }
    }

    private var stageArea: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                stage(ScienceLabGeometry.sanitized(geometry.size))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityIdentifier("scienceLab.stage")
                ScienceLabReadoutPanel(
                    stageSize: geometry.size,
                    labels: labels,
                    initialMode: initialReadoutMode,
                    readouts: readouts
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Clipping bounds the panel without applying glass to the canvas.
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func dock(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Button(action: onToggleRun) {
                dockLabel(
                    title: primaryAction.title ?? (isRunning ? labels.pause : labels.start),
                    icon: primaryAction.systemImage ?? (isRunning ? "pause.fill" : "play.fill"),
                    compact: compact
                )
                .foregroundStyle(palette.accent)
                .modifier(ScienceLabSurface(cornerRadius: 20, interactive: true, tint: palette.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(!primaryAction.isEnabled)
            .opacity(primaryAction.isEnabled ? 1 : 0.45)
            .accessibilityLabel(Text(primaryAction.title ?? (isRunning ? labels.pause : labels.start)))
            .accessibilityIdentifier("scienceLab.primaryAction")

            Button { activeSheet = .commonParameters } label: {
                dockLabel(title: labels.commonParameters, icon: "dial.min", compact: compact)
                    .modifier(ScienceLabSurface(cornerRadius: 20, interactive: true))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(labels.commonParameters))
            .accessibilityIdentifier("scienceLab.commonParameters")
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func dockLabel(title: String, icon: String, compact: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
            if !compact {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .padding(.horizontal, 12)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func iconButton(label: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .modifier(ScienceLabSurface(cornerRadius: 14, interactive: true))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}
#endif
