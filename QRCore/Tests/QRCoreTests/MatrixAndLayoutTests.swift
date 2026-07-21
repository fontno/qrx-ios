import CoreGraphics
import Foundation
import Testing
@testable import QRCore

@Suite("QRMatrix generation")
struct MatrixTests {
    @Test func emptyPayloadReturnsNil() {
        #expect(QRMatrix(payload: "", correction: .medium) == nil)
    }

    @Test func oversizedPayloadReturnsNil() {
        let huge = String(repeating: "A", count: 8000)
        #expect(QRMatrix(payload: huge, correction: .high) == nil)
    }

    @Test func tinyPayloadIsVersionOne() throws {
        let m = try #require(QRMatrix(payload: "A", correction: .low))
        #expect(m.size == 21)
    }

    /// Every QR version has size 21 + 4k.
    @Test(arguments: ["hello", "https://example.com", String(repeating: "data", count: 100)])
    func sizeIsAlwaysAValidQRVersion(_ payload: String) throws {
        let m = try #require(QRMatrix(payload: payload, correction: .quartile))
        #expect(m.size >= 21)
        #expect((m.size - 21) % 4 == 0)
    }

    @Test func generationIsDeterministic() throws {
        let a = try #require(QRMatrix(payload: "same input", correction: .high))
        let b = try #require(QRMatrix(payload: "same input", correction: .high))
        #expect(a == b)
    }

    /// Finder patterns: 7×7 dark border, light ring, dark 3×3 center — at all
    /// three corners. Catches any orientation/cropping regression in the
    /// CIQRCodeGenerator pixel sampling.
    @Test func finderPatternsAtThreeCorners() throws {
        let m = try #require(QRMatrix(payload: "finder check", correction: .medium))
        let n = m.size
        for (ox, oy) in [(0, 0), (n - 7, 0), (0, n - 7)] {
            #expect(m[ox, oy], "outer ring dark at (\(ox),\(oy))")
            #expect(m[ox + 6, oy + 6], "outer ring dark corner")
            #expect(!m[ox + 1, oy + 1], "inner ring light")
            #expect(m[ox + 3, oy + 3], "pupil dark")
        }
    }
}

@Suite("QRLayout geometry")
struct LayoutTests {
    private func makeLayout(design: QRDesign = QRDesign()) throws -> QRLayout {
        let m = try #require(QRMatrix(payload: "layout test", correction: .quartile))
        return QRLayout(matrix: m, design: design)
    }

    @Test func totalIncludesQuietZone() throws {
        let layout = try makeLayout(design: QRDesign(quietZone: 3))
        #expect(layout.total == CGFloat(layout.matrix.size + 6))
    }

    @Test func eyeRegionsAtThreeCornersOnly() throws {
        let layout = try makeLayout()
        let n = layout.matrix.size
        #expect(layout.isInEye(0, 0))
        #expect(layout.isInEye(n - 1, 0))
        #expect(layout.isInEye(0, n - 1))
        #expect(!layout.isInEye(n - 1, n - 1))
        #expect(!layout.isInEye(n / 2, n / 2))
    }

    @Test func darkModulesNeverOverlapEyes() throws {
        let layout = try makeLayout()
        #expect(layout.darkModuleCells.allSatisfy { !layout.isInEye($0.x, $0.y) })
    }

    @Test func logoRectNilWithoutLogo() throws {
        let layout = try makeLayout()
        #expect(layout.logoRect == nil)
        #expect(!layout.isKnockedOut(layout.matrix.size / 2, layout.matrix.size / 2))
    }

    @Test func logoRectCenteredAndKnockoutClearsCenter() throws {
        let logo = LogoOptions(imageData: Data([0x1]), sizeFraction: 0.25, backing: .circle, knockout: true)
        let layout = try makeLayout(design: QRDesign(logo: logo))
        let rect = try #require(layout.logoRect)
        #expect(abs(rect.midX - layout.total / 2) < 0.001)
        #expect(abs(rect.midY - layout.total / 2) < 0.001)

        let center = layout.matrix.size / 2
        #expect(layout.isKnockedOut(center, center))
        #expect(!layout.isKnockedOut(0, 0))
        #expect(layout.darkModuleCells.allSatisfy { !($0.x == center && $0.y == center) })
    }

    @Test func knockoutDisabledKeepsCenterModules() throws {
        let logo = LogoOptions(imageData: Data([0x1]), sizeFraction: 0.25, backing: .circle, knockout: false)
        let layout = try makeLayout(design: QRDesign(logo: logo))
        let center = layout.matrix.size / 2
        #expect(!layout.isKnockedOut(center, center))
    }
}

@Suite("RGBAColor")
struct RGBAColorTests {
    @Test func svgHex() {
        #expect(RGBAColor.black.svgHex == "#000000")
        #expect(RGBAColor.white.svgHex == "#FFFFFF")
        #expect(RGBAColor(red: 1, green: 0, blue: 0).svgHex == "#FF0000")
    }

    @Test func codableRoundTrip() throws {
        let original = RGBAColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.9)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RGBAColor.self, from: data)
        #expect(decoded == original)
    }

    @Test func designCodableRoundTrip() throws {
        let design = QRDesign(
            moduleShape: .circle,
            eyeShape: .leaf,
            foreground: .linearGradient(.black, RGBAColor(red: 0.3, green: 0.2, blue: 0.9), angleDegrees: 45),
            background: .clear,
            eyeColor: RGBAColor(red: 1, green: 0, blue: 0),
            pupilColor: nil,
            logo: LogoOptions(imageData: Data([1, 2, 3]), sizeFraction: 0.2, backing: .roundedRect, knockout: true),
            frame: QRFrame(text: "SCAN ME", color: .black),
            quietZone: 3
        )
        let data = try JSONEncoder().encode(design)
        let decoded = try JSONDecoder().decode(QRDesign.self, from: data)
        #expect(decoded == design)
    }
}
