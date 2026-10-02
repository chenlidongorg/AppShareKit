#if canImport(UIKit) && canImport(SwiftUI)
import UIKit
import ObjectiveC

@MainActor
private enum ScienceLabExportAppearanceStorage {
    static var key: UInt8 = 0
}

@available(iOS 15.0, macCatalyst 15.0, *)
public extension UIImage {
    /// Presentation intent travels with the original image through existing
    /// UIImage callbacks. It never modifies the scientific PNG pixels.
    @MainActor
    var scienceLabExportAppearance: ScienceLabAppearance {
        get {
            (objc_getAssociatedObject(self, &ScienceLabExportAppearanceStorage.key) as? NSNumber)?.boolValue == true ? .dark : .system
        }
        set {
            objc_setAssociatedObject(self, &ScienceLabExportAppearanceStorage.key,
                                     NSNumber(value: newValue == .dark), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
#endif
