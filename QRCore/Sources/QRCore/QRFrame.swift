import CoreGraphics
import Foundation

/// A call-to-action frame: rounded border around the code with a filled
/// banner underneath carrying the label text ("SCAN ME").
public struct QRFrame: Codable, Equatable, Hashable, Sendable {
    public var text: String
    public var color: RGBAColor

    public init(text: String = "SCAN ME", color: RGBAColor = .black) {
        self.text = text
        self.color = color
    }

    /// Black or white, whichever reads against the banner color.
    public var textColor: RGBAColor {
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.6 ? .black : .white
    }
}

/// Canvas geometry once a frame is applied, in module units.
/// Without a frame the canvas is exactly the QRLayout square.
public struct FrameMetrics: Sendable {
    public let canvasSize: CGSize
    public let codeOrigin: CGPoint
    /// Rounded border around everything; nil when no frame.
    public let borderRect: CGRect?
    public let bannerRect: CGRect?

    public static let margin: CGFloat = 1.6
    public static let bannerHeight: CGFloat = 5
    public static let cornerRadius: CGFloat = 2.5
    public static let strokeWidth: CGFloat = 1.0
    public static let fontSize: CGFloat = 2.6

    public init(layoutTotal: CGFloat, hasFrame: Bool) {
        guard hasFrame else {
            canvasSize = CGSize(width: layoutTotal, height: layoutTotal)
            codeOrigin = .zero
            borderRect = nil
            bannerRect = nil
            return
        }
        let m = Self.margin
        let width = layoutTotal + 2 * m
        let height = width + Self.bannerHeight
        canvasSize = CGSize(width: width, height: height)
        codeOrigin = CGPoint(x: m, y: m)
        borderRect = CGRect(x: 0.5, y: 0.5, width: width - 1, height: height - 1)
        bannerRect = CGRect(x: 0.5, y: height - 0.5 - Self.bannerHeight, width: width - 1, height: Self.bannerHeight)
    }
}
