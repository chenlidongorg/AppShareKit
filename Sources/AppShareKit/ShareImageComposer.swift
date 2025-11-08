import UIKit

final class ShareImageComposer {
    private struct Layout {
        static let canvasSize = CGSize(width: 1024, height: 1400)
        static let cardInset: CGFloat = 64
        static let contentInset: CGFloat = 48
        static let logoSize: CGFloat = 180
        static let qrSize: CGFloat = 260
    }

    func composeImage(from payload: AppSharePayload, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let resolvedScale = scale > 0 ? scale : max(UIScreen.main.scale, 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = resolvedScale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: Layout.canvasSize, format: format)
        return renderer.image { context in
            drawBackground(in: context.cgContext, size: Layout.canvasSize)
            drawCard(in: context.cgContext, payload: payload)
        }
    }

    private func drawBackground(in context: CGContext, size: CGSize) {
        let colors = [
            UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1).cgColor,
            UIColor(red: 0.90, green: 0.94, blue: 1.0, alpha: 1).cgColor
        ]
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            return
        }
        let start = CGPoint(x: size.width / 2, y: 0)
        let end = CGPoint(x: size.width / 2, y: size.height)
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
    }

    private func drawCard(in context: CGContext, payload: AppSharePayload) {
        let cardRect = CGRect(
            x: Layout.cardInset,
            y: Layout.cardInset * 1.5,
            width: Layout.canvasSize.width - Layout.cardInset * 2,
            height: Layout.canvasSize.height - Layout.cardInset * 3
        )
        context.saveGState()
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 48)
        context.setShadow(offset: CGSize(width: 0, height: 24), blur: 48, color: UIColor.black.withAlphaComponent(0.08).cgColor)
        UIColor.white.setFill()
        path.fill()
        context.restoreGState()

        let contentRect = cardRect.insetBy(dx: Layout.contentInset, dy: Layout.contentInset)
        let footerStart = drawHeader(in: context, payload: payload, rect: contentRect)
        drawFooter(in: context, payload: payload, rect: contentRect, startY: footerStart + 32)
    }

    @discardableResult
    private func drawHeader(in context: CGContext, payload: AppSharePayload, rect: CGRect) -> CGFloat {
        var currentY = rect.minY
        var logoRect = CGRect(x: rect.minX, y: currentY, width: Layout.logoSize, height: Layout.logoSize)
        var hasLogo = false

        if let logo = payload.logo ?? placeholderLogo(for: payload) {
            draw(image: logo, in: logoRect, cornerRadius: 40)
            hasLogo = true
        }

        let textStartX = hasLogo ? logoRect.maxX + 32 : rect.minX
        let textWidth = rect.maxX - textStartX

        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 56, weight: .heavy),
            .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1)
        ]
        let promptAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .regular),
            .foregroundColor: UIColor(red: 0.23, green: 0.27, blue: 0.36, alpha: 1)
        ]

        let nameString = payload.sanitizedAppName as NSString
        let nameRect = CGRect(x: textStartX, y: currentY, width: textWidth, height: 70)
        nameString.draw(in: nameRect, withAttributes: nameAttributes)

        let promptString = payload.sanitizedPrompt as NSString
        let promptRect = CGRect(x: textStartX, y: nameRect.maxY + 12, width: textWidth, height: 160)
        promptString.draw(with: promptRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: promptAttributes, context: nil)

        let bottomY = max(hasLogo ? logoRect.maxY : rect.minY, promptRect.maxY)
        let separatorY = bottomY + 40
        let separatorRect = CGRect(x: rect.minX, y: separatorY, width: rect.width, height: 1)
        UIColor(white: 0.92, alpha: 1).setFill()
        UIBezierPath(rect: separatorRect).fill()
        return separatorRect.maxY
    }

    private func drawFooter(in context: CGContext, payload: AppSharePayload, rect: CGRect, startY: CGFloat) {
        let footerTop = min(max(startY, rect.minY), rect.maxY - Layout.qrSize - 40)
        let availableHeight = rect.maxY - footerTop
        let qrRect = CGRect(x: rect.maxX - Layout.qrSize, y: footerTop, width: Layout.qrSize, height: Layout.qrSize)
        let hasQRCode = payload.qrcode != nil
        if let qr = payload.qrcode {
            draw(image: qr, in: qrRect, cornerRadius: 24)
            drawQRCodeCaption(in: context, rect: qrRect)
        }

        let textWidth = hasQRCode ? qrRect.minX - rect.minX - 32 : rect.width
        let textRect = CGRect(x: rect.minX, y: footerTop, width: textWidth, height: availableHeight)

        let caption = "Official Link" as NSString
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: UIColor(red: 0.19, green: 0.24, blue: 0.36, alpha: 1)
        ]
        let captionSize = caption.size(withAttributes: captionAttributes)
        caption.draw(in: CGRect(x: textRect.minX, y: textRect.minY, width: captionSize.width, height: captionSize.height), withAttributes: captionAttributes)

        let urlAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 30, weight: .regular),
            .foregroundColor: UIColor(red: 0.15, green: 0.17, blue: 0.26, alpha: 1)
        ]
        let urlRect = CGRect(
            x: textRect.minX,
            y: textRect.minY + captionSize.height + 12,
            width: textRect.width,
            height: 200
        )
        (payload.sanitizedURL as NSString).draw(with: urlRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: urlAttributes, context: nil)

        if !hasQRCode {
            let hintAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor(red: 0.40, green: 0.44, blue: 0.56, alpha: 1)
            ]
            let hint = "Tip: Add a QR code to increase installs" as NSString
            let hintRect = CGRect(
                x: textRect.minX,
                y: urlRect.maxY + 24,
                width: textRect.width,
                height: 60
            )
            hint.draw(with: hintRect, options: [.usesLineFragmentOrigin], attributes: hintAttributes, context: nil)
        }
    }

    private func drawQRCodeCaption(in context: CGContext, rect: CGRect) {
        let label = "Scan to install" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.45, alpha: 1)
        ]
        let size = label.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.maxY + 12,
            width: size.width,
            height: size.height
        )
        label.draw(in: textRect, withAttributes: attributes)
    }

    private func draw(image: UIImage, in rect: CGRect, cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.addClip()
        let fittedRect = aspectFitRect(for: image.size, inside: rect)
        image.draw(in: fittedRect)
    }

    private func aspectFitRect(for size: CGSize, inside rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let widthRatio = rect.width / size.width
        let heightRatio = rect.height / size.height
        let scale = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: rect.midX - newSize.width / 2,
            y: rect.midY - newSize.height / 2
        )
        return CGRect(origin: origin, size: newSize)
    }

    private func placeholderLogo(for payload: AppSharePayload) -> UIImage? {
        guard payload.logo == nil else { return nil }
        let diameter = Layout.logoSize
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter), format: format)
        let initials = String(payload.sanitizedAppName.prefix(1)).uppercased()
        return renderer.image { _ in
            let circleRect = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
            UIBezierPath(ovalIn: circleRect).addClip()
            UIColor(red: 0.29, green: 0.34, blue: 0.98, alpha: 1).setFill()
            UIBezierPath(ovalIn: circleRect).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: diameter * 0.48, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let size = initials.size(withAttributes: attributes)
            let rect = CGRect(
                x: (diameter - size.width) / 2,
                y: (diameter - size.height) / 2,
                width: size.width,
                height: size.height
            )
            initials.draw(in: rect, withAttributes: attributes)
        }
    }
}
