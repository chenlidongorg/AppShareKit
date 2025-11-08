import SwiftUI
import UIKit

struct AppShareButtonView: View {
    let payload: AppSharePayload
    let appearance: ShareButtonAppearance
    private let presenterReference: WeakPresenterReference
    private let imageCache = ShareImageCache.shared
    @State private var warmedImage: UIImage?
    @State private var warmedPayloadID: String?

    init(payload: AppSharePayload, appearance: ShareButtonAppearance, presenter: UIViewController?) {
        self.payload = payload
        self.appearance = appearance
        self.presenterReference = WeakPresenterReference(controller: presenter)
    }

    var body: some View {
        Button(action: share) {
            HStack(spacing: 8) {
                iconView
                Text(appearance.resolvedTitle)
                    .font(.headline)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .onAppear(perform: warmUpShareImage)
    }

    @ViewBuilder
    private var iconView: some View {
        if let custom = appearance.customImage {
            Image(uiImage: custom)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else if let systemName = appearance.iconSystemName {
            Image(systemName: systemName)
                .imageScale(.medium)
        }
    }

    private func share() {
        Task { @MainActor in
            let image = warmedImage ?? imageCache.preparedImage(for: payload)
            warmedImage = image
            AppShareKit.shareImmediately(
                payload: payload,
                presenter: presenterReference.controller,
                preparedImage: image
            )
        }
    }

    private func warmUpShareImage() {
        let identifier = payload.cacheIdentifier
        guard warmedPayloadID != identifier || warmedImage == nil else { return }
        warmedPayloadID = identifier

        if let cached = imageCache.cachedImageIfAvailable(for: payload) {
            warmedImage = cached
            return
        }

        imageCache.prepareImage(for: payload) { image in
            guard warmedPayloadID == identifier else { return }
            warmedImage = image
        }
    }
}

private final class WeakPresenterReference {
    weak var controller: UIViewController?

    init(controller: UIViewController?) {
        self.controller = controller
    }
}
