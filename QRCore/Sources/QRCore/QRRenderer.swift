import CoreGraphics
import UIKit

public enum QRRenderer {
    /// Renders the styled code to a bitmap `pixelSize` wide (taller when a
    /// frame banner is present).
    public static func render(matrix: QRMatrix, design: QRDesign, pixelSize: CGFloat) -> UIImage {
        let layout = QRLayout(matrix: matrix, design: design)
        let metrics = FrameMetrics(layoutTotal: layout.total, hasFrame: design.frame != nil)
        let scale = pixelSize / metrics.canvasSize.width
        let imageSize = CGSize(width: pixelSize, height: pixelSize * metrics.canvasSize.height / metrics.canvasSize.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

        return renderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            ctx.scaleBy(x: scale, y: scale)

            if design.background.alpha > 0 {
                ctx.setFillColor(design.background.cgColor)
                let canvas = CGRect(origin: .zero, size: metrics.canvasSize)
                if design.frame != nil {
                    // Round the background to the frame border's outer edge so
                    // no square corners poke out past the rounded frame.
                    let r = FrameMetrics.cornerRadius + FrameMetrics.strokeWidth / 2
                    ctx.addPath(CGPath(roundedRect: canvas, cornerWidth: r, cornerHeight: r, transform: nil))
                    ctx.fillPath()
                } else {
                    ctx.fill(canvas)
                }
            }

            ctx.saveGState()
            ctx.translateBy(x: metrics.codeOrigin.x, y: metrics.codeOrigin.y)
            let fullRect = CGRect(x: 0, y: 0, width: layout.total, height: layout.total)

            // Data modules
            let modulesPath = CGMutablePath()
            for cell in layout.darkModuleCells {
                modulesPath.addPath(design.moduleShape.path(in: layout.moduleRect(cell.x, cell.y)))
            }
            fill(modulesPath, style: design.foreground, in: fullRect, ctx: ctx, evenOdd: false)

            // Eyes
            let ringStyle: FillStyle = design.eyeColor.map { .solid($0) } ?? design.foreground
            let pupilStyle: FillStyle = design.pupilColor.map { .solid($0) } ?? design.foreground
            for eye in layout.eyes {
                fill(design.eyeShape.ringPath(in: eye.rect, corner: eye.corner),
                     style: ringStyle, in: fullRect, ctx: ctx, evenOdd: true)
                fill(design.eyeShape.pupilPath(in: eye.rect, corner: eye.corner),
                     style: pupilStyle, in: fullRect, ctx: ctx, evenOdd: false)
            }

            // Logo
            if let logo = design.logo,
               let logoRect = layout.logoRect,
               let clearRect = layout.logoClearRect,
               let image = UIImage(data: logo.imageData) {
                let backingColor = design.background.alpha > 0 ? design.background : .white
                switch logo.backing {
                case .none:
                    // No plate, no clip — respects transparent-PNG logos as-is.
                    image.draw(in: aspectFit(image.size, in: logoRect))
                case .circle:
                    ctx.setFillColor(backingColor.cgColor)
                    ctx.fillEllipse(in: clearRect)
                    ctx.saveGState()
                    ctx.addEllipse(in: logoRect)
                    ctx.clip()
                    image.draw(in: aspectFill(image.size, in: logoRect))
                    ctx.restoreGState()
                case .roundedRect:
                    ctx.setFillColor(backingColor.cgColor)
                    let r = clearRect.width * 0.2
                    ctx.addPath(CGPath(roundedRect: clearRect, cornerWidth: r, cornerHeight: r, transform: nil))
                    ctx.fillPath()
                    ctx.saveGState()
                    let lr = logoRect.width * 0.24
                    ctx.addPath(CGPath(roundedRect: logoRect, cornerWidth: lr, cornerHeight: lr, transform: nil))
                    ctx.clip()
                    image.draw(in: aspectFill(image.size, in: logoRect))
                    ctx.restoreGState()
                }
            }
            ctx.restoreGState()

            if let frame = design.frame {
                drawFrame(frame, metrics: metrics, ctx: ctx)
            }
        }
    }

    private static func drawFrame(_ frame: QRFrame, metrics: FrameMetrics, ctx: CGContext) {
        guard let borderRect = metrics.borderRect, let bannerRect = metrics.bannerRect else { return }
        let r = FrameMetrics.cornerRadius

        ctx.setFillColor(frame.color.cgColor)
        ctx.addPath(QRGeometry.roundedRectPath(bannerRect, tl: 0, tr: 0, br: r, bl: r))
        ctx.fillPath()

        ctx.setStrokeColor(frame.color.cgColor)
        ctx.setLineWidth(FrameMetrics.strokeWidth)
        ctx.addPath(CGPath(roundedRect: borderRect, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.strokePath()

        let text = frame.text.isEmpty ? "SCAN ME" : frame.text
        var font = UIFont.systemFont(ofSize: FrameMetrics.fontSize, weight: .heavy)
        if let descriptor = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: font.pointSize)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(cgColor: frame.textColor.cgColor),
            .kern: 0.15,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let origin = CGPoint(x: bannerRect.midX - textSize.width / 2, y: bannerRect.midY - textSize.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    private static func fill(_ path: CGPath, style: FillStyle, in fullRect: CGRect, ctx: CGContext, evenOdd: Bool) {
        guard !path.isEmpty else { return }
        switch style {
        case .solid(let color):
            ctx.addPath(path)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath(using: evenOdd ? .evenOdd : .winding)
        case .linearGradient(let c1, let c2, let angle):
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip(using: evenOdd ? .evenOdd : .winding)
            let colors = [c1.cgColor, c2.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
                let (start, end) = QRGeometry.gradientEndpoints(in: fullRect, angleDegrees: angle)
                ctx.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            ctx.restoreGState()
        }
    }

    private static func aspectFit(_ size: CGSize, in rect: CGRect) -> CGRect {
        scaled(size, in: rect, by: min)
    }

    /// Fills the rect (cropping overflow) — used with a clip for avatar-style
    /// circular/rounded logos.
    private static func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        scaled(size, in: rect, by: max)
    }

    private static func scaled(_ size: CGSize, in rect: CGRect, by pick: (CGFloat, CGFloat) -> CGFloat) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = pick(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}

public enum MonogramFactory {
    /// Renders 1–2 characters on a colored circle — an instant "brand icon"
    /// for users who don't have a logo file handy.
    public static func image(text: String, textColor: RGBAColor, backgroundColor: RGBAColor) -> Data? {
        let side: CGFloat = 512
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { _ in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            let circle = UIBezierPath(ovalIn: rect)
            UIColor(cgColor: backgroundColor.cgColor).setFill()
            circle.fill()

            let trimmed = String(text.prefix(2))
            guard !trimmed.isEmpty else { return }
            var font = UIFont.systemFont(ofSize: trimmed.count > 1 ? 220 : 280, weight: .bold)
            if let descriptor = font.fontDescriptor.withDesign(.rounded) {
                font = UIFont(descriptor: descriptor, size: font.pointSize)
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(cgColor: textColor.cgColor),
            ]
            let textSize = (trimmed as NSString).size(withAttributes: attributes)
            let origin = CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
            (trimmed as NSString).draw(at: origin, withAttributes: attributes)
        }
        return image.pngData()
    }
}
