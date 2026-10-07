import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Camera geometry only: a tool continues to render and measure in its original
/// stage coordinates. No scientific dimensions or values are rescaled.
public struct ScienceLabViewportState: Equatable {
    public static let minimumScale: CGFloat = 0.6
    public static let maximumScale: CGFloat = 3
    public private(set) var size: CGSize
    public private(set) var scale: CGFloat
    public private(set) var offset: CGSize

    public init(size: CGSize, scale: CGFloat = 1, offset: CGSize = .zero) {
        self.size = ScienceLabGeometry.sanitized(size)
        self.scale = min(Self.maximumScale, max(Self.minimumScale, scale.isFinite ? scale : 1))
        self.offset = Self.clamped(offset, size: self.size, scale: self.scale)
    }

    /// The content underneath the first centroid stays underneath the current
    /// centroid, except at a boundary. At or below full size, center the whole
    /// stage so zooming out cannot push any part of it offscreen.
    public func transformed(scaleFactor: CGFloat, from initialCentroid: CGPoint, to centroid: CGPoint) -> Self {
        guard scaleFactor.isFinite, scaleFactor > 0,
              initialCentroid.x.isFinite, initialCentroid.y.isFinite,
              centroid.x.isFinite, centroid.y.isFinite else { return self }
        let requestedScale = scale * scaleFactor
        let nextScale = min(Self.maximumScale, max(Self.minimumScale,
                                                  requestedScale.isFinite ? requestedScale : Self.maximumScale))
        let ratio = nextScale / scale
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return Self(size: size, scale: nextScale, offset: CGSize(
            width: centroid.x - center.x - ratio * (initialCentroid.x - center.x - offset.width),
            height: centroid.y - center.y - ratio * (initialCentroid.y - center.y - offset.height)
        ))
    }

    public func resized(to size: CGSize) -> Self {
        let newSize = ScienceLabGeometry.sanitized(size)
        return Self(size: newSize, scale: scale,
                    offset: CGSize(width: self.size.width > 0 ? offset.width / self.size.width * newSize.width : 0,
                                   height: self.size.height > 0 ? offset.height / self.size.height * newSize.height : 0))
    }

    public func contentPoint(fromViewport point: CGPoint) -> CGPoint {
        CGPoint(x: size.width / 2 + (point.x - size.width / 2 - offset.width) / scale,
                y: size.height / 2 + (point.y - size.height / 2 - offset.height) / scale)
    }

    public func viewportPoint(fromContent point: CGPoint) -> CGPoint {
        CGPoint(x: size.width / 2 + scale * (point.x - size.width / 2) + offset.width,
                y: size.height / 2 + scale * (point.y - size.height / 2) + offset.height)
    }

    public var accessibilityValue: String {
        // POSIX avoids locale-dependent commas; these are camera diagnostics,
        // not a new visual HUD or scientific data output.
        String(format: "{\"scale\":%.3f,\"offsetX\":%.3f,\"offsetY\":%.3f}",
               locale: Locale(identifier: "en_US_POSIX"), Double(scale), Double(offset.width), Double(offset.height))
    }

    private static func clamped(_ offset: CGSize, size: CGSize, scale: CGFloat) -> CGSize {
        let xLimit = size.width * max(0, scale - 1) / 2
        let yLimit = size.height * max(0, scale - 1) / 2
        return CGSize(width: min(xLimit, max(-xLimit, offset.width.isFinite ? offset.width : 0)),
                      height: min(yLimit, max(-yLimit, offset.height.isFinite ? offset.height : 0)))
    }
}

/// One baseline serves simultaneous pinch and translation. In particular,
/// centroid movement is applied once, never once for each recognizer.
struct ScienceLabViewportGestureState {
    private(set) var viewport: ScienceLabViewportState
    private var baseline: ScienceLabViewportState?
    private var centroid: CGPoint = .zero
    var isInteracting: Bool { baseline != nil }

    init(viewport: ScienceLabViewportState) { self.viewport = viewport }

    mutating func begin(at centroid: CGPoint) {
        guard !isInteracting, centroid.x.isFinite, centroid.y.isFinite else { return }
        baseline = viewport
        self.centroid = centroid
    }

    mutating func update(scaleFactor: CGFloat, centroid: CGPoint) {
        guard let baseline else { return }
        viewport = baseline.transformed(scaleFactor: scaleFactor, from: self.centroid, to: centroid)
    }

    mutating func finish() { baseline = nil }

    mutating func cancel() {
        if let baseline { viewport = baseline }
        baseline = nil
    }

    mutating func resize(to size: CGSize) {
        cancel()
        viewport = viewport.resized(to: size)
    }

    mutating func reset() {
        baseline = nil
        viewport = ScienceLabViewportState(size: viewport.size)
    }
}
