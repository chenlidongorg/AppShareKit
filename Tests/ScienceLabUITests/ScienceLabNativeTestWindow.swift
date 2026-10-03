#if canImport(UIKit)
import UIKit

@MainActor
final class ScienceLabTestAppearanceController: UIViewController {
    let content: UIViewController
    private(set) var nativeDidAppear = false
    init(content: UIViewController) { self.content = content; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(content)
        content.view.frame = view.bounds
        content.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(content.view)
        content.didMove(toParent: self)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nativeDidAppear = true
    }
}
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabTestHostingController<Content: View>: UIHostingController<Content> {
    private(set) var nativeDidAppear = false
    override init(rootView: Content) { super.init(rootView: rootView) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nativeDidAppear = true
    }
}
#endif

// Native app-hosted fixtures must attach to the actual scene. Keep the
// scene-less path for SwiftPM's original generic XCTest process.
@MainActor
func scienceLabTestWindow(frame: CGRect) -> UIWindow {
    if #available(iOS 13.0, macCatalyst 13.0, *),
       let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        return window
    }
    return UIWindow(frame: frame)
}
#endif
