#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// Reports only the portion of the current native window's safe area that
/// intersects this shell. A parent's ignoresSafeArea must not move controls
/// into system regions; the experiment itself still uses the full stage.
@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabNativeSafeArea: UIViewRepresentable {
    let onChange: (EdgeInsets) -> Void

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        view.onChange = onChange
        view.report()
    }

    final class Probe: UIView {
        var onChange: ((EdgeInsets) -> Void)?
        private var reported: UIEdgeInsets?

        override func didMoveToWindow() { super.didMoveToWindow(); report() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); report() }
        override func layoutSubviews() { super.layoutSubviews(); report() }

        func report() {
            guard window != nil, bounds.width > 0, bounds.height > 0 else { return }
            let insets = safeAreaInsets
            guard reported != insets else { return }
            reported = insets
            // Native layout callbacks can occur while SwiftUI builds its
            // graph. Publish after that transaction and reject stale values.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, self.reported == insets else { return }
                self.onChange?(EdgeInsets(top: insets.top, leading: insets.left,
                                          bottom: insets.bottom, trailing: insets.right))
            }
        }
    }
}
#endif
