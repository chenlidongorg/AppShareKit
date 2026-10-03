#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
public enum ScienceLabExportPresenter {
    private final class Presentation {
        weak var controller: UIViewController?
        init(_ controller: UIViewController) { self.controller = controller }
    }
    private static var active: [ObjectIdentifier: Presentation] = [:]

    /// Opens one preview in the originating foreground window. The host owns
    /// photo-library permissions and reports save completion through onSave.
    @discardableResult
    public static func present(image: UIImage, title: String, presenter: UIViewController? = nil,
                               onSave: ScienceLabExportSaveHandler? = nil) -> Bool {
        guard let source = foregroundPresenter(preferred: presenter), let window = source.view.window,
              !source.isBeingPresented, !source.isBeingDismissed else { return false }
        let key = ObjectIdentifier(window)
        guard active[key]?.controller == nil else { return false }
        let session = ScienceLabExportSession(image: image, title: title, onSave: onSave)
        let controller = makeController(session: session)
        controller.modalPresentationStyle = .formSheet
        controller.onClosed = { active[key] = nil }
        active[key] = Presentation(controller)
        source.present(controller, animated: true)
        controller.presentationController?.delegate = controller
        return true
    }

    /// This is also exercised by native UIKit tests without fabricating a
    /// foreground scene or claiming a presentation that never occurred.
    static func makeController(session: ScienceLabExportSession) -> ScienceLabExportHostingController {
        let controller = ScienceLabExportHostingController(session: session)
        controller.overrideUserInterfaceStyle = session.appearance == .dark ? .dark : .unspecified
        return controller
    }

    private static func foregroundPresenter(preferred: UIViewController?) -> UIViewController? {
        if let preferred, let scene = preferred.view.window?.windowScene, scene.activationState == .foregroundActive {
            return topController(preferred)
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        for scene in scenes {
            if let root = scene.windows.first(where: { $0.isKeyWindow && !$0.isHidden })?.rootViewController {
                return topController(root)
            }
        }
        return nil
    }

    private static func topController(_ controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed { return topController(presented) }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController { return topController(visible) }
        if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController { return topController(selected) }
        return controller
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabExportHostingController: UIHostingController<ScienceLabExportPreview>, UIAdaptivePresentationControllerDelegate {
    private let session: ScienceLabExportSession
    var onClosed: (() -> Void)?
    private var didClose = false
    private var activityDelegate: ScienceLabActivityDismissalDelegate?
    private var activityToken: UUID?

    init(session: ScienceLabExportSession) {
        self.session = session
        super.init(rootView: ScienceLabExportPreview(session: session))
        rootView.onCancel = { [weak self] in self?.close() }
        rootView.onShare = { [weak self] in self?.share() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { cleanup() }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { cleanup() }
    }

    private func close() {
        session.cancel()
        dismiss(animated: true) { [weak self] in self?.cleanup() }
    }

    private func cleanup() {
        guard !didClose else { return }
        didClose = true
        activityToken = nil
        activityDelegate = nil
        session.cancel()
        onClosed?()
        onClosed = nil
    }

    private func share() {
        guard presentedViewController == nil, let url = session.beginShare() else { return }
        let token = UUID()
        activityToken = token
        let delegate = ScienceLabActivityDismissalDelegate { [weak self] completed, error in
            guard let self, self.activityToken == token, !self.didClose else { return }
            self.activityToken = nil
            self.activityDelegate = nil
            self.session.finishShare(completed: completed, error: error)
        }
        activityDelegate = delegate
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        if let popover = controller.popoverPresentationController {
            popover.sourceView = view
            let bounds = view.bounds
            popover.sourceRect = CGRect(x: max(0, min(bounds.width - 1, bounds.midX)),
                                        y: max(0, min(bounds.height - 1, bounds.height - 72)), width: 1, height: 1)
            popover.permittedArrowDirections = [.up, .down]
            popover.delegate = delegate
        }
        controller.completionWithItemsHandler = { [weak delegate] _, completed, _, error in
            Task { @MainActor in delegate?.complete(completed: completed, error: error) }
        }
        present(controller, animated: true)
        controller.presentationController?.delegate = delegate
    }
}

/// UIKit's interactive sheet/popover cancellation also ends the share attempt.
/// This delegate belongs to the activity, never the enclosing preview: cancelling
/// the system sheet must leave the preview and its prepared file available.
@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class ScienceLabActivityDismissalDelegate: NSObject, UIAdaptivePresentationControllerDelegate, UIPopoverPresentationControllerDelegate {
    private var completion: ((Bool, Error?) -> Void)?

    init(completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
    }

    func complete(completed: Bool, error: Error?) {
        guard let completion else { return }
        self.completion = nil
        completion(completed, error)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { cancelled() }
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) { cancelled() }

    private func cancelled() {
        // Let UIKit's activity result win when it arrives alongside dismissal.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.complete(completed: false, error: nil)
        }
    }
}

@available(iOS 15.0, macCatalyst 15.0, *)
struct ScienceLabExportPreview: View {
    @ObservedObject var session: ScienceLabExportSession
    var onCancel: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(uiImage: session.previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .accessibilityLabel(Text(session.title))
                            .accessibilityIdentifier("scienceLab.export.image")
                        if let file = session.file {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.url.lastPathComponent).font(.headline)
                                Text("PNG · \(file.pixelWidth) × \(file.pixelHeight) px · \(ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("scienceLab.export.file")
                        }
                    }
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
                .accessibilityIdentifier("scienceLab.export.report")
                Divider()
                actionDock
            }
            .navigationTitle(label("export.preview", "Export preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(label("export.cancel", "Cancel"), action: onCancel)
                        .accessibilityIdentifier("scienceLab.export.cancel")
                }
            }
        }
        .navigationViewStyle(.stack)
        .task { await session.prepareForPreview() }
        .accessibilityIdentifier("scienceLab.export.preview")
    }

    // The scientific report can contain thousands of rows. Its content scrolls
    // independently; export actions and operation/retry feedback stay reachable.
    private var actionDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            status
            Button(action: onShare) {
                Label(label("export.share", "Share PNG"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canAct)
            .accessibilityIdentifier("scienceLab.export.share")
            Button { session.save() } label: {
                Label(label("export.save", "Save image"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(!session.canSave)
            .accessibilityIdentifier("scienceLab.export.save")
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .accessibilityIdentifier("scienceLab.export.actions")
    }

    @ViewBuilder private var status: some View {
        switch session.phase {
        case .processing(let operation):
            ProgressView(operation == .save ? label("export.saving", "Saving image…") : label("export.preparing", "Preparing PNG…"))
                .accessibilityIdentifier("scienceLab.export.processing")
        case .success(let operation):
            Label(operation == .save ? label("export.saved", "Image saved") : label("export.shared", "Image shared"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityIdentifier("scienceLab.export.success")
        case .failed(_, let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(label("export.failed", "Export could not be completed"), systemImage: "exclamationmark.triangle")
                Text(message).font(.footnote)
                Button(label("export.retry", "Retry")) {
                    Task {
                        let wasShareFailure: Bool
                        if case .failed(.share, _) = session.phase { wasShareFailure = true } else { wasShareFailure = false }
                        await session.retry()
                        if wasShareFailure { onShare() }
                    }
                }
                .accessibilityIdentifier("scienceLab.export.retry")
            }
            .accessibilityIdentifier("scienceLab.export.failed")
        default: EmptyView()
        }
    }

    private func label(_ key: String, _ fallback: String) -> String { ScienceLabExportLabels.text(key, fallback) }
}
#endif
