#if canImport(SwiftUI)
import SwiftUI

/// Synchronous cancellation contract for scientific single-finger gestures.
/// A cancellation must never be interpreted as releasing an experimental object.
@available(iOS 15.0, macCatalyst 15.0, *)
public final class ScienceLabStageInteraction: ObservableObject {
    @Published public private(set) var isViewportManipulating = false
    @Published public private(set) var cancellationGeneration: UInt = 0
    private var isEndingStageLifetime = false

    /// Read synchronously by scientific drag handlers. Teardown closes this
    /// gate without publishing into the SwiftUI graph being dismantled.
    public var canReleaseObject: Bool {
        !isViewportManipulating && !isEndingStageLifetime
    }

    func beginViewportInteraction() {
        guard canReleaseObject else { return }
        isViewportManipulating = true
        invalidateObjectInteraction()
    }

    func finishViewportInteraction() {
        if isViewportManipulating { isViewportManipulating = false }
    }

    func preventObjectRelease() { isEndingStageLifetime = true }

    func invalidateObjectInteraction() { cancellationGeneration &+= 1 }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct ScienceLabStageInteractionKey: EnvironmentKey {
    static let defaultValue = ScienceLabStageInteraction()
}

@available(iOS 15.0, macCatalyst 15.0, *)
public extension EnvironmentValues {
    var scienceLabStageInteraction: ScienceLabStageInteraction {
        get { self[ScienceLabStageInteractionKey.self] }
        set { self[ScienceLabStageInteractionKey.self] = newValue }
    }
}
#endif
