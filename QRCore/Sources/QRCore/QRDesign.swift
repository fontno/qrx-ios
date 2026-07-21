import CoreGraphics
import Foundation

public enum ModuleShape: String, Codable, CaseIterable, Sendable, Identifiable {
    case square
    case rounded
    case circle
    case diamond

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .square: "Square"
        case .rounded: "Rounded"
        case .circle: "Dots"
        case .diamond: "Diamond"
        }
    }

    /// Path for one module in `rect`. Squares overdraw slightly so adjacent
    /// modules fuse without antialiasing seams.
    public func path(in rect: CGRect) -> CGPath {
        let w = rect.width
        switch self {
        case .square:
            return CGPath(rect: rect.insetBy(dx: -w * 0.02, dy: -w * 0.02), transform: nil)
        case .rounded:
            let r = rect.insetBy(dx: w * 0.04, dy: w * 0.04)
            return CGPath(roundedRect: r, cornerWidth: r.width * 0.3, cornerHeight: r.width * 0.3, transform: nil)
        case .circle:
            return CGPath(ellipseIn: rect.insetBy(dx: w * 0.07, dy: w * 0.07), transform: nil)
        case .diamond:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
            return p
        }
    }
}

/// Which corner of the code an eye (finder pattern) sits in.
/// Used to orient asymmetric eye shapes like `leaf`.
public enum EyeCorner: Sendable {
    case topLeft
    case topRight
    case bottomLeft
}

public enum EyeShape: String, Codable, CaseIterable, Sendable, Identifiable {
    case square
    case rounded
    case circle
    case leaf

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .square: "Square"
        case .rounded: "Rounded"
        case .circle: "Circle"
        case .leaf: "Leaf"
        }
    }

    /// The 7×7 outer ring: outer shape plus 5×5 hole. Fill with even-odd rule.
    public func ringPath(in rect: CGRect, corner: EyeCorner) -> CGPath {
        let hole = rect.insetBy(dx: rect.width / 7, dy: rect.height / 7)
        let p = CGMutablePath()
        p.addPath(shapePath(in: rect, corner: corner))
        p.addPath(shapePath(in: hole, corner: corner))
        return p
    }

    /// The 3×3 pupil, given the full 7×7 eye rect.
    public func pupilPath(in rect: CGRect, corner: EyeCorner) -> CGPath {
        let pupil = rect.insetBy(dx: rect.width * 2 / 7, dy: rect.height * 2 / 7)
        return shapePath(in: pupil, corner: corner)
    }

    public func shapePath(in rect: CGRect, corner: EyeCorner) -> CGPath {
        let w = rect.width
        switch self {
        case .square:
            return CGPath(rect: rect, transform: nil)
        case .rounded:
            return CGPath(roundedRect: rect, cornerWidth: w * 0.25, cornerHeight: w * 0.25, transform: nil)
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .leaf:
            // Three rounded corners; the corner facing the code's own corner stays sharp.
            let r = w * 0.45
            switch corner {
            case .topLeft:
                return QRGeometry.roundedRectPath(rect, tl: 0, tr: r, br: r, bl: r)
            case .topRight:
                return QRGeometry.roundedRectPath(rect, tl: r, tr: 0, br: r, bl: r)
            case .bottomLeft:
                return QRGeometry.roundedRectPath(rect, tl: r, tr: r, br: r, bl: 0)
            }
        }
    }
}

public enum FillStyle: Codable, Equatable, Hashable, Sendable {
    case solid(RGBAColor)
    case linearGradient(RGBAColor, RGBAColor, angleDegrees: Double)

    public var primaryColor: RGBAColor {
        switch self {
        case .solid(let c): c
        case .linearGradient(let c, _, _): c
        }
    }
}

public enum LogoBacking: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case circle
    case roundedRect

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "None"
        case .circle: "Circle"
        case .roundedRect: "Rounded"
        }
    }
}

public struct LogoOptions: Codable, Equatable, Hashable, Sendable {
    /// PNG data of the logo image (photo or generated monogram).
    public var imageData: Data
    /// Logo box side as a fraction of the full code side. Keep ≤ 0.3 or the
    /// code stops scanning even at high error correction.
    public var sizeFraction: Double
    public var backing: LogoBacking
    /// Remove the modules behind the logo instead of overlaying on top.
    public var knockout: Bool

    public init(imageData: Data, sizeFraction: Double = 0.22, backing: LogoBacking = .roundedRect, knockout: Bool = true) {
        self.imageData = imageData
        self.sizeFraction = sizeFraction
        self.backing = backing
        self.knockout = knockout
    }
}

public struct QRDesign: Codable, Equatable, Hashable, Sendable {
    public var moduleShape: ModuleShape
    public var eyeShape: EyeShape
    public var foreground: FillStyle
    public var background: RGBAColor
    /// Overrides for the eye ring / pupil; nil means "use foreground".
    public var eyeColor: RGBAColor?
    public var pupilColor: RGBAColor?
    public var logo: LogoOptions?
    public var frame: QRFrame?
    /// Quiet-zone width in modules on each side.
    public var quietZone: Int

    public init(
        moduleShape: ModuleShape = .square,
        eyeShape: EyeShape = .square,
        foreground: FillStyle = .solid(.black),
        background: RGBAColor = .white,
        eyeColor: RGBAColor? = nil,
        pupilColor: RGBAColor? = nil,
        logo: LogoOptions? = nil,
        frame: QRFrame? = nil,
        quietZone: Int = 2
    ) {
        self.moduleShape = moduleShape
        self.eyeShape = eyeShape
        self.foreground = foreground
        self.background = background
        self.eyeColor = eyeColor
        self.pupilColor = pupilColor
        self.logo = logo
        self.frame = frame
        self.quietZone = quietZone
    }
}

public enum QRGeometry {
    /// Rounded rect with independent corner radii (CGPath only supports uniform).
    public static func roundedRectPath(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        } else {
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        }
        p.closeSubpath()
        return p
    }

    /// Endpoints for a linear gradient covering `rect` at `angleDegrees`
    /// (0° = left→right, 90° = top→bottom).
    public static func gradientEndpoints(in rect: CGRect, angleDegrees: Double) -> (start: CGPoint, end: CGPoint) {
        let angle = angleDegrees * .pi / 180
        let dx = cos(angle), dy = sin(angle)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfDiagonal = hypot(rect.width, rect.height) / 2
        return (
            CGPoint(x: center.x - dx * halfDiagonal, y: center.y - dy * halfDiagonal),
            CGPoint(x: center.x + dx * halfDiagonal, y: center.y + dy * halfDiagonal)
        )
    }
}
