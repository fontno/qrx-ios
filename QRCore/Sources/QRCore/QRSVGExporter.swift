import CoreGraphics
import Foundation

/// Vector export mirroring QRRenderer's geometry. Coordinates are in module
/// units via the SVG viewBox, so output is resolution-independent.
public enum QRSVGExporter {
    public static func svg(matrix: QRMatrix, design: QRDesign) -> String {
        let layout = QRLayout(matrix: matrix, design: design)
        let total = layout.total
        let metrics = FrameMetrics(layoutTotal: total, frame: design.frame)
        var defs: [String] = []
        var body: [String] = []

        if design.background.alpha > 0 {
            if let borderRect = metrics.borderRect {
                // Fill only the bordered region, rounded to the border's outer
                // edge — matches the raster renderer.
                let bg = borderRect.insetBy(dx: -FrameMetrics.strokeWidth / 2, dy: -FrameMetrics.strokeWidth / 2)
                let rx = FrameMetrics.cornerRadius + FrameMetrics.strokeWidth / 2
                body.append("<rect x=\"\(fmt(bg.minX))\" y=\"\(fmt(bg.minY))\" width=\"\(fmt(bg.width))\" height=\"\(fmt(bg.height))\" rx=\"\(fmt(rx))\" fill=\"\(design.background.svgHex)\"\(opacity(design.background))/>")
            } else {
                body.append("<rect width=\"\(fmt(metrics.canvasSize.width))\" height=\"\(fmt(metrics.canvasSize.height))\" fill=\"\(design.background.svgHex)\"\(opacity(design.background))/>")
            }
        }

        if design.frame != nil {
            body.append("<g transform=\"translate(\(fmt(metrics.codeOrigin.x)) \(fmt(metrics.codeOrigin.y)))\">")
        }

        let fullRect = CGRect(x: 0, y: 0, width: total, height: total)
        let fgFill = fillAttributes(design.foreground, id: "fg", in: fullRect, defs: &defs)

        // Data modules as one path
        var moduleData = ""
        for cell in layout.darkModuleCells {
            moduleData += modulePathData(design.moduleShape, in: layout.moduleRect(cell.x, cell.y))
        }
        if !moduleData.isEmpty {
            body.append("<path d=\"\(moduleData)\" \(fgFill)/>")
        }

        // Eyes
        let ringFill = design.eyeColor.map { "fill=\"\($0.svgHex)\"\(opacity($0))" } ?? fgFill
        let pupilFill = design.pupilColor.map { "fill=\"\($0.svgHex)\"\(opacity($0))" } ?? fgFill
        for eye in layout.eyes {
            let outer = eyePathData(design.eyeShape, in: eye.rect, corner: eye.corner)
            let hole = eyePathData(design.eyeShape, in: eye.rect.insetBy(dx: eye.rect.width / 7, dy: eye.rect.height / 7), corner: eye.corner)
            body.append("<path d=\"\(outer)\(hole)\" fill-rule=\"evenodd\" \(ringFill)/>")
            let pupilRect = eye.rect.insetBy(dx: eye.rect.width * 2 / 7, dy: eye.rect.height * 2 / 7)
            body.append("<path d=\"\(eyePathData(design.eyeShape, in: pupilRect, corner: eye.corner))\" \(pupilFill)/>")
        }

        // Logo — for circle/rounded the image is aspect-filled ("slice") and
        // clipped to the shape, matching the raster renderer.
        if let logo = design.logo, let logoRect = layout.logoRect, let clearRect = layout.logoClearRect {
            let backing = design.background.alpha > 0 ? design.background : .white
            var aspectMode = "meet"
            var clipAttribute = ""
            switch logo.backing {
            case .none:
                break
            case .circle:
                body.append("<circle cx=\"\(fmt(clearRect.midX))\" cy=\"\(fmt(clearRect.midY))\" r=\"\(fmt(clearRect.width / 2))\" fill=\"\(backing.svgHex)\"/>")
                defs.append("<clipPath id=\"logoclip\"><circle cx=\"\(fmt(logoRect.midX))\" cy=\"\(fmt(logoRect.midY))\" r=\"\(fmt(logoRect.width / 2))\"/></clipPath>")
                aspectMode = "slice"
                clipAttribute = " clip-path=\"url(#logoclip)\""
            case .roundedRect:
                body.append("<rect x=\"\(fmt(clearRect.minX))\" y=\"\(fmt(clearRect.minY))\" width=\"\(fmt(clearRect.width))\" height=\"\(fmt(clearRect.height))\" rx=\"\(fmt(clearRect.width * 0.2))\" fill=\"\(backing.svgHex)\"/>")
                defs.append("<clipPath id=\"logoclip\"><rect x=\"\(fmt(logoRect.minX))\" y=\"\(fmt(logoRect.minY))\" width=\"\(fmt(logoRect.width))\" height=\"\(fmt(logoRect.height))\" rx=\"\(fmt(logoRect.width * 0.24))\"/></clipPath>")
                aspectMode = "slice"
                clipAttribute = " clip-path=\"url(#logoclip)\""
            }
            let base64 = logo.imageData.base64EncodedString()
            body.append("<image href=\"data:image/png;base64,\(base64)\" x=\"\(fmt(logoRect.minX))\" y=\"\(fmt(logoRect.minY))\" width=\"\(fmt(logoRect.width))\" height=\"\(fmt(logoRect.height))\" preserveAspectRatio=\"xMidYMid \(aspectMode)\"\(clipAttribute)/>")
        }

        if let frame = design.frame {
            body.append("</g>")
            appendFrame(frame, metrics: metrics, background: design.background, defs: &defs, to: &body)
        }

        let defsBlock = defs.isEmpty ? "" : "<defs>\(defs.joined())</defs>"
        let width: CGFloat = 2048
        let height = (width * metrics.canvasSize.height / metrics.canvasSize.width).rounded()
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(fmt(metrics.canvasSize.width)) \(fmt(metrics.canvasSize.height))" width="\(Int(width))" height="\(Int(height))">\(defsBlock)\(body.joined())</svg>
        """
    }

    private static func appendFrame(_ frame: QRFrame, metrics: FrameMetrics, background: RGBAColor, defs: inout [String], to body: inout [String]) {
        guard let borderRect = metrics.borderRect else { return }
        let r = FrameMetrics.cornerRadius
        let text = frame.text.isEmpty ? "SCAN ME" : frame.text
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        if let bannerRect = metrics.bannerRect {
            body.append("<path d=\"\(roundedRectData(bannerRect, tl: 0, tr: 0, br: r, bl: r))\" fill=\"\(frame.color.svgHex)\"/>")
        }
        body.append("<rect x=\"\(fmt(borderRect.minX))\" y=\"\(fmt(borderRect.minY))\" width=\"\(fmt(borderRect.width))\" height=\"\(fmt(borderRect.height))\" rx=\"\(fmt(r))\" fill=\"none\" stroke=\"\(frame.color.svgHex)\" stroke-width=\"\(fmt(FrameMetrics.strokeWidth))\"/>")

        if let bannerRect = metrics.bannerRect {
            body.append("<text x=\"\(fmt(bannerRect.midX))\" y=\"\(fmt(bannerRect.midY))\" font-family=\"Helvetica, Arial, sans-serif\" font-weight=\"bold\" font-size=\"\(fmt(FrameMetrics.fontSize))\" letter-spacing=\"0.15\" fill=\"\(frame.textColor.svgHex)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escaped)</text>")
        }

        if let centerY = metrics.topLabelCenterY {
            // Estimated knockout width — SVG has no text measurement. Matches
            // the raster look closely for typical short labels.
            let estimatedWidth = CGFloat(text.count) * FrameMetrics.topLabelFontSize * 0.68 + 2
            let knockoutColor = background.alpha > 0 ? background : .white
            let knockout = CGRect(
                x: metrics.canvasSize.width / 2 - estimatedWidth / 2,
                y: centerY - FrameMetrics.topLabelHeight / 2,
                width: estimatedWidth,
                height: FrameMetrics.topLabelHeight
            )
            body.append("<rect x=\"\(fmt(knockout.minX))\" y=\"\(fmt(knockout.minY))\" width=\"\(fmt(knockout.width))\" height=\"\(fmt(knockout.height))\" fill=\"\(knockoutColor.svgHex)\"/>")
            body.append("<text x=\"\(fmt(metrics.canvasSize.width / 2))\" y=\"\(fmt(centerY))\" font-family=\"Helvetica, Arial, sans-serif\" font-weight=\"bold\" font-size=\"\(fmt(FrameMetrics.topLabelFontSize))\" letter-spacing=\"0.15\" fill=\"\(frame.color.svgHex)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escaped)</text>")
        }

        if let badgeRect = metrics.badgeRect, let badgeData = frame.badgeImageData {
            let cx = badgeRect.midX, cy = badgeRect.midY
            body.append("<circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(badgeRect.width / 2))\" fill=\"#FFFFFF\"/>")
            let clipR = badgeRect.width / 2 - 0.2
            defs.append("<clipPath id=\"badgeclip\"><circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(clipR))\"/></clipPath>")
            let clipRect = badgeRect.insetBy(dx: 0.2, dy: 0.2)
            body.append("<image href=\"data:image/png;base64,\(badgeData.base64EncodedString())\" x=\"\(fmt(clipRect.minX))\" y=\"\(fmt(clipRect.minY))\" width=\"\(fmt(clipRect.width))\" height=\"\(fmt(clipRect.height))\" preserveAspectRatio=\"xMidYMid slice\" clip-path=\"url(#badgeclip)\"/>")
            body.append("<circle cx=\"\(fmt(cx))\" cy=\"\(fmt(cy))\" r=\"\(fmt(badgeRect.width / 2))\" fill=\"none\" stroke=\"\(frame.color.svgHex)\" stroke-width=\"\(fmt(FrameMetrics.strokeWidth * 0.8))\"/>")
        }
    }

    // MARK: - Fills

    private static func fillAttributes(_ style: FillStyle, id: String, in rect: CGRect, defs: inout [String]) -> String {
        switch style {
        case .solid(let c):
            return "fill=\"\(c.svgHex)\"\(opacity(c))"
        case .linearGradient(let c1, let c2, let angle):
            let (start, end) = QRGeometry.gradientEndpoints(in: rect, angleDegrees: angle)
            defs.append("""
            <linearGradient id="\(id)" gradientUnits="userSpaceOnUse" x1="\(fmt(start.x))" y1="\(fmt(start.y))" x2="\(fmt(end.x))" y2="\(fmt(end.y))"><stop offset="0" stop-color="\(c1.svgHex)"/><stop offset="1" stop-color="\(c2.svgHex)"/></linearGradient>
            """)
            return "fill=\"url(#\(id))\""
        }
    }

    private static func opacity(_ c: RGBAColor) -> String {
        c.alpha < 1 ? " fill-opacity=\"\(fmt(CGFloat(c.alpha)))\"" : ""
    }

    // MARK: - Path data

    private static func modulePathData(_ shape: ModuleShape, in rect: CGRect) -> String {
        let w = rect.width
        switch shape {
        case .square:
            let r = rect.insetBy(dx: -w * 0.02, dy: -w * 0.02)
            return "M\(fmt(r.minX)) \(fmt(r.minY))H\(fmt(r.maxX))V\(fmt(r.maxY))H\(fmt(r.minX))Z"
        case .rounded:
            let r = rect.insetBy(dx: w * 0.04, dy: w * 0.04)
            let radius = r.width * 0.3
            return roundedRectData(r, tl: radius, tr: radius, br: radius, bl: radius)
        case .circle:
            let r = rect.insetBy(dx: w * 0.07, dy: w * 0.07)
            return circleData(center: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2)
        case .diamond:
            return "M\(fmt(rect.midX)) \(fmt(rect.minY))L\(fmt(rect.maxX)) \(fmt(rect.midY))L\(fmt(rect.midX)) \(fmt(rect.maxY))L\(fmt(rect.minX)) \(fmt(rect.midY))Z"
        }
    }

    private static func eyePathData(_ shape: EyeShape, in rect: CGRect, corner: EyeCorner) -> String {
        let w = rect.width
        switch shape {
        case .square:
            return "M\(fmt(rect.minX)) \(fmt(rect.minY))H\(fmt(rect.maxX))V\(fmt(rect.maxY))H\(fmt(rect.minX))Z"
        case .rounded:
            let r = w * 0.25
            return roundedRectData(rect, tl: r, tr: r, br: r, bl: r)
        case .circle:
            return circleData(center: CGPoint(x: rect.midX, y: rect.midY), radius: w / 2)
        case .leaf:
            let r = w * 0.45
            switch corner {
            case .topLeft: return roundedRectData(rect, tl: 0, tr: r, br: r, bl: r)
            case .topRight: return roundedRectData(rect, tl: r, tr: 0, br: r, bl: r)
            case .bottomLeft: return roundedRectData(rect, tl: r, tr: r, br: r, bl: 0)
            }
        }
    }

    private static func roundedRectData(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> String {
        var d = "M\(fmt(rect.minX + tl)) \(fmt(rect.minY))"
        d += "H\(fmt(rect.maxX - tr))"
        if tr > 0 { d += "A\(fmt(tr)) \(fmt(tr)) 0 0 1 \(fmt(rect.maxX)) \(fmt(rect.minY + tr))" }
        d += "V\(fmt(rect.maxY - br))"
        if br > 0 { d += "A\(fmt(br)) \(fmt(br)) 0 0 1 \(fmt(rect.maxX - br)) \(fmt(rect.maxY))" }
        d += "H\(fmt(rect.minX + bl))"
        if bl > 0 { d += "A\(fmt(bl)) \(fmt(bl)) 0 0 1 \(fmt(rect.minX)) \(fmt(rect.maxY - bl))" }
        d += "V\(fmt(rect.minY + tl))"
        if tl > 0 { d += "A\(fmt(tl)) \(fmt(tl)) 0 0 1 \(fmt(rect.minX + tl)) \(fmt(rect.minY))" }
        return d + "Z"
    }

    private static func circleData(center: CGPoint, radius: CGFloat) -> String {
        "M\(fmt(center.x - radius)) \(fmt(center.y))"
            + "A\(fmt(radius)) \(fmt(radius)) 0 1 0 \(fmt(center.x + radius)) \(fmt(center.y))"
            + "A\(fmt(radius)) \(fmt(radius)) 0 1 0 \(fmt(center.x - radius)) \(fmt(center.y))Z"
    }

    private static func fmt(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(Double(rounded))
    }
}
