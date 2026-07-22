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
    @State private var savedToPhotos = false
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
        NavigationStack {
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
                    if savedToPhotos {
                        Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.green)
                            .padding(.top, 8)
                            .transition(.opacity)
                    }
                }
                Spacer()
            }
            // Solid white regardless of appearance: maximum scan contrast.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    .accessibilityIdentifier("present.close")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let design {
                        ShareLink(
                            item: PNGExport(payload: payload, design: design),
                            preview: SharePreview(name, image: sharePreviewImage)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("present.share")
                        Button {
                            downloadToPhotos()
                        } label: {
                            Label("Download", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("present.download")
                        .disabled(savedToPhotos)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
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

    private var sharePreviewImage: Image {
        rendered.map { Image(uiImage: $0) } ?? Image(systemName: "qrcode")
    }

    /// Saves a full-resolution render to the photo library (add-only access).
    private func downloadToPhotos() {
        guard let design else { return }
        let payload = payload
        Task {
            let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
            let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let matrix = QRMatrix(payload: payload, correction: correction) else { return nil }
                return QRRenderer.render(matrix: matrix, design: design, pixelSize: 2048)
            }.value
            guard let image else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            withAnimation {
                savedToPhotos = true
            }
        }
    }
}
