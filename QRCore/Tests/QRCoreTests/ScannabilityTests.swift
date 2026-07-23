import CoreImage
import Testing
import UIKit
@testable import QRCore

/// The app's core promise is "this code scans". These tests enforce it as a
/// property: for every styling combination the renderer supports, the rendered
/// bitmap must decode back to the exact input payload.
@Suite("Scannability round-trip")
struct ScannabilityTests {
    private static let payload = "https://example.com/brand?id=42"

    private func decode(_ image: UIImage) -> [String] {
        guard let cgImage = image.cgImage,
              let detector = CIDetector(
                  ofType: CIDetectorTypeQRCode,
                  context: nil,
                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              )
        else { return [] }
        return detector.features(in: CIImage(cgImage: cgImage))
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }

    /// Renders on white first so transparent backgrounds decode the way a
    /// scanner would actually see them (printed on paper / placed on a page).
    private func flattenedOnWhite(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }

    private func expectScans(_ design: QRDesign, payload: String = ScannabilityTests.payload,
                             correction: QRCorrectionLevel = .quartile,
                             sourceLocation: SourceLocation = #_sourceLocation) throws {
        let matrix = try #require(QRMatrix(payload: payload, correction: correction), sourceLocation: sourceLocation)
        let image = QRRenderer.render(matrix: matrix, design: design, pixelSize: 512)
        let decoded = decode(flattenedOnWhite(image))
        #expect(decoded.contains(payload), "decoded: \(decoded)", sourceLocation: sourceLocation)
    }

    // MARK: The property: every shape combination scans

    @Test(arguments: ModuleShape.allCases, EyeShape.allCases)
    func everyShapeCombinationScans(module: ModuleShape, eye: EyeShape) throws {
        try expectScans(QRDesign(moduleShape: module, eyeShape: eye))
    }

    // MARK: Styling variations

    @Test func gradientForegroundScans() throws {
        let design = QRDesign(
            moduleShape: .rounded,
            eyeShape: .leaf,
            foreground: .linearGradient(
                RGBAColor(red: 0.05, green: 0.05, blue: 0.15),
                RGBAColor(red: 0.35, green: 0.2, blue: 0.85),
                angleDegrees: 45
            )
        )
        try expectScans(design)
    }

    @Test func customEyeColorsScan() throws {
        var design = QRDesign(moduleShape: .circle, eyeShape: .rounded)
        design.eyeColor = RGBAColor(red: 0.1, green: 0.2, blue: 0.6)
        design.pupilColor = RGBAColor(red: 0.5, green: 0.1, blue: 0.4)
        try expectScans(design)
    }

    @Test func transparentBackgroundScansOnWhite() throws {
        try expectScans(QRDesign(moduleShape: .rounded, eyeShape: .circle, background: .clear))
    }

    @Test(arguments: LogoBacking.allCases)
    func centerLogoWithKnockoutScans(backing: LogoBacking) throws {
        let logoData = try #require(MonogramFactory.image(
            text: "QX",
            textColor: .white,
            backgroundColor: RGBAColor(red: 0.1, green: 0.45, blue: 0.95)
        ))
        var design = QRDesign(moduleShape: .rounded, eyeShape: .leaf)
        design.logo = LogoOptions(imageData: logoData, sizeFraction: 0.22, backing: backing, knockout: true)
        try expectScans(design, correction: .high)
    }

    @Test func frameScans() throws {
        var design = QRDesign(moduleShape: .rounded, eyeShape: .rounded)
        design.frame = QRFrame(text: "SCAN ME", color: .black)
        try expectScans(design)
    }

    @Test func topLabelFrameWithBadgeScans() throws {
        let badge = try #require(MonogramFactory.image(
            text: "G", textColor: .white, backgroundColor: RGBAColor(red: 0.26, green: 0.52, blue: 0.96)))
        var design = QRDesign(moduleShape: .rounded, eyeShape: .rounded)
        design.frame = QRFrame(
            text: "TAP OR SCAN",
            color: RGBAColor(red: 0.1, green: 0.35, blue: 0.7),
            labelEdge: .top,
            badgeImageData: badge
        )
        try expectScans(design)
    }

    @Test func legacyFrameJSONStillDecodes() throws {
        // Designs saved before labelEdge/badge existed must keep loading.
        let legacy = #"{"text":"SCAN ME","color":{"red":0,"green":0,"blue":0,"alpha":1}}"#
        let frame = try JSONDecoder().decode(QRFrame.self, from: Data(legacy.utf8))
        #expect(frame.labelEdge == .bottom)
        #expect(frame.badgeImageData == nil)
    }

    @Test func classicBannerGeometryUnchangedByFrameV2() throws {
        // The v2 metrics must reproduce the original banner frame exactly.
        let old = FrameMetrics(layoutTotal: 29, hasFrame: true)
        let new = FrameMetrics(layoutTotal: 29, frame: QRFrame())
        #expect(old.canvasSize == new.canvasSize)
        #expect(old.borderRect == new.borderRect)
        #expect(old.bannerRect == new.bannerRect)
        #expect(old.codeOrigin == new.codeOrigin)
    }

    @Test func badgeStaysInsideCanvas() {
        let metrics = FrameMetrics(layoutTotal: 29, frame: QRFrame(labelEdge: .top, badgeImageData: Data([1])))
        let badge = metrics.badgeRect!
        #expect(badge.maxY <= metrics.canvasSize.height)
        #expect(badge.minY >= 0)
        let label = metrics.topLabelCenterY!
        #expect(label - FrameMetrics.topLabelHeight / 2 >= 0)
        #expect(label + FrameMetrics.topLabelHeight / 2 <= metrics.codeOrigin.y)
    }

    @Test func everythingAtOnceScans() throws {
        let logoData = try #require(MonogramFactory.image(text: "B", textColor: .white, backgroundColor: .black))
        var design = QRDesign(
            moduleShape: .circle,
            eyeShape: .leaf,
            foreground: .linearGradient(
                RGBAColor(red: 0.1, green: 0.05, blue: 0.3),
                RGBAColor(red: 0.2, green: 0.3, blue: 0.9),
                angleDegrees: 120
            )
        )
        design.eyeColor = RGBAColor(red: 0.1, green: 0.05, blue: 0.3)
        design.pupilColor = RGBAColor(red: 0.2, green: 0.3, blue: 0.9)
        design.logo = LogoOptions(imageData: logoData, sizeFraction: 0.2, backing: .circle, knockout: true)
        design.frame = QRFrame(text: "SCAN ME", color: .black)
        try expectScans(design, correction: .high)
    }

    // MARK: Content payloads survive encoding

    @Test func wifiPayloadWithSpecialCharactersRoundTrips() throws {
        let payload = QRPayload.wifi(ssid: "Br;an's \"Café\"", password: "p@ss:word", security: .wpa, hidden: true)
        try expectScans(QRDesign(), payload: payload)
    }

    @Test func vCardPayloadRoundTrips() throws {
        let payload = QRPayload.contact(name: "Ada Lovelace", org: "Engines, Inc", phone: "+15550100", email: "ada@example.com", website: "https://example.com")
        try expectScans(QRDesign(), payload: payload)
    }

    // MARK: Renderer output geometry

    @Test func renderedImageMatchesRequestedSize() throws {
        let matrix = try #require(QRMatrix(payload: "size", correction: .low))
        let image = QRRenderer.render(matrix: matrix, design: QRDesign(), pixelSize: 300)
        #expect(image.size == CGSize(width: 300, height: 300))
    }

    @Test func frameMakesImageTaller() throws {
        let matrix = try #require(QRMatrix(payload: "size", correction: .low))
        var design = QRDesign()
        design.frame = QRFrame()
        let image = QRRenderer.render(matrix: matrix, design: design, pixelSize: 300)
        #expect(image.size.width == 300)
        #expect(image.size.height > 300)
    }

    /// The background must follow the frame's rounded border — square corners
    /// poking out past it are a rendering bug.
    @Test func framedBackgroundHasTransparentCorners() throws {
        let matrix = try #require(QRMatrix(payload: "corners", correction: .low))
        var design = QRDesign(background: RGBAColor(red: 1, green: 1, blue: 0))
        design.frame = QRFrame(color: .black)
        let image = QRRenderer.render(matrix: matrix, design: design, pixelSize: 400)

        #expect(alpha(of: image, atUnit: 0.002, 0.002) == 0, "corner pixel should be transparent")
        #expect(alpha(of: image, atUnit: 0.5, 0.5) > 0, "center must be opaque")
    }

    /// Reads the alpha of the pixel at a fractional position in the image.
    private func alpha(of image: UIImage, atUnit ux: CGFloat, _ uy: CGFloat) -> UInt8 {
        guard let cgImage = image.cgImage else { return 255 }
        let x = Int(CGFloat(cgImage.width - 1) * ux)
        let y = Int(CGFloat(cgImage.height - 1) * uy)
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let ctx = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 255 }
        ctx.draw(cgImage, in: CGRect(x: -CGFloat(x), y: -CGFloat(cgImage.height - 1 - y), width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        return pixel[3]
    }
}
