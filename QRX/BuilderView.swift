import QRCore
import SwiftData
import SwiftUI
import WidgetKit

struct BuilderView: View {
    private let existing: SavedCode?
    @State private var model: BuilderModel
    @State private var rendered: UIImage?
    @State private var scanState: ScanState = .idle
    @State private var showingSavePrompt = false
    @State private var showingFullPreview = false
    @State private var saveName = ""
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(existing: SavedCode? = nil) {
        self.existing = existing
        let model = BuilderModel()
        if let existing {
            model.load(from: existing)
        }
        _model = State(initialValue: model)
    }

    private struct RenderKey: Equatable {
        let payload: String
        let design: QRDesign
    }

    var body: some View {
        VStack(spacing: 0) {
            preview
                .padding(.horizontal)
                .padding(.bottom, 8)
            Form {
                ContentFieldsView(model: model)
                DesignPanelView(model: model)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(existing?.name ?? "New Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !model.payload.isEmpty {
                    Button {
                        save()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .accessibilityIdentifier("builder.save")
                    Menu {
                        ShareLink(
                            item: PNGExport(payload: model.payload, design: model.design),
                            preview: SharePreview("QR Code", image: sharePreviewImage)
                        ) {
                            Label("Share PNG", systemImage: "photo")
                        }
                        ShareLink(
                            item: SVGExport(payload: model.payload, design: model.design),
                            preview: SharePreview("QR Code (SVG)", image: sharePreviewImage)
                        ) {
                            Label("Share SVG (vector)", systemImage: "square.and.arrow.up.on.square")
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("builder.shareMenu")
                    if existing != nil {
                        Button {
                            duplicate()
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        .accessibilityIdentifier("builder.duplicate")
                    }
                }
            }
        }
        .task(id: RenderKey(payload: model.payload, design: model.design)) {
            await regenerate()
        }
        .fullScreenCover(isPresented: $showingFullPreview) {
            PresentView(
                name: existing?.name ?? model.suggestedName,
                typeLabel: model.contentType.rawValue,
                payload: model.payload,
                design: model.design
            )
        }
        .alert("Save Code", isPresented: $showingSavePrompt) {
            TextField("Name", text: $saveName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let code = SavedCode(name: saveName.isEmpty ? model.suggestedName : saveName)
                model.write(to: code)
                context.insert(code)
                WidgetCenter.shared.reloadAllTimelines()
                dismiss()
            }
        } message: {
            Text("Give this code a name for your library.")
        }
    }

    /// Saves the current builder state as a new library entry, so users can
    /// riff on an existing code without touching the original.
    private func duplicate() {
        guard let existing else { return }
        let copy = SavedCode(name: existing.name + " Copy")
        model.write(to: copy)
        context.insert(copy)
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }

    private func save() {
        if let existing {
            model.write(to: existing)
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } else {
            saveName = model.suggestedName
            showingSavePrompt = true
        }
    }

    private var sharePreviewImage: Image {
        rendered.map { Image(uiImage: $0) } ?? Image(systemName: "qrcode")
    }

    @ViewBuilder
    private var preview: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                if let rendered {
                    Image(uiImage: rendered)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(14)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingFullPreview = true
                        }
                        .accessibilityIdentifier("builder.preview")
                        .accessibilityAddTraits(.isButton)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 56))
                            .foregroundStyle(.tertiary)
                        Text("Enter content below")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 260)

            scanBadge
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var scanBadge: some View {
        switch scanState {
        case .idle:
            EmptyView()
        case .checking:
            Label("Checking…", systemImage: "ellipsis")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        case .scans:
            Label("Scans", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case .fails:
            Label("May not scan — reduce logo size or simplify styling", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }

    private func regenerate() async {
        // Debounce keystrokes; .task(id:) cancels superseded runs.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }

        let payload = model.payload
        guard !payload.isEmpty else {
            rendered = nil
            scanState = .idle
            return
        }

        let design = model.design
        let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let matrix = QRMatrix(payload: payload, correction: correction) else { return nil }
            return QRRenderer.render(matrix: matrix, design: design, pixelSize: 1024)
        }.value

        guard !Task.isCancelled else { return }
        rendered = image
        guard let image else {
            scanState = .fails
            return
        }
        scanState = .checking
        let ok = await ScanCheck.verify(image: image, expectedPayload: payload)
        if !Task.isCancelled {
            scanState = ok ? .scans : .fails
        }
    }
}

#Preview {
    NavigationStack {
        BuilderView()
    }
    .modelContainer(for: SavedCode.self, inMemory: true)
}
