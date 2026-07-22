import QRCore
import SwiftData
import SwiftUI
import WidgetKit

enum BuilderSection: String, CaseIterable, Identifiable {
    case content = "Content"
    case shape = "Shape"
    case colors = "Colors"
    case frame = "Frame"
    case logo = "Logo"

    var id: String { rawValue }
}

struct BuilderView: View {
    private let existing: SavedCode?
    @State private var model: BuilderModel
    @State private var section: BuilderSection = .content
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
            sectionChips
            Form {
                switch section {
                case .content:
                    ContentFieldsView(model: model)
                case .shape:
                    ShapeSectionView(model: model)
                case .colors:
                    ColorsSectionView(model: model)
                case .frame:
                    FrameSectionView(model: model)
                case .logo:
                    LogoSectionView(model: model)
                }
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
        VStack(spacing: 6) {
            Group {
                if let rendered {
                    Image(uiImage: rendered)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
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
            .frame(maxHeight: 230)

            scanBadge
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 296)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
        .padding(.top, 8)
    }

    @ViewBuilder
    private var scanBadge: some View {
        Group {
            switch scanState {
            case .idle:
                EmptyView()
            case .checking:
                pill("Checking…", systemImage: "ellipsis", tint: .secondary)
            case .scans:
                pill("Scans reliably", systemImage: "checkmark.circle.fill", tint: .green)
            case .fails:
                pill("May not scan — reduce logo size", systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
    }

    private func pill(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private var sectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BuilderSection.allCases) { candidate in
                    let isSelected = section == candidate
                    Button {
                        section = candidate
                    } label: {
                        Text(candidate.rawValue)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.primary : Color(.secondarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("builder.section.\(candidate.rawValue)")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
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
