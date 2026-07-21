import CoreGraphics
import CoreImage
import Foundation

public enum QRCorrectionLevel: String, Codable, Sendable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"
}

/// The boolean module grid of a QR code, quiet zone stripped.
public struct QRMatrix: Equatable, Sendable {
    public let size: Int
    private let modules: [Bool]

    public subscript(x: Int, y: Int) -> Bool {
        modules[y * size + x]
    }

    /// Encodes `payload` with CIQRCodeGenerator and samples the output at
    /// one pixel per module. Returns nil for empty/oversized payloads.
    public init?(payload: String, correction: QRCorrectionLevel) {
        guard !payload.isEmpty else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter?.setValue(correction.rawValue, forKey: "inputCorrectionLevel")
        guard let output = filter?.outputImage else { return nil }

        let width = Int(output.extent.width)
        let height = Int(output.extent.height)
        guard width > 0, height > 0 else { return nil }

        let ciContext = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }

        var pixels = [UInt8](repeating: 255, count: width * height)
        guard let bitmap = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func isDark(_ x: Int, _ y: Int) -> Bool {
            pixels[y * width + x] < 128
        }

        // Strip the quiet zone by cropping to the dark bounding box.
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where isDark(x, y) {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY, (maxX - minX) == (maxY - minY) else { return nil }

        let n = maxX - minX + 1
        var grid = [Bool](repeating: false, count: n * n)
        for y in 0..<n {
            for x in 0..<n {
                grid[y * n + x] = isDark(minX + x, minY + y)
            }
        }
        self.size = n
        self.modules = grid
    }
}
