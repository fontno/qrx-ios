import CoreGraphics
import Foundation

/// Geometry of a styled QR code in "module units": one module = 1.0, with the
/// origin at the top-left of the quiet zone. Shared by the raster renderer and
/// the SVG exporter so both produce identical output.
public struct QRLayout: Sendable {
    public let matrix: QRMatrix
    public let design: QRDesign

    /// Full side length in module units, including both quiet zones.
    public var total: CGFloat {
        CGFloat(matrix.size + 2 * design.quietZone)
    }

    public init(matrix: QRMatrix, design: QRDesign) {
        self.matrix = matrix
        self.design = design
    }

    public func moduleRect(_ x: Int, _ y: Int) -> CGRect {
        let q = CGFloat(design.quietZone)
        return CGRect(x: q + CGFloat(x), y: q + CGFloat(y), width: 1, height: 1)
    }

    /// The three 7×7 finder-pattern frames, in module units.
    public var eyes: [(rect: CGRect, corner: EyeCorner)] {
        let n = matrix.size
        let q = CGFloat(design.quietZone)
        return [
            (CGRect(x: q, y: q, width: 7, height: 7), .topLeft),
            (CGRect(x: q + CGFloat(n - 7), y: q, width: 7, height: 7), .topRight),
            (CGRect(x: q, y: q + CGFloat(n - 7), width: 7, height: 7), .bottomLeft),
        ]
    }

    public func isInEye(_ x: Int, _ y: Int) -> Bool {
        let n = matrix.size
        return (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7)
    }

    /// Centered square box for the logo, in module units. nil when no logo.
    public var logoRect: CGRect? {
        guard let logo = design.logo else { return nil }
        let side = total * CGFloat(logo.sizeFraction)
        return CGRect(x: (total - side) / 2, y: (total - side) / 2, width: side, height: side)
    }

    /// Logo box grown by padding — the area cleared of modules (knockout) and
    /// filled by the backing shape.
    public var logoClearRect: CGRect? {
        logoRect?.insetBy(dx: -0.6, dy: -0.6)
    }

    public func isKnockedOut(_ x: Int, _ y: Int) -> Bool {
        guard design.logo?.knockout == true, let clear = logoClearRect else { return false }
        let r = moduleRect(x, y)
        return clear.contains(CGPoint(x: r.midX, y: r.midY))
    }

    /// Dark modules to draw: excludes eyes (drawn separately) and knocked-out cells.
    public var darkModuleCells: [(x: Int, y: Int)] {
        var cells: [(Int, Int)] = []
        for y in 0..<matrix.size {
            for x in 0..<matrix.size where matrix[x, y] && !isInEye(x, y) && !isKnockedOut(x, y) {
                cells.append((x, y))
            }
        }
        return cells
    }
}
