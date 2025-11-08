import UIKit

final class ShareImageComposer {
    private struct Layout {
        static let canvasWidth: CGFloat = 1024
        static let cardInset: CGFloat = 64
        static let contentInset: CGFloat = 48
        static let logoSize: CGFloat = 180
        static let qrSize: CGFloat = 260
        static let columnSpacing: CGFloat = 32
        static let headerTextSpacing: CGFloat = 12
        static let headerSeparatorSpacing: CGFloat = 40
        static let sectionSpacing: CGFloat = 32
        static let hintSpacing: CGFloat = 24
        static let separatorHeight: CGFloat = 1
    }

    private struct ResolvedLayout {
        let canvasSize: CGSize
        let cardRect: CGRect
        let contentRect: CGRect
    }

    private enum Typography {
        static let nameFont = UIFont.systemFont(ofSize: 56, weight: .heavy)
        static let promptFont = UIFont.systemFont(ofSize: 32, weight: .regular)
        static let urlFont = UIFont.monospacedSystemFont(ofSize: 30, weight: .regular)
        static let hintFont = UIFont.systemFont(ofSize: 24, weight: .regular)

        static var nameAttributes: [NSAttributedString.Key: Any] {
            [
                .font: nameFont,
                .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1)
            ]
        }

        static var promptAttributes: [NSAttributedString.Key: Any] {
            [
                .font: promptFont,
                .foregroundColor: UIColor(red: 0.23, green: 0.27, blue: 0.36, alpha: 1)
            ]
        }

        static var urlAttributes: [NSAttributedString.Key: Any] {
            [
                .font: urlFont,
                .foregroundColor: UIColor(red: 0.15, green: 0.17, blue: 0.26, alpha: 1)
            ]
        }

        static var hintAttributes: [NSAttributedString.Key: Any] {
            [
                .font: hintFont,
                .foregroundColor: UIColor(red: 0.40, green: 0.44, blue: 0.56, alpha: 1)
            ]
        }
    }

    private enum Copy {
        static let qrHint = "Tip: Add a QR code to increase installs"
    }

    func composeImage(from payload: AppSharePayload, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let resolvedScale = scale > 0 ? scale : max(UIScreen.main.scale, 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = resolvedScale
        format.opaque = false

        let resolvedLogo = payload.logo ?? placeholderLogo(for: payload)
        let layout = resolveLayout(for: payload, logo: resolvedLogo)
        let renderer = UIGraphicsImageRenderer(size: layout.canvasSize, format: format)
        return renderer.image { context in
            drawBackground(in: context.cgContext, size: layout.canvasSize)
            drawCard(in: context.cgContext, payload: payload, layout: layout, logo: resolvedLogo)
        }
    }

    private func resolveLayout(for payload: AppSharePayload, logo: UIImage?) -> ResolvedLayout {
        let cardWidth = Layout.canvasWidth - Layout.cardInset * 2
        let contentWidth = max(cardWidth - Layout.contentInset * 2, 0)
        let headerHeight = measureHeaderHeight(for: payload, contentWidth: contentWidth, logo: logo)
        let footerHeight = measureFooterHeight(for: payload, contentWidth: contentWidth)
        let contentHeight = headerHeight + Layout.sectionSpacing + footerHeight
        let cardHeight = Layout.contentInset * 2 + contentHeight
        let canvasHeight = cardHeight + Layout.cardInset * 3
        let canvasSize = CGSize(width: Layout.canvasWidth, height: canvasHeight)
        let cardRect = CGRect(
            x: Layout.cardInset,
            y: Layout.cardInset * 1.5,
            width: cardWidth,
            height: cardHeight
        )
        let contentRect = cardRect.insetBy(dx: Layout.contentInset, dy: Layout.contentInset)
        return ResolvedLayout(canvasSize: canvasSize, cardRect: cardRect, contentRect: contentRect)
    }

    private func measureHeaderHeight(for payload: AppSharePayload, contentWidth: CGFloat, logo: UIImage?) -> CGFloat {
        guard contentWidth > 0 else { return Layout.logoSize + Layout.headerSeparatorSpacing + Layout.separatorHeight }
        let hasLogo = logo != nil
        let textStartX = hasLogo ? Layout.logoSize + Layout.columnSpacing : 0
        let textWidth = max(contentWidth - textStartX, 0)
        let nameString = payload.sanitizedAppName as NSString
        let nameHeight = ceil(nameString.size(withAttributes: Typography.nameAttributes).height)
        let promptHeight = boundingHeight(
            for: payload.sanitizedPrompt,
            width: textWidth,
            attributes: Typography.promptAttributes
        )
        let textBlockHeight = nameHeight + (promptHeight > 0 ? Layout.headerTextSpacing + promptHeight : 0)
        let logoHeight = hasLogo ? Layout.logoSize : 0
        let headerContentHeight = max(textBlockHeight, logoHeight)
        return headerContentHeight + Layout.headerSeparatorSpacing + Layout.separatorHeight
    }

    private func measureFooterHeight(for payload: AppSharePayload, contentWidth: CGFloat) -> CGFloat {
        guard contentWidth > 0 else { return Layout.qrSize }
        let hasQRCode = payload.qrcode != nil
        let textWidth = hasQRCode ? max(contentWidth - Layout.qrSize - Layout.columnSpacing, 0) : contentWidth
        let urlHeight = boundingHeight(
            for: payload.sanitizedURL,
            width: textWidth,
            attributes: Typography.urlAttributes
        )
        var textBlockHeight = urlHeight
        if !hasQRCode {
            let hintHeight = boundingHeight(
                for: Copy.qrHint,
                width: textWidth,
                attributes: Typography.hintAttributes
            )
            if hintHeight > 0 {
                textBlockHeight += Layout.hintSpacing + hintHeight
            }
        }
        let qrBlockHeight = hasQRCode ? Layout.qrSize : 0
        return max(textBlockHeight, qrBlockHeight)
    }

    private func boundingHeight(for string: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        guard !string.isEmpty, width > 0 else { return 0 }
        let rect = (string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(rect.height)
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

    private func drawCard(in context: CGContext, payload: AppSharePayload, layout: ResolvedLayout, logo: UIImage?) {
        let cardRect = layout.cardRect
        context.saveGState() // isolate the clip so later drawing isn't limited to this image
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 48)
        context.setShadow(offset: CGSize(width: 0, height: 24), blur: 48, color: UIColor.black.withAlphaComponent(0.08).cgColor)
        UIColor.white.setFill()
        path.fill()
        context.restoreGState()

        let contentRect = layout.contentRect
        let footerStart = drawHeader(in: context, payload: payload, rect: contentRect, logo: logo)
        drawFooter(in: context, payload: payload, rect: contentRect, startY: footerStart + Layout.sectionSpacing)
    }

    @discardableResult
    private func drawHeader(in context: CGContext, payload: AppSharePayload, rect: CGRect, logo: UIImage?) -> CGFloat {
        let currentY = rect.minY
        var textStartX = rect.minX
        var logoBottomY = currentY

        if let logo = logo {
            let logoRect = CGRect(x: rect.minX, y: currentY, width: Layout.logoSize, height: Layout.logoSize)
            draw(image: logo, in: logoRect, cornerRadius: 40)
            textStartX = logoRect.maxX + Layout.columnSpacing
            logoBottomY = logoRect.maxY
        }

        let textWidth = max(rect.maxX - textStartX, 0)
        let nameString = payload.sanitizedAppName as NSString
        let nameSize = nameString.size(withAttributes: Typography.nameAttributes)
        let nameHeight = ceil(nameSize.height)
        let nameRect = CGRect(x: textStartX, y: currentY, width: textWidth, height: nameHeight)
        nameString.draw(in: nameRect, withAttributes: Typography.nameAttributes)

        let promptString = payload.sanitizedPrompt as NSString
        let promptHeight = boundingHeight(
            for: payload.sanitizedPrompt,
            width: textWidth,
            attributes: Typography.promptAttributes
        )
        var textBottomY = nameRect.maxY
        if promptHeight > 0 {
            let promptRect = CGRect(
                x: textStartX,
                y: nameRect.maxY + Layout.headerTextSpacing,
                width: textWidth,
                height: promptHeight
            )
            promptString.draw(
                with: promptRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: Typography.promptAttributes,
                context: nil
            )
            textBottomY = promptRect.maxY
        }

        let contentBottom = max(logoBottomY, textBottomY)
        let separatorY = contentBottom + Layout.headerSeparatorSpacing
        let separatorRect = CGRect(x: rect.minX, y: separatorY, width: rect.width, height: Layout.separatorHeight)
        UIColor(white: 0.92, alpha: 1).setFill()
        UIBezierPath(rect: separatorRect).fill()
        return separatorRect.maxY
    }

    private func drawFooter(in context: CGContext, payload: AppSharePayload, rect: CGRect, startY: CGFloat) {
        let footerTop = max(startY, rect.minY)
        let hasQRCode = payload.qrcode != nil
        let qrRect = CGRect(x: rect.maxX - Layout.qrSize, y: footerTop, width: Layout.qrSize, height: Layout.qrSize)
        if let qr = payload.qrcode {
            draw(image: qr, in: qrRect, cornerRadius: 24)
        }

        let textWidth = hasQRCode ? max(qrRect.minX - rect.minX - Layout.columnSpacing, 0) : rect.width
        var currentY = footerTop
        let urlHeight = boundingHeight(
            for: payload.sanitizedURL,
            width: textWidth,
            attributes: Typography.urlAttributes
        )
        if urlHeight > 0 {
            let urlRect = CGRect(x: rect.minX, y: currentY, width: textWidth, height: urlHeight)
            (payload.sanitizedURL as NSString).draw(
                with: urlRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: Typography.urlAttributes,
                context: nil
            )
            currentY = urlRect.maxY
        }

        if !hasQRCode {
            let hintHeight = boundingHeight(
                for: Copy.qrHint,
                width: textWidth,
                attributes: Typography.hintAttributes
            )
            if hintHeight > 0 {
                let hint = Copy.qrHint as NSString
                let hintRect = CGRect(
                    x: rect.minX,
                    y: currentY + Layout.hintSpacing,
                    width: textWidth,
                    height: hintHeight
                )
                hint.draw(
                    with: hintRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: Typography.hintAttributes,
                    context: nil
                )
            }
        }
    }

    private func draw(image: UIImage, in rect: CGRect, cornerRadius: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else {
            image.draw(in: rect)
            return
        }
        context.saveGState() // limit clipping to this draw call so the rest of the canvas is unaffected
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.addClip()
        let fittedRect = aspectFitRect(for: image.size, inside: rect)
        image.draw(in: fittedRect)
        context.restoreGState()
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
