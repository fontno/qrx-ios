import QRCore
import SwiftData
import SwiftUI
import WidgetKit

struct LibraryView: View {
    @Query(sort: \SavedCode.updatedAt, order: .reverse) private var codes: [SavedCode]
    @Environment(\.modelContext) private var context
    @State private var renameTarget: SavedCode?
    @State private var renameText = ""
    @State private var presentTarget: SavedCode?

    var body: some View {
        NavigationStack {
            Group {
                if codes.isEmpty {
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
                } else {
                    List {
                        ForEach(codes) { code in
                            NavigationLink {
                                BuilderView(existing: code)
                            } label: {
                                CodeRow(code: code)
                            }
                            .contextMenu {
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
                        .onDelete { offsets in
                            for index in offsets {
                                context.delete(codes[index])
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                }
            }
            .navigationTitle("QRX")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            .onOpenURL { url in
                // qrx://present/<uuid> — from widget taps.
                guard url.scheme == "qrx", url.host() == "present",
                      let id = UUID(uuidString: url.lastPathComponent),
                      let code = codes.first(where: { $0.id == id })
                else { return }
                presentTarget = code
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
}

private struct CodeRow: View {
    let code: SavedCode
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "qrcode")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
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
        .task(id: code.updatedAt) {
            let payload = code.payload
            guard !payload.isEmpty, let design = code.design else { return }
            let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
            thumbnail = await Task.detached {
                guard let matrix = QRMatrix(payload: payload, correction: correction) else { return nil }
                return QRRenderer.render(matrix: matrix, design: design, pixelSize: 208)
            }.value
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: SavedCode.self, inMemory: true)
}
