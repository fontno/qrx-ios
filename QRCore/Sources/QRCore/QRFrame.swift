import CoreGraphics
import Foundation

/// A call-to-action frame: rounded border around the code with a label —
/// either a filled banner underneath (classic "SCAN ME") or a knockout label
/// breaking the top border ("TAP OR SCAN") — plus an optional circular brand
/// badge centered on the bottom border.
public struct QRFrame: Codable, Equatable, Hashable, Sendable {
    public enum LabelEdge: String, Codable, CaseIterable, Sendable {
        /// Filled banner bar below the code.
        case bottom
        /// Label text breaking the top border line.
        case top
    }

    public var text: String
    public var color: RGBAColor
    public var labelEdge: LabelEdge
    /// PNG for a circular badge centered on the bottom border (e.g. a brand
    /// mark). Aspect-filled and clipped to a circle with a ring in `color`.
    public var badgeImageData: Data?

    public init(text: String = "SCAN ME", color: RGBAColor = .black, labelEdge: LabelEdge = .bottom, badgeImageData: Data? = nil) {
        self.text = text
        self.color = color
        self.labelEdge = labelEdge
        self.badgeImageData = badgeImageData
    }

    // Custom decoding: designs saved before labelEdge/badge existed must
    // keep decoding (missing keys → defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        color = try container.decode(RGBAColor.self, forKey: .color)
        labelEdge = try container.decodeIfPresent(LabelEdge.self, forKey: .labelEdge) ?? .bottom
        badgeImageData = try container.decodeIfPresent(Data.self, forKey: .badgeImageData)
    }

    /// Black or white, whichever reads against the banner color.
    public var textColor: RGBAColor {
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.6 ? .black : .white
    }
}

/// Canvas geometry once a frame is applied, in module units.
/// Without a frame the canvas is exactly the QRLayout square.
/// With labelEdge == .bottom and no badge this reproduces the original
/// banner-frame geometry byte for byte.
public struct FrameMetrics: Sendable {
    public let canvasSize: CGSize
    public let codeOrigin: CGPoint
    /// Rounded border around everything; nil when no frame.
    public let borderRect: CGRect?
    /// Filled banner (labelEdge == .bottom only).
    public let bannerRect: CGRect?
    /// Centerline y of the top knockout label (labelEdge == .top only).
    public let topLabelCenterY: CGFloat?
    /// Circular badge box centered on the bottom border, when a badge is set.
    public let badgeRect: CGRect?

    public static let margin: CGFloat = 1.6
    public static let topLabelMargin: CGFloat = 3.0
    public static let bannerHeight: CGFloat = 5
    public static let badgeDiameter: CGFloat = 3.6
    public static let badgeDrop: CGFloat = 2.0
    public static let cornerRadius: CGFloat = 2.5
    public static let strokeWidth: CGFloat = 1.0
    public static let fontSize: CGFloat = 2.6
    public static let topLabelFontSize: CGFloat = 2.2
    public static let topLabelHeight: CGFloat = 1.8

    public init(layoutTotal: CGFloat, frame: QRFrame?) {
        guard let frame else {
            canvasSize = CGSize(width: layoutTotal, height: layoutTotal)
            codeOrigin = .zero
            borderRect = nil
            bannerRect = nil
            topLabelCenterY = nil
            badgeRect = nil
            return
        }
        let side = Self.margin
        let top = frame.labelEdge == .top ? Self.topLabelMargin : side
        let banner = frame.labelEdge == .bottom ? Self.bannerHeight : 0
        let drop = frame.badgeImageData != nil ? Self.badgeDrop : 0

        let width = layoutTotal + 2 * side
        let height = top + layoutTotal + side + banner + drop
        canvasSize = CGSize(width: width, height: height)
        codeOrigin = CGPoint(x: side, y: top)

        let borderTop = frame.labelEdge == .top ? top - 1.4 : 0.5
        let borderBottom = height - 0.5 - drop
        borderRect = CGRect(x: 0.5, y: borderTop, width: width - 1, height: borderBottom - borderTop)

        bannerRect = frame.labelEdge == .bottom
            ? CGRect(x: 0.5, y: borderBottom - banner, width: width - 1, height: banner)
            : nil
        topLabelCenterY = frame.labelEdge == .top ? borderTop : nil
        badgeRect = frame.badgeImageData != nil
            ? CGRect(x: width / 2 - Self.badgeDiameter / 2, y: borderBottom - Self.badgeDiameter / 2,
                     width: Self.badgeDiameter, height: Self.badgeDiameter)
            : nil
    }

    /// Backwards-compatible convenience used by earlier call sites/tests.
    public init(layoutTotal: CGFloat, hasFrame: Bool) {
        self.init(layoutTotal: layoutTotal, frame: hasFrame ? QRFrame() : nil)
    }
}
