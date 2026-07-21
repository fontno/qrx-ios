import CoreImage
import UIKit

enum ScanState: Equatable {
    case idle
    case checking
    case scans
    case fails
}

/// Decodes the rendered image and confirms the payload round-trips.
/// This is the trust feature: never let someone export a code that won't scan.
///
/// Deliberately uses CIDetector rather than Vision: Vision's barcode detector
/// is unavailable on simulators and hangs on virtualized CI runners, while
/// CIDetector decodes deterministically everywhere. The engine test suite
/// (QRCoreTests) standardizes on the same decoder.
enum ScanCheck {
    static func verify(image: UIImage, expectedPayload: String) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        return await Task.detached(priority: .userInitiated) {
            ciDetectorCheck(cgImage: cgImage, expected: expectedPayload)
        }.value
    }

    private nonisolated static func ciDetectorCheck(cgImage: CGImage, expected: String) -> Bool {
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: CIImage(cgImage: cgImage)) ?? []
        return features.contains { ($0 as? CIQRCodeFeature)?.messageString == expected }
    }
}
