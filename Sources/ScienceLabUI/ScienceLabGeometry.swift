import Foundation

/// Presentation state is independent of any scientific model or SwiftUI view.
public enum ScienceLabReadoutMode: String, CaseIterable {
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

/// Pure geometry, intentionally kept free of SwiftUI and screen-singleton APIs.
public enum ScienceLabGeometry {
    public static let defaultInset: CGFloat = 10
    public static let readoutHeaderHeight: CGFloat = 48

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
        switch mode {
        case .minimized:
            return CGSize(width: min(224, bounds.width), height: min(readoutHeaderHeight, bounds.height))
        case .expanded:
            // The ordinary panel leaves most of the simulation available.
            // Larger Dynamic Type uses more space, with a scrolling body.
            let preferredWidth: CGFloat = accessibilitySize ? 360 : 304
            let heightFraction: CGFloat = accessibilitySize ? 0.72 : 0.52
            let preferredHeight: CGFloat = accessibilitySize ? 360 : 244
            return CGSize(
                width: min(preferredWidth, bounds.width),
                height: min(bounds.height, max(min(readoutHeaderHeight, bounds.height),
                    min(preferredHeight, bounds.height * heightFraction)))
            )
        case .maximized:
            return bounds.size
        }
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

    /// Reserve only compact chrome; common controls live in a sheet, never in
    /// an oversized panel below the stage. Input is the safe-area proposal.
    public static func layout(
        for availableSize: CGSize,
        accessibilitySize: Bool = false
    ) -> ScienceLabLayoutMetrics {
        let size = sanitized(availableSize)
        let compact = size.height < 420 || accessibilitySize
        let verticalPadding: CGFloat = compact ? 4 : 8
        let spacing: CGFloat = compact ? 4 : 8
        let headerHeight: CGFloat = 48
        let dockHeight: CGFloat = compact ? 52 : 60
        let chromeHeight = 2 * verticalPadding + 2 * spacing + headerHeight + dockHeight
        return ScienceLabLayoutMetrics(
            usesCompactChrome: compact,
            horizontalPadding: size.width < 400 ? 10 : 16,
            verticalPadding: verticalPadding,
            spacing: spacing,
            headerHeight: headerHeight,
            dockHeight: dockHeight,
            stageHeight: max(0, size.height - chromeHeight)
        )
    }
}
