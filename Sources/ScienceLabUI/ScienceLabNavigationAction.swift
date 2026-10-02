#if canImport(SwiftUI)
import SwiftUI

/// The host supplies its existing dismissal action so navigation shares the
/// stage's chrome layer rather than consuming a separate row above the canvas.
@available(iOS 15.0, macCatalyst 15.0, *)
public struct ScienceLabNavigationAction {
    public let isBack: Bool
    public let onDismiss: () -> Void

    public init(isBack: Bool = false, onDismiss: @escaping () -> Void) {
        self.isBack = isBack
        self.onDismiss = onDismiss
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
private struct ScienceLabNavigationActionKey: EnvironmentKey {
    static var defaultValue: ScienceLabNavigationAction? { nil }
}

@available(iOS 15.0, macCatalyst 15.0, *)
public extension EnvironmentValues {
    var scienceLabNavigationAction: ScienceLabNavigationAction? {
        get { self[ScienceLabNavigationActionKey.self] }
        set { self[ScienceLabNavigationActionKey.self] = newValue }
    }
}
#endif
