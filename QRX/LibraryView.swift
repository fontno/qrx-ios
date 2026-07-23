import QRCore
import SwiftData
import SwiftUI
import WidgetKit

enum LibraryViewMode: String {
    case list
    case grid
}

struct LibraryView: View {
    @Query(sort: \SavedCode.updatedAt, order: .reverse) private var codes: [SavedCode]
    @Environment(\.modelContext) private var context
    @AppStorage("libraryViewMode") private var viewModeRaw = LibraryViewMode.list.rawValue
    @State private var renameTarget: SavedCode?
    @State private var renameText = ""
    @State private var presentTarget: SavedCode?
    @State private var showingScanner = false

    private var viewMode: LibraryViewMode {
        LibraryViewMode(rawValue: viewModeRaw) ?? .list
    }

    var body: some View {
        NavigationStack {
            Group {
                if codes.isEmpty {
                    emptyState
                } else if viewMode == .list {
                    listView
                } else {
                    gridView
                }
            }
            .navigationTitle("QRX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !codes.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModeRaw = (viewMode == .list ? LibraryViewMode.grid : .list).rawValue
                        } label: {
                            Label(
                                viewMode == .list ? "Grid View" : "List View",
                                systemImage: viewMode == .list ? "square.grid.2x2" : "list.bullet"
                            )
                        }
                        .accessibilityIdentifier("library.viewMode")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("library.scan")
                    NavigationLink {
                        BuilderView()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("library.add")
                }
            }
            .fullScreenCover(item: $presentTarget) { code in
                PresentView(code: code)
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView()
                    .tint(.primary)
            }
            .onOpenURL { url in
                guard url.scheme == "qrx" else { return }
                switch url.host() {
                case "present":
                    // qrx://present/<uuid> — widget taps and ShowCodeIntent.
                    guard let id = UUID(uuidString: url.lastPathComponent),
                          let code = codes.first(where: { $0.id == id })
                    else { return }
                    presentTarget = code
                case "scan":
                    // qrx://scan — the Control Center button.
                    showingScanner = true
                default:
                    break
                }
            }
            .alert("Rename Code", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if let target = renameTarget, !renameText.isEmpty {
                        target.name = renameText
                        target.updatedAt = .now
                    }
                }
            }
        }
    }

    // MARK: - Presentations

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Codes Yet", systemImage: "qrcode")
        } description: {
            Text("Create a branded QR code for your business, Wi-Fi, or contact card. Codes are generated on-device and never expire.")
        } actions: {
            NavigationLink {
                BuilderView()
            } label: {
                Text("Create Your First Code")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("library.createFirst")
        }
    }

    private var listView: some View {
        List {
            ForEach(codes) { code in
                NavigationLink {
                    BuilderView(existing: code)
                } label: {
                    CodeRow(code: code)
                }
                .contextMenu {
                    codeActions(for: code)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(codes[index])
                }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                ForEach(codes) { code in
                    NavigationLink {
                        BuilderView(existing: code)
                    } label: {
                        CodeCard(code: code)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        codeActions(for: code)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func codeActions(for code: SavedCode) -> some View {
        Button {
            presentTarget = code
        } label: {
            Label("Present", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        Button {
            code.pinned.toggle()
            WidgetCenter.shared.reloadAllTimelines()
        } label: {
            Label(code.pinned ? "Unpin from Widgets" : "Pin to Widgets",
                  systemImage: code.pinned ? "pin.slash" : "pin")
        }
        Button {
            renameTarget = code
            renameText = code.name
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        ShareLink(
            item: PNGExport(payload: code.payload, design: code.design ?? QRDesign()),
            preview: SharePreview(code.name, image: Image(systemName: "qrcode"))
        ) {
            Label("Share PNG", systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive) {
            context.delete(code)
            WidgetCenter.shared.reloadAllTimelines()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Thumbnail loading

/// Renders a code's thumbnail off-main, re-rendering when the code changes.
private struct CodeThumbnail: View {
    let code: SavedCode
    let pixelSize: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: code.updatedAt) {
            let payload = code.payload
            guard !payload.isEmpty, let design = code.design else { return }
            let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
            let size = pixelSize
            image = await Task.detached {
                guard let matrix = QRMatrix(payload: payload, correction: correction) else { return nil }
                return QRRenderer.render(matrix: matrix, design: design, pixelSize: size)
            }.value
        }
    }
}

// MARK: - List row

private struct CodeRow: View {
    let code: SavedCode

    var body: some View {
        HStack(spacing: 12) {
            CodeThumbnail(code: code, pixelSize: 208)
                .frame(width: 52, height: 52)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(code.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if code.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(code.typeLabel) · \(code.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Grid card

private struct CodeCard: View {
    let code: SavedCode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CodeThumbnail(code: code, pixelSize: 480)
                .padding(10)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(code.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if code.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(code.typeLabel) · \(code.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: SavedCode.self, inMemory: true)
}
