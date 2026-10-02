import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Presentation state is independent of any scientific model or SwiftUI view.
public enum ScienceLabReadoutMode: String, CaseIterable, Hashable {
    case minimized
    case expanded
    case maximized
}

/// A panel's location in its available travel range, rather than screen pixels.
/// A value of (1, 0) anchors the panel to the stage's top-trailing corner.
public struct ScienceLabNormalizedPosition: Equatable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat = 1, y: CGFloat = 0) {
        self.x = ScienceLabGeometry.unit(x)
        self.y = ScienceLabGeometry.unit(y)
    }

    public static let topTrailing = ScienceLabNormalizedPosition()
}

public struct ScienceLabLayoutMetrics: Equatable {
    public let usesCompactChrome: Bool
    public let horizontalPadding: CGFloat
    public let verticalPadding: CGFloat
    public let spacing: CGFloat
    public let headerHeight: CGFloat
    public let dockHeight: CGFloat
    public let stageHeight: CGFloat
}

/// A drag is only meaningful in the geometry in which it started. A resize or
/// mode change cancels the transient translation, preserving the saved anchor.
struct ScienceLabDragGeometry: Equatable, Hashable {
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let panelWidth: CGFloat
    let panelHeight: CGFloat

    init(container: CGSize, panel: CGSize) {
        let container = ScienceLabGeometry.sanitized(container)
        let panel = ScienceLabGeometry.sanitized(panel)
        containerWidth = container.width
        containerHeight = container.height
        panelWidth = panel.width
        panelHeight = panel.height
    }
}

/// Pure geometry, intentionally kept free of SwiftUI and screen-singleton APIs.
public enum ScienceLabGeometry {
    public static let defaultInset: CGFloat = 10
    public static let readoutHeaderHeight: CGFloat = 48
    private static let minimumReadoutBodyHeight: CGFloat = 56

    /// Small stages keep an operable header instead of a barely visible
    /// scrolling region. Explicit maximization remains available in every size.
    public static func displayMode(
        for requestedMode: ScienceLabReadoutMode,
        in container: CGSize,
        accessibilitySize: Bool = false,
        inset: CGFloat = defaultInset
    ) -> ScienceLabReadoutMode {
        guard requestedMode == .expanded else { return requestedMode }
        let preferred = expandedPanelSize(in: container, accessibilitySize: accessibilitySize, inset: inset)
        let minimumBody = accessibilitySize ? minimumReadoutBodyHeight * 2 : minimumReadoutBodyHeight
        return preferred.width >= 160 && preferred.height >= readoutHeaderHeight + minimumBody
            ? .expanded : .minimized
    }

    /// Restoring in a compact window opens readable data rather than immediately
    /// folding the panel again. It does not change the user's saved position.
    public static func restoredMode(
        in container: CGSize,
        accessibilitySize: Bool = false,
        inset: CGFloat = defaultInset
    ) -> ScienceLabReadoutMode {
        displayMode(for: .expanded, in: container, accessibilitySize: accessibilitySize, inset: inset) == .expanded
            ? .expanded : .maximized
    }

    public static func finiteNonnegative(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }

    public static func unit(_ value: CGFloat) -> CGFloat {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    public static func sanitized(_ size: CGSize) -> CGSize {
        CGSize(width: finiteNonnegative(size.width), height: finiteNonnegative(size.height))
    }

    public static func availableBounds(
        in container: CGSize,
        inset: CGFloat = defaultInset
    ) -> CGRect {
        let size = sanitized(container)
        let safeInset = min(finiteNonnegative(inset), min(size.width, size.height) / 2)
        return CGRect(
            x: safeInset,
            y: safeInset,
            width: max(0, size.width - safeInset * 2),
            height: max(0, size.height - safeInset * 2)
        )
    }

    public static func panelSize(
        in container: CGSize,
        mode: ScienceLabReadoutMode,
        accessibilitySize: Bool = false,
        inset: CGFloat = defaultInset
    ) -> CGSize {
        let bounds = availableBounds(in: container, inset: inset)
        switch displayMode(for: mode, in: container, accessibilitySize: accessibilitySize, inset: inset) {
        case .minimized:
            return CGSize(width: min(224, bounds.width), height: min(readoutHeaderHeight, bounds.height))
        case .expanded:
            return expandedPanelSize(in: container, accessibilitySize: accessibilitySize, inset: inset)
        case .maximized:
            let size = sanitized(container)
            return CGSize(width: min(size.width >= size.height ? 600 : 360, bounds.width),
                          height: min(size.height / 3, bounds.height))
        }
    }

    /// First expansion sits immediately above the two 48-point dock buttons.
    /// Recalculate this semantic anchor after a resize until the user moves it.
    public static func defaultMaximizedPosition(in container: CGSize) -> ScienceLabNormalizedPosition {
        let bounds = availableBounds(in: container)
        let panel = panelSize(in: container, mode: .maximized)
        let origin = CGPoint(x: bounds.midX - panel.width / 2,
                             y: max(bounds.minY, bounds.maxY - 48 - defaultInset - panel.height))
        return position(after: CGSize(width: origin.x - bounds.minX, height: origin.y - bounds.minY),
                        from: .init(x: 0, y: 0), panelSize: panel, in: container)
    }

    private static func expandedPanelSize(
        in container: CGSize,
        accessibilitySize: Bool,
        inset: CGFloat
    ) -> CGSize {
        let bounds = availableBounds(in: container, inset: inset)
        return CGSize(
            width: min(accessibilitySize ? 360 : 304, bounds.width),
            height: min(accessibilitySize ? 360 : 244, bounds.height * (accessibilitySize ? 0.72 : 0.52))
        )
    }

    static func dragTranslation(
        _ translation: CGSize,
        startedIn original: ScienceLabDragGeometry,
        current: ScienceLabDragGeometry,
        isActive: Bool = true
    ) -> CGSize {
        guard isActive, original == current else { return .zero }
        return CGSize(
            width: translation.width.isFinite ? translation.width : 0,
            height: translation.height.isFinite ? translation.height : 0
        )
    }

    /// Constrains both the panel's origin and its dimensions to the stage.
    public static func clampedFrame(
        origin: CGPoint,
        panelSize: CGSize,
        in container: CGSize,
        inset: CGFloat = defaultInset
    ) -> CGRect {
        let bounds = availableBounds(in: container, inset: inset)
        let requested = sanitized(panelSize)
        let size = CGSize(width: min(requested.width, bounds.width), height: min(requested.height, bounds.height))
        let x = origin.x.isFinite ? origin.x : bounds.minX
        let y = origin.y.isFinite ? origin.y : bounds.minY
        return CGRect(
            x: min(max(x, bounds.minX), bounds.maxX - size.width),
            y: min(max(y, bounds.minY), bounds.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    public static func frame(
        at position: ScienceLabNormalizedPosition,
        panelSize: CGSize,
        in container: CGSize,
        translation: CGSize = .zero,
        inset: CGFloat = defaultInset
    ) -> CGRect {
        let bounds = availableBounds(in: container, inset: inset)
        let requested = sanitized(panelSize)
        let width = min(requested.width, bounds.width)
        let height = min(requested.height, bounds.height)
        let dx = translation.width.isFinite ? translation.width : 0
        let dy = translation.height.isFinite ? translation.height : 0
        return clampedFrame(
            origin: CGPoint(
                x: bounds.minX + unit(position.x) * max(0, bounds.width - width) + dx,
                y: bounds.minY + unit(position.y) * max(0, bounds.height - height) + dy
            ),
            panelSize: CGSize(width: width, height: height),
            in: container,
            inset: inset
        )
    }

    /// Preserve the previous normalized component when there is no travel on
    /// an axis, so maximizing then restoring never loses the saved location.
    public static func position(
        after translation: CGSize,
        from position: ScienceLabNormalizedPosition,
        panelSize: CGSize,
        in container: CGSize,
        inset: CGFloat = defaultInset
    ) -> ScienceLabNormalizedPosition {
        let bounds = availableBounds(in: container, inset: inset)
        let resolvedFrame = frame(at: position, panelSize: panelSize, in: container, translation: translation, inset: inset)
        let travelX = bounds.width - resolvedFrame.width
        let travelY = bounds.height - resolvedFrame.height
        return ScienceLabNormalizedPosition(
            x: travelX > 0 ? (resolvedFrame.minX - bounds.minX) / travelX : position.x,
            y: travelY > 0 ? (resolvedFrame.minY - bounds.minY) / travelY : position.y
        )
    }

    /// Chrome overlays the stage; no rows or outer margins consume its size.
    /// Input is the safe-area proposal supplied by the containing window.
    public static func layout(
        for availableSize: CGSize,
        accessibilitySize: Bool = false
    ) -> ScienceLabLayoutMetrics {
        let size = sanitized(availableSize)
        return ScienceLabLayoutMetrics(
            usesCompactChrome: true,
            horizontalPadding: 0,
            verticalPadding: 0,
            spacing: 0,
            headerHeight: 44,
            dockHeight: 48,
            stageHeight: size.height
        )
    }
}
