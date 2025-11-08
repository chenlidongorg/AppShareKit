import UIKit

struct AppSharePayload {
    let appName: String?
    let prompt: String?
    let logo: UIImage?
    let qrcode: UIImage?
    let officeURL: String?

    var sanitizedAppName: String {
        appName?.trimmedNonEmpty ?? "Your App"
    }

    var sanitizedPrompt: String {
        prompt?.trimmedNonEmpty ?? "Share-worthy features packed inside."
    }

    var sanitizedURL: String {
        officeURL?.trimmedNonEmpty ?? "Scan the QR code to install."
    }
}

struct ShareButtonAppearance {
    let iconSystemName: String?
    let customImage: UIImage?
    let title: String?

    var resolvedTitle: String {
        title?.trimmedNonEmpty ?? "Share Now"
    }

    var isEmpty: Bool {
        iconSystemName == nil && customImage == nil && title == nil
    }
}

extension Optional where Wrapped == String {
    fileprivate var trimmedNonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
