import Foundation
import Testing
@testable import QRCore

@Suite("SVG export")
struct SVGExportTests {
    private func makeSVG(design: QRDesign, payload: String = "https://example.com") throws -> String {
        let matrix = try #require(QRMatrix(payload: payload, correction: .quartile))
        return QRSVGExporter.svg(matrix: matrix, design: design)
    }

    private func isWellFormedXML(_ svg: String) -> Bool {
        let parser = XMLParser(data: Data(svg.utf8))
        return parser.parse()
    }

    @Test(arguments: ModuleShape.allCases, EyeShape.allCases)
    func everyShapeCombinationIsWellFormedXML(module: ModuleShape, eye: EyeShape) throws {
        let svg = try makeSVG(design: QRDesign(moduleShape: module, eyeShape: eye))
        #expect(isWellFormedXML(svg))
    }

    @Test func solidForegroundEmitsHexFill() throws {
        let svg = try makeSVG(design: QRDesign(foreground: .solid(RGBAColor(red: 1, green: 0, blue: 0))))
        #expect(svg.contains("fill=\"#FF0000\""))
        #expect(!svg.contains("<linearGradient"))
    }

    @Test func gradientForegroundEmitsGradientDef() throws {
        let design = QRDesign(foreground: .linearGradient(.black, .white, angleDegrees: 90))
        let svg = try makeSVG(design: design)
        #expect(svg.contains("<linearGradient id=\"fg\""))
        #expect(svg.contains("fill=\"url(#fg)\""))
    }

    @Test func transparentBackgroundEmitsNoBackgroundRect() throws {
        let svg = try makeSVG(design: QRDesign(background: .clear))
        #expect(!svg.contains("<rect width="))
    }

    @Test func framedBackgroundIsRounded() throws {
        var design = QRDesign()
        design.frame = QRFrame()
        let svg = try makeSVG(design: design)
        // The first white rect is the background; framed it must be rounded.
        let bgRect = try #require(svg.firstMatch(of: /<rect [^>]*fill="#FFFFFF"[^>]*\/>/))
        #expect(bgRect.0.contains("rx="))
    }

    @Test func circleLogoEmitsClipPathAndAspectFill() throws {
        var design = QRDesign()
        design.logo = LogoOptions(imageData: Data([0x89, 0x50]), sizeFraction: 0.2, backing: .circle, knockout: true)
        let svg = try makeSVG(design: design)
        #expect(svg.contains("<clipPath id=\"logoclip\"><circle"))
        #expect(svg.contains("clip-path=\"url(#logoclip)\""))
        #expect(svg.contains("xMidYMid slice"))
    }

    @Test func bareLogoKeepsAspectFitAndNoClip() throws {
        var design = QRDesign()
        design.logo = LogoOptions(imageData: Data([0x89, 0x50]), sizeFraction: 0.2, backing: .none, knockout: true)
        let svg = try makeSVG(design: design)
        #expect(!svg.contains("clipPath"))
        #expect(svg.contains("xMidYMid meet"))
    }

    @Test func logoEmbedsImageDataAsBase64() throws {
        let data = Data([1, 2, 3, 4])
        var design = QRDesign()
        design.logo = LogoOptions(imageData: data, sizeFraction: 0.2, backing: .roundedRect, knockout: true)
        let svg = try makeSVG(design: design)
        #expect(svg.contains("data:image/png;base64,\(data.base64EncodedString())"))
    }

    @Test func frameEmitsBannerTextAndGrowsViewBox() throws {
        var plain = QRDesign()
        let plainSVG = try makeSVG(design: plain)
        plain.frame = QRFrame(text: "SCAN ME", color: .black)
        let framedSVG = try makeSVG(design: plain)

        #expect(framedSVG.contains(">SCAN ME</text>"))
        #expect(isWellFormedXML(framedSVG))

        func viewBoxHeight(_ svg: String) throws -> Double {
            let pattern = /viewBox="0 0 ([0-9.]+) ([0-9.]+)"/
            let match = try #require(svg.firstMatch(of: pattern))
            return try #require(Double(match.2))
        }
        #expect(try viewBoxHeight(framedSVG) > viewBoxHeight(plainSVG))
    }

    @Test func topLabelFrameWithBadgeEmitsKnockoutAndBadge() throws {
        var design = QRDesign()
        design.frame = QRFrame(text: "TAP OR SCAN", color: .black, labelEdge: .top, badgeImageData: Data([1, 2, 3]))
        let svg = try makeSVG(design: design)
        #expect(isWellFormedXML(svg))
        #expect(svg.contains(">TAP OR SCAN</text>"))
        #expect(!svg.contains("<path d=\"M0.5"))  // no banner path for top labels
        #expect(svg.contains("badgeclip"))
        #expect(svg.contains("data:image/png;base64,\(Data([1, 2, 3]).base64EncodedString())"))
    }

    @Test func frameTextIsXMLEscaped() throws {
        var design = QRDesign()
        design.frame = QRFrame(text: "A<B & C>", color: .black)
        let svg = try makeSVG(design: design)
        #expect(svg.contains(">A&lt;B &amp; C&gt;</text>"))
        #expect(isWellFormedXML(svg))
    }

    /// The vector and raster paths share QRLayout, so the SVG must contain one
    /// drawable element per dark module (plus eyes, background, and logo).
    @Test func moduleCountMatchesLayout() throws {
        let matrix = try #require(QRMatrix(payload: "parity", correction: .quartile))
        let design = QRDesign(moduleShape: .square)
        let layout = QRLayout(matrix: matrix, design: design)
        let svg = QRSVGExporter.svg(matrix: matrix, design: design)

        // Square modules are emitted as "M<x> <y>H…V…H…Z" segments: 2 "H"
        // commands per module. The three square eyes contribute 2 per shape
        // (ring outer + ring hole + pupil = 3 shapes each).
        let segments = svg.components(separatedBy: "H").count - 1
        #expect(segments == layout.darkModuleCells.count * 2 + 3 * 3 * 2)
    }
}
