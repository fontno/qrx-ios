import CoreImage
import UIKit
import Vision

enum ScanState: Equatable {
    case idle
    case checking
    case scans
    case fails
}

/// Decodes the rendered image with Vision and confirms the payload round-trips.
/// This is the trust feature: never let someone export a code that won't scan.
enum ScanCheck {
    static func verify(image: UIImage, expectedPayload: String) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]
        do {
            let observations = try await request.perform(on: cgImage)
            return observations.contains { $0.payloadString == expectedPayload }
        } catch {
            // Vision's barcode detector is unavailable on the simulator;
            // CIDetector decodes fine everywhere.
            return await Task.detached {
                ciDetectorCheck(cgImage: cgImage, expected: expectedPayload)
            }.value
        }
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
