#if canImport(SwiftUI)
import SwiftUI

/// Dark-field experiments can opt into a consistent dark presentation.
/// Ordinary tools inherit the system appearance.
public enum ScienceLabAppearance {
    case system
    case dark
}

/// A stage-first layout with two centered primary controls and a movable
/// readout overlay. All science, capture, and controller state stays with the
/// host. There is deliberately no scroll container around the stage.
@available(iOS 15.0, macCatalyst 15.0, *)
public struct ScienceLabShell<Stage: View, Controls: View, Readouts: View, Knowledge: View>: View {
    private let title: String
    private let subtitle: String?
    private let showsTitle: Bool
    private let isRunning: Bool
    private let isCaptureConfirmed: Bool
    private let primaryAction: ScienceLabPrimaryAction
    private let appearance: ScienceLabAppearance
    private let stageInteractionPolicy: ScienceLabStageInteractionPolicy
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
    @Environment(\.scienceLabNavigationAction) private var navigationAction
    @State private var activeSheet: Sheet?
    @State private var isFocused = false
    @State private var isSubtitleVisible = false
    @State private var viewport = ScienceLabViewportState(size: .zero)
    @State private var viewportResetGeneration: UInt = 0

    private enum Sheet: String, Identifiable {
        case commonParameters, knowledge
        var id: String { rawValue }
    }

    public init(
        title: String,
        subtitle: String? = nil,
        showsTitle: Bool = true,
        isRunning: Bool,
        isCaptureConfirmed: Bool = false,
        primaryAction: ScienceLabPrimaryAction = .simulation,
        appearance: ScienceLabAppearance = .system,
        stageInteractionPolicy: ScienceLabStageInteractionPolicy = .bounded2D,
        palette: ScienceLabPalette = .standard,
        labels: ScienceLabLabels = .init(),
        initialReadoutMode: ScienceLabReadoutMode = .minimized,
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
        self.subtitle = subtitle
        self.showsTitle = showsTitle
        self.isRunning = isRunning
        self.isCaptureConfirmed = isCaptureConfirmed
        self.primaryAction = primaryAction
        self.appearance = appearance
        self.stageInteractionPolicy = stageInteractionPolicy
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
        // Read local state in the owning body, before the escaping geometry
        // builder. Every overlay must receive the same focus snapshot.
        let focused = isFocused
        let subtitleVisible = isSubtitleVisible
        let cameraValue = cameraAccessibilityValue
        return GeometryReader { geometry in
            let safeInsets = geometry.safeAreaInsets
            let stageSize = CGSize(width: geometry.size.width + safeInsets.leading + safeInsets.trailing,
                                   height: geometry.size.height + safeInsets.top + safeInsets.bottom)
            ScienceLabGlassGroup {
                ZStack(alignment: .topLeading) {
                    // Render through system safe areas. Controls and movable data
                    // continue to use the unobscured window geometry below.
                    ZStack {
                        viewportStage(size: ScienceLabGeometry.sanitized(stageSize))
                    }
                        .frame(width: stageSize.width, height: stageSize.height)
                        .clipped()
                        .offset(x: -safeInsets.leading, y: -safeInsets.top)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("scienceLab.stage")
                        .accessibilityValue(Text(cameraValue))
                        .zIndex(0)

                    VStack(spacing: 0) {
                        header(focused: focused)
                        if showsTitle && !focused {
                            heading(subtitleVisible: subtitleVisible)
                                .padding(.top, 8)
                        }
                        Spacer(minLength: 0)
                        dock
                    }
                    .padding(10)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .zIndex(1)
                    ScienceLabReadoutPanel(
                        stageSize: geometry.size,
                        isVisible: !focused,
                        labels: labels,
                        initialMode: initialReadoutMode,
                        initialHeaderOffset: showsTitle ? 124 : 54,
                        readouts: readouts
                    )
                    .zIndex(2)

                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
        }
        .background(palette.canvas)
        .environment(\.scienceLabPalette, palette)
        .preferredColorScheme(appearance == .dark ? .dark : nil)
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

    private var cameraAccessibilityValue: String {
        // World-camera metadata belongs to the tool. Do not report an unused
        // two-dimensional observation camera as if it describes the world.
        guard stageInteractionPolicy == .bounded2D else { return "" }
        #if DEBUG
        return viewport.accessibilityValue
        #else
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(viewport.scale))) ?? ""
        #endif
    }

    @ViewBuilder
    private func viewportStage(size: CGSize) -> some View {
        switch stageInteractionPolicy {
        case .bounded2D:
            #if canImport(UIKit)
            ScienceLabStageViewport(size: size, resetGeneration: viewportResetGeneration,
                                    viewport: $viewport, content: stage(size))
            #else
            stage(size)
            #endif
        case .toolManaged:
            // Keep the native view in the existing SwiftUI hierarchy: no
            // shared ancestor recognizers, affine transform or extra hosting.
            stage(size)
        }
    }

    private func header(focused: Bool) -> some View {
        return HStack(spacing: 8) {
            if !focused, let navigationAction {
                iconButton(label: labels.back, icon: "chevron.left",
                           identifier: "scienceLab.navigation.dismiss", action: navigationAction.onDismiss)
            }
            iconButton(label: focused ? labels.exitFocus : labels.focus,
                       icon: focused ? "arrow.down.right.and.arrow.up.left" : "viewfinder",
                       identifier: "scienceLab.focus") {
                isFocused.toggle()
            }
            Spacer(minLength: 0)
            if !focused {
              HStack(spacing: 8) {
                iconButton(label: labels.knowledge, icon: "info.circle", identifier: "scienceLab.knowledge") {
                    activeSheet = .knowledge
                }
                iconButton(label: labels.advancedParameters, icon: "slider.horizontal.3", identifier: "scienceLab.advancedParameters", action: onParameters)
                Menu {
                    Button(action: onCapture) {
                        Label(isCaptureConfirmed ? labels.captureConfirmed : labels.capture,
                              systemImage: isCaptureConfirmed ? "checkmark" : "camera")
                    }
                    .accessibilityIdentifier("scienceLab.capture")
                    Button {
                        if stageInteractionPolicy == .bounded2D {
                            viewportResetGeneration &+= 1
                            viewport = ScienceLabViewportState(size: viewport.size)
                        }
                        onReset()
                    } label: {
                        Label(labels.reset, systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("scienceLab.reset")
                } label: {
                    Image(systemName: isCaptureConfirmed ? "checkmark.circle" : "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isCaptureConfirmed ? palette.positive : Color.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .modifier(ScienceLabSurface(cornerRadius: 14, interactive: true))
                }
                .accessibilityLabel(Text(labels.moreActions))
                .accessibilityValue(Text(isCaptureConfirmed ? labels.captureConfirmed : ""))
                .accessibilityIdentifier("scienceLab.moreActions")
              }
            }
        }
    }

    private func heading(subtitleVisible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                isSubtitleVisible.toggle()
            } label: {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.60))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("scienceLab.title")
            }
                .buttonStyle(.plain)
                .disabled(subtitle?.isEmpty != false)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue(Text(subtitleVisible ? labels.expanded : labels.minimized))
                .accessibilityIdentifier("scienceLab.headingToggle")
            if subtitleVisible, let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .lineLimit(2)
                    .accessibilityIdentifier("scienceLab.subtitle")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scienceLab.heading")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dock: some View {
        HStack(spacing: 12) {
            Button(action: onToggleRun) {
                dockIcon(primaryAction.systemImage ?? (isRunning ? "pause.fill" : "play.fill"))
                .foregroundStyle(Color.primary)
                .modifier(ScienceLabSurface(cornerRadius: 20, interactive: true))
            }
            .buttonStyle(.plain)
            .disabled(!primaryAction.isEnabled)
            .opacity(primaryAction.isEnabled ? 1 : 0.45)
            .accessibilityLabel(Text(primaryAction.title ?? (isRunning ? labels.pause : labels.start)))
            .accessibilityIdentifier("scienceLab.primaryAction")

            Button { activeSheet = .commonParameters } label: {
                dockIcon("dial.min")
                    .modifier(ScienceLabSurface(cornerRadius: 20, interactive: true))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(labels.commonParameters))
            .accessibilityIdentifier("scienceLab.commonParameters")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func dockIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
        .frame(width: 48, height: 48)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func iconButton(label: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .modifier(ScienceLabSurface(cornerRadius: 14, interactive: true))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}
#endif
