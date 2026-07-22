import QRCore
import SwiftUI

/// Full-screen presentation of a code — hand your phone to a guest.
/// Reached from the library, widget taps (qrx://present/<id>), and tapping
/// the builder preview.
struct PresentView: View {
    let name: String
    let typeLabel: String
    let payload: String
    let design: QRDesign?
    @State private var rendered: UIImage?
    @Environment(\.dismiss) private var dismiss

    init(code: SavedCode) {
        name = code.name
        typeLabel = code.typeLabel
        payload = code.payload
        design = code.design
    }

    init(name: String, typeLabel: String, payload: String, design: QRDesign) {
        self.name = name
        self.typeLabel = typeLabel
        self.payload = payload
        self.design = design
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if let rendered {
                Image(uiImage: rendered)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(24)
            } else {
                ProgressView()
            }
            VStack(spacing: 4) {
                Text(name)
                    .font(.title2.weight(.semibold))
                Text(typeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 24)
        }
        // Solid white regardless of appearance: maximum scan contrast.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .task {
            let payload = payload
            guard !payload.isEmpty, let design else { return }
            let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
            rendered = await Task.detached(priority: .userInitiated) {
                guard let matrix = QRMatrix(payload: payload, correction: correction) else { return nil }
                return QRRenderer.render(matrix: matrix, design: design, pixelSize: 1200)
            }.value
        }
    }
}
