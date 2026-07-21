import CoreTransferable
import QRCore
import UIKit
import UniformTypeIdentifiers

/// Lazily renders a 2048px PNG when the share actually happens.
/// nonisolated: the export closures run off the main actor.
nonisolated struct PNGExport: Transferable {
    let payload: String
    let design: QRDesign

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            let correction: QRCorrectionLevel = export.design.logo != nil ? .high : .quartile
            guard let matrix = QRMatrix(payload: export.payload, correction: correction) else {
                throw ExportError.encodingFailed
            }
            let image = QRRenderer.render(matrix: matrix, design: export.design, pixelSize: 2048)
            guard let data = image.pngData() else { throw ExportError.encodingFailed }
            return data
        }
        .suggestedFileName("qrcode.png")
    }
}

nonisolated struct SVGExport: Transferable {
    let payload: String
    let design: QRDesign

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .svg) { export in
            let correction: QRCorrectionLevel = export.design.logo != nil ? .high : .quartile
            guard let matrix = QRMatrix(payload: export.payload, correction: correction) else {
                throw ExportError.encodingFailed
            }
            return Data(QRSVGExporter.svg(matrix: matrix, design: export.design).utf8)
        }
        .suggestedFileName("qrcode.svg")
    }
}

enum ExportError: Error {
    case encodingFailed
}
