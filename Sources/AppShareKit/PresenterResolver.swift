import UIKit

enum PresenterResolver {
    @MainActor
    static func resolveTopController(from controller: UIViewController?) -> UIViewController? {
        if let controller {
            return topViewController(from: controller)
        }

        let connectedScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { lhs, rhs in
                lhs.activationState.rawValue > rhs.activationState.rawValue
            }

        for scene in connectedScenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }),
               let root = window.rootViewController {
                return topViewController(from: root)
            }
        }

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
           let root = window.rootViewController {
            return topViewController(from: root)
        }

        return nil
    }

    private static func topViewController(from base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(from: presented)
        }
        return base
    }
}
