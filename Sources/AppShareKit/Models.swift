import CryptoKit
import UIKit

struct AppSharePayload {
    let appName: String?
    let prompt: String?
    let logo: UIImage?
    let qrcode: UIImage?
    let officeURL: String?
    let contentImage: UIImage?

    var sanitizedAppName: String {
        appName?.trimmedNonEmpty ?? "Your App"
    }

    var sanitizedPrompt: String {
        prompt?.trimmedNonEmpty ?? "Share-worthy features packed inside."
    }

    var sanitizedURL: String {
        officeURL?.trimmedNonEmpty ?? "Scan the QR code to install."
    }

    var cacheIdentifier: String {
        let components = [
            sanitizedAppName,
            sanitizedPrompt,
            sanitizedURL,
            logo?.pngData()?.sha256Hex ?? "no-logo",
            qrcode?.pngData()?.sha256Hex ?? "no-qr",
            contentImage?.pngData()?.sha256Hex ?? "no-content"
        ]
        return components.joined(separator: "|").sha256Hex
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

extension String {
    fileprivate var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        return value
    }

    fileprivate var sha256Hex: String {
        Data(utf8).sha256Hex
    }
}

private extension Data {
    var sha256Hex: String {
        let digest = SHA256.hash(data: self)
        return digest.reduce(into: "") { partialResult, byte in
            partialResult += String(format: "%02x", byte)
        }
    }
}
