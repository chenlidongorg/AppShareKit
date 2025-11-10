import SwiftUI
import UIKit

/// Public entry for performing promotion shares.
public enum AppShareKit {
    private static let shareImageCache = ShareImageCache.shared

    /// Generates a promotion image and either shares it immediately or returns a ready-to-use SwiftUI button.
    /// - Note: Passing any of the share button parameters will return a button view. Otherwise the share sheet appears immediately.
    @MainActor
    @discardableResult
    public static func appshare(
        appName: String? = nil,
        prompt: String? = nil,
        logo: UIImage? = nil,
        qrcode: UIImage? = nil,
        officeURL: String? = nil,
        contentImage: UIImage? = nil,
        shareButtonIcon: String? = nil,
        shareButtonImage: UIImage? = nil,
        shareButtonName: String? = nil,
        presenter: UIViewController? = nil
    ) -> AnyView {
        let payload = AppSharePayload(
            appName: appName,
            prompt: prompt,
            logo: logo,
            qrcode: qrcode,
            officeURL: officeURL,
            contentImage: contentImage
        )
        let appearance = ShareButtonAppearance(
            iconSystemName: shareButtonIcon,
            customImage: shareButtonImage,
            title: shareButtonName
        )

        if appearance.isEmpty {
            shareImmediately(payload: payload, presenter: presenter)
            return AnyView(EmptyView())
        } else {
            return AnyView(
                AppShareButtonView(
                    payload: payload,
                    appearance: appearance,
                    presenter: presenter
                )
            )
        }
    }

    @MainActor
    static func shareImmediately(payload: AppSharePayload, presenter: UIViewController?, preparedImage: UIImage? = nil) {
        let image = preparedImage ?? shareImageCache.preparedImage(for: payload)
        let activityItems: [Any] = [image]
        let shareController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        shareController.excludedActivityTypes = [.assignToContact]

        guard let topController = PresenterResolver.resolveTopController(from: presenter) else {
            assertionFailure("AppShareKit: Unable to find a presenter for UIActivityViewController.")
            return
        }

        if let popover = shareController.popoverPresentationController, popover.sourceView == nil {
            popover.sourceView = presenter?.view ?? topController.view
            popover.sourceRect = CGRect(
                x: popover.sourceView?.bounds.midX ?? 0,
                y: popover.sourceView?.bounds.midY ?? 0,
                width: 0,
                height: 0
            )
        }

        topController.present(shareController, animated: true)
    }
}
