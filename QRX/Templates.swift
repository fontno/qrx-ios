import QRCore
import SwiftUI

// MARK: - Brand logos

/// Bundled brand badges (see DesignAssets/gen_brand_logos.sh). Logos are
/// trademarks of their respective owners, used to indicate where a code points.
enum BrandLogo: String, CaseIterable, Identifiable {
    case google, facebook, instagram, x, tiktok, youtube, whatsapp, spotify, linkedin

    var id: String { rawValue }

    var assetName: String { "brand.\(rawValue)" }

    var displayName: String {
        switch self {
        case .google: "Google"
        case .facebook: "Facebook"
        case .instagram: "Instagram"
        case .x: "X"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        case .whatsapp: "WhatsApp"
        case .spotify: "Spotify"
        case .linkedin: "LinkedIn"
        }
    }

    func pngData() -> Data? {
        UIImage(named: assetName)?.pngData()
    }
}

/// Horizontal quick-pick row of brand badges.
struct BrandPickerRow: View {
    let includeNone: Bool
    let onPick: (BrandLogo?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if includeNone {
                    Button {
                        onPick(nil)
                    } label: {
                        Image(systemName: "slash.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(Color.primary.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("No badge")
                }
                ForEach(BrandLogo.allCases) { brand in
                    Button {
                        onPick(brand)
                    } label: {
                        Image(brand.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(brand.displayName)
                    .accessibilityIdentifier("brand.\(brand.rawValue)")
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Templates

struct QRTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let contentTypeRaw: String
    let design: QRDesign
}

extension QRTemplate {
    /// Built on demand so brand assets load from the catalog.
    static var all: [QRTemplate] {
        let googleBlue = RGBAColor(red: 0.1, green: 0.37, blue: 0.71)
        return [
            QRTemplate(
                id: "review",
                name: "Review Us",
                subtitle: "Google review sign",
                contentTypeRaw: "URL",
                design: QRDesign(
                    moduleShape: .rounded,
                    eyeShape: .rounded,
                    foreground: .solid(RGBAColor(red: 0.08, green: 0.09, blue: 0.11)),
                    frame: QRFrame(text: "TAP OR SCAN", color: googleBlue, labelEdge: .top,
                                   badgeImageData: BrandLogo.google.pngData())
                )
            ),
            QRTemplate(
                id: "wifi",
                name: "Wi-Fi Guest",
                subtitle: "Password-free joining",
                contentTypeRaw: "Wi-Fi",
                design: QRDesign(
                    moduleShape: .rounded,
                    eyeShape: .rounded,
                    frame: QRFrame(text: "SCAN TO JOIN", color: .black)
                )
            ),
            QRTemplate(
                id: "follow",
                name: "Follow Us",
                subtitle: "Instagram profile",
                contentTypeRaw: "URL",
                design: QRDesign(
                    moduleShape: .circle,
                    eyeShape: .rounded,
                    foreground: .linearGradient(
                        RGBAColor(red: 0.51, green: 0.23, blue: 0.71),
                        RGBAColor(red: 0.99, green: 0.35, blue: 0.29),
                        angleDegrees: 45
                    ),
                    frame: QRFrame(text: "FOLLOW US", color: RGBAColor(red: 0.76, green: 0.21, blue: 0.52),
                                   badgeImageData: BrandLogo.instagram.pngData())
                )
            ),
            QRTemplate(
                id: "watch",
                name: "Watch Us",
                subtitle: "YouTube channel",
                contentTypeRaw: "URL",
                design: QRDesign(
                    moduleShape: .rounded,
                    eyeShape: .circle,
                    foreground: .solid(RGBAColor(red: 0.78, green: 0.05, blue: 0.05)),
                    frame: QRFrame(text: "WATCH US", color: RGBAColor(red: 0.78, green: 0.05, blue: 0.05),
                                   badgeImageData: BrandLogo.youtube.pngData())
                )
            ),
            QRTemplate(
                id: "menu",
                name: "Menu",
                subtitle: "Table-tent menu link",
                contentTypeRaw: "URL",
                design: QRDesign(
                    moduleShape: .circle,
                    eyeShape: .rounded,
                    foreground: .solid(RGBAColor(red: 0.42, green: 0.26, blue: 0.13)),
                    frame: QRFrame(text: "SCAN FOR MENU", color: RGBAColor(red: 0.42, green: 0.26, blue: 0.13))
                )
            ),
            QRTemplate(
                id: "card",
                name: "Business Card",
                subtitle: "Share your contact",
                contentTypeRaw: "Contact",
                design: QRDesign(
                    moduleShape: .square,
                    eyeShape: .square,
                    foreground: .solid(RGBAColor(red: 0.05, green: 0.05, blue: 0.15))
                )
            ),
        ]
    }
}

// MARK: - Chooser

struct TemplateChooserView: View {
    let onSelect: (QRTemplate?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    blankCard
                    ForEach(QRTemplate.all) { template in
                        Button {
                            dismiss()
                            onSelect(template)
                        } label: {
                            TemplateCard(template: template)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("template.\(template.id)")
                    }
                }
                .padding()
            }
            .navigationTitle("New Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
        .tint(.primary)
    }

    private var blankCard: some View {
        Button {
            dismiss()
            onSelect(nil)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.largeTitle.weight(.light))
                            .foregroundStyle(.secondary)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blank")
                        .font(.subheadline.weight(.medium))
                    Text("Start from scratch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("template.blank")
    }
}

private struct TemplateCard: View {
    let template: QRTemplate
    @State private var preview: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
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
                Text(template.name)
                    .font(.subheadline.weight(.medium))
                Text(template.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .task {
            let design = template.design
            preview = await Task.detached {
                guard let matrix = QRMatrix(payload: "https://example.com", correction: .quartile) else { return nil }
                return QRRenderer.render(matrix: matrix, design: design, pixelSize: 460)
            }.value
        }
    }
}
