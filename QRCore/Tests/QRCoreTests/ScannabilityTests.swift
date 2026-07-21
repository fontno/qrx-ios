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
}
