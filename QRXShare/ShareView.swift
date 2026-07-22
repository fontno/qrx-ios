import QRCore
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

/// Instant QR from whatever was shared, with one-tap save to the library.
struct ShareView: View {
    let loadContent: () async -> SharedContent?
    let finish: () -> Void
    let cancel: () -> Void

    @State private var content: SharedContent?
    @State private var payload = ""
    @State private var rendered: UIImage?
    @State private var name = ""
    @State private var state: LoadState = .loading
    @State private var saved = false

    private let design = QRDesign(moduleShape: .rounded, eyeShape: .rounded)

    enum LoadState {
        case loading
        case ready
        case unsupported
        case saveFailed
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView()
                case .unsupported:
                    ContentUnavailableView(
                        "Nothing to Encode",
                        systemImage: "qrcode",
                        description: Text("Share a link or text to make a QR code.")
                    )
                case .saveFailed:
                    ContentUnavailableView(
                        "Couldn't Save",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The shared library isn't available. Open QRX once, then try again.")
                    )
                case .ready:
                    VStack(spacing: 16) {
                        if let rendered {
                            Image(uiImage: rendered)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(maxHeight: 280)
                                .padding(.horizontal, 32)
                        }
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 32)
                        if saved {
                            Label("Saved to your library", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Save QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(state != .ready || saved)
                }
            }
        }
        .task {
            content = await loadContent()
            switch content {
            case .url(let raw):
                payload = QRPayload.url(raw)
                name = URL(string: payload)?.host() ?? "Link"
            case .text(let text):
                payload = text
                name = String(text.prefix(24))
            case nil:
                state = .unsupported
                return
            }
            guard let matrix = QRMatrix(payload: payload, correction: .quartile) else {
                state = .unsupported
                return
            }
            rendered = QRRenderer.render(matrix: matrix, design: design, pixelSize: 800)
            state = .ready
        }
    }

    private func save() {
        do {
            let container = try SharedStore.makeContainer()
            let context = ModelContext(container)
            let code = SavedCode(name: name.isEmpty ? "QR Code" : name)
            code.payload = payload
            let snapshot: BuilderSnapshot
            switch content {
            case .url(let raw): snapshot = .url(raw)
            case .text(let text): snapshot = .text(text)
            case nil: snapshot = .text(payload)
            }
            code.typeLabel = snapshot.contentType
            code.contentData = (try? JSONEncoder().encode(snapshot)) ?? Data()
            code.designData = (try? JSONEncoder().encode(design)) ?? Data()
            context.insert(code)
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
            saved = true
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                finish()
            }
        } catch {
            state = .saveFailed
        }
    }
}
