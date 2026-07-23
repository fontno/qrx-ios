import CoreImage
import Foundation
import Testing
import UIKit
@testable import QRX

@Suite("Make QR Code intent rendering")
struct IntentTests {
    @Test func urlContentGetsSchemeNormalized() {
        #expect(IntentQRRenderer.payload(for: "www.example.com") == "https://www.example.com")
        #expect(IntentQRRenderer.payload(for: "https://example.com") == "https://example.com")
    }

    @Test func plainTextPassesThrough() {
        #expect(IntentQRRenderer.payload(for: "  hello world  ") == "hello world")
    }

    @Test func rendersScannablePNG() throws {
        let data = try #require(IntentQRRenderer.renderPNG(content: "https://example.com"))
        let image = try #require(UIImage(data: data))
        #expect(image.size.width == 1024)

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let cgImage = try #require(image.cgImage)
        let messages = (detector?.features(in: CIImage(cgImage: cgImage)) ?? [])
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        #expect(messages == ["https://example.com"])
    }

    @Test func emptyContentRendersNothing() {
        #expect(IntentQRRenderer.renderPNG(content: "   ") == nil)
    }
}
