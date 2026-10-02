#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Scientific meanings stay distinct from interface accent/status colors.
public enum ScienceLabColorRole: String, CaseIterable {
    case position, velocity, acceleration, force, energy, substance, structure, reference
}

@available(iOS 15.0, macCatalyst 15.0, *)
public struct ScienceLabPalette {
    public var accent: Color
    public var positive: Color
    public var warning: Color
    public var canvas: Color
    public var opaqueSurface: Color
    public var scientificOverrides: [ScienceLabColorRole: Color]

    public init(
        accent: Color = .blue,
        positive: Color = .green,
        warning: Color = .orange,
        canvas: Color? = nil,
        opaqueSurface: Color? = nil,
        scientificOverrides: [ScienceLabColorRole: Color] = [:]
    ) {
        self.accent = accent
        self.positive = positive
        self.warning = warning
        #if canImport(UIKit)
        self.canvas = canvas ?? Color(uiColor: .systemGroupedBackground)
        self.opaqueSurface = opaqueSurface ?? Color(uiColor: .secondarySystemGroupedBackground)
        #else
        self.canvas = canvas ?? Color(white: 0.12)
        self.opaqueSurface = opaqueSurface ?? Color(white: 0.2)
        #endif
        self.scientificOverrides = scientificOverrides
    }

    public static var standard: ScienceLabPalette { ScienceLabPalette() }

    /// Supply the original tool's colors as overrides. The shell never changes
    /// a renderer, legend, series, or model color on its own.
    public func color(for role: ScienceLabColorRole) -> Color {
        if let original = scientificOverrides[role] { return original }
        switch role {
        case .position: return .blue
        case .velocity: return .orange
        case .acceleration: return .purple
        case .force: return .red
        case .energy: return .green
        case .substance: return .teal
        case .structure: return .indigo
        case .reference: return .secondary
        }
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct ScienceLabPaletteKey: EnvironmentKey {
    static var defaultValue: ScienceLabPalette { .standard }
}

@available(iOS 15.0, macCatalyst 15.0, *)
public extension EnvironmentValues {
    var scienceLabPalette: ScienceLabPalette {
        get { self[ScienceLabPaletteKey.self] }
        set { self[ScienceLabPaletteKey.self] = newValue }
    }
}

/// Default controls are localized in this target. Hosts may replace individual
/// values with their existing localization strings without changing models.
public struct ScienceLabLabels {
    public var start = "Start"
    public var pause = "Pause"
    public var commonParameters = "Common parameters"
    public var advancedParameters = "Advanced parameters"
    public var knowledge = "How it works"
    public var moreActions = "More actions"
    public var focus = "Focus stage"
    public var exitFocus = "Exit focus"
    public var reset = "Reset experiment"
    public var capture = "Capture image"
    public var captureConfirmed = "Image captured"
    public var readouts = "Output data"
    public var minimize = "Minimize output data"
    public var restore = "Restore output data"
    public var maximize = "Maximize output data"
    public var resetPosition = "Reset output data position"
    public var centerPosition = "Center output data"
    public var moveHint = "Drag the header to move. More actions include reset position."
    public var minimized = "Minimized"
    public var expanded = "Expanded"
    public var maximized = "Maximized"
    public var done = "Done"
    public var close = "Close"
    public var back = "Back"

    public init() {
        start = localized("action.start", fallback: start)
        pause = localized("action.pause", fallback: pause)
        commonParameters = localized("action.commonParameters", fallback: commonParameters)
        advancedParameters = localized("action.advancedParameters", fallback: advancedParameters)
        knowledge = localized("action.knowledge", fallback: knowledge)
        moreActions = localized("action.more", fallback: moreActions)
        focus = localized("action.focus", fallback: focus)
        exitFocus = localized("action.exitFocus", fallback: exitFocus)
        reset = localized("action.reset", fallback: reset)
        capture = localized("action.capture", fallback: capture)
        captureConfirmed = localized("status.captured", fallback: captureConfirmed)
        readouts = localized("title.readouts", fallback: readouts)
        minimize = localized("action.minimize", fallback: minimize)
        restore = localized("action.restore", fallback: restore)
        maximize = localized("action.maximize", fallback: maximize)
        resetPosition = localized("action.resetPosition", fallback: resetPosition)
        centerPosition = localized("action.centerPosition", fallback: centerPosition)
        moveHint = localized("hint.move", fallback: moveHint)
        minimized = localized("status.minimized", fallback: minimized)
        expanded = localized("status.expanded", fallback: expanded)
        maximized = localized("status.maximized", fallback: maximized)
        done = localized("action.done", fallback: done)
        close = localized("action.close", fallback: close)
        back = localized("action.back", fallback: back)
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, bundle: .module, value: fallback, comment: "Science lab shell control")
    }
}

/// Leave title/icon nil for Start/Pause. For non-simulation tools, override
/// their presentation and pass the existing action to `onToggleRun`.
public struct ScienceLabPrimaryAction {
    public var title: String?
    public var systemImage: String?
    public var isEnabled: Bool

    public init(title: String? = nil, systemImage: String? = nil, isEnabled: Bool = true) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }

    public static var simulation: ScienceLabPrimaryAction { ScienceLabPrimaryAction() }
}
#endif
