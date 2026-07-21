import QRCore
import SwiftUI

/// Full-screen presentation of a saved code — hand your phone to a guest.
/// Reached from the library and from widget taps (qrx://present/<id>).
struct PresentView: View {
    let code: SavedCode
    @State private var rendered: UIImage?
    @Environment(\.dismiss) private var dismiss

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
                Text(code.name)
                    .font(.title2.weight(.semibold))
                Text(code.typeLabel)
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
            let payload = code.payload
            guard !payload.isEmpty, let design = code.design else { return }
            let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
            rendered = await Task.detached(priority: .userInitiated) {
                guard let matrix = QRMatrix(payload: payload, correction: correction) else { return nil }
                return QRRenderer.render(matrix: matrix, design: design, pixelSize: 1200)
            }.value
        }
    }
}
