import AppIntents
import QRCore
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Configuration intent

struct SelectCodeIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Code"
    static let description = IntentDescription("Choose which saved QR code to show.")

    @Parameter(title: "Code")
    var code: CodeEntity?
}

// MARK: - Timeline

struct CodeEntry: TimelineEntry {
    let date: Date
    let id: UUID?
    let name: String
    let typeLabel: String
    let image: UIImage?

    static let empty = CodeEntry(date: .now, id: nil, name: "No saved codes", typeLabel: "Open QRX to create one", image: nil)
}

struct CodeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CodeEntry {
        sampleEntry()
    }

    func snapshot(for configuration: SelectCodeIntent, in context: Context) async -> CodeEntry {
        entry(for: configuration) ?? sampleEntry()
    }

    func timeline(for configuration: SelectCodeIntent, in context: Context) async -> Timeline<CodeEntry> {
        Timeline(entries: [entry(for: configuration) ?? .empty], policy: .never)
    }

    private func entry(for configuration: SelectCodeIntent) -> CodeEntry? {
        guard let code = CodeFetch.code(id: configuration.code?.id),
              let design = code.design,
              !code.payload.isEmpty
        else { return nil }
        let correction: QRCorrectionLevel = design.logo != nil ? .high : .quartile
        guard let matrix = QRMatrix(payload: code.payload, correction: correction) else { return nil }
        let image = QRRenderer.render(matrix: matrix, design: design, pixelSize: 600)
        return CodeEntry(date: .now, id: code.id, name: code.name, typeLabel: code.typeLabel, image: image)
    }

    private func sampleEntry() -> CodeEntry {
        let design = QRDesign(moduleShape: .rounded, eyeShape: .rounded)
        guard let matrix = QRMatrix(payload: "https://example.com", correction: .quartile) else { return .empty }
        let image = QRRenderer.render(matrix: matrix, design: design, pixelSize: 600)
        return CodeEntry(date: .now, id: nil, name: "My Code", typeLabel: "URL", image: image)
    }
}

// MARK: - Views

struct CodeWidgetView: View {
    var entry: CodeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "qrcode")
                    .font(.title2)
                    .widgetAccentable()
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.headline)
                        .widgetAccentable()
                        .lineLimit(1)
                    Text("Show QR code")
                        .font(.caption)
                }
            case .systemMedium:
                HStack(spacing: 14) {
                    qrImage
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(.headline)
                            .foregroundStyle(.black)
                            .lineLimit(2)
                        Text(entry.typeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            default:
                qrImage
            }
        }
        .widgetURL(deepLink)
        .containerBackground(for: .widget) {
            if family == .accessoryCircular || family == .accessoryRectangular {
                Color.clear
            } else {
                // Always white behind the code so it scans in dark mode.
                Color.white
            }
        }
    }

    @ViewBuilder
    private var qrImage: some View {
        if let image = entry.image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            VStack(spacing: 6) {
                Image(systemName: "qrcode")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text(entry.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var deepLink: URL? {
        guard let id = entry.id else { return URL(string: "qrx://") }
        return URL(string: "qrx://present/\(id.uuidString)")
    }
}

// MARK: - Widget

struct PinnedCodeWidget: Widget {
    let kind = "PinnedCode"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCodeIntent.self, provider: CodeProvider()) { entry in
            CodeWidgetView(entry: entry)
        }
        .configurationDisplayName("QR Code")
        .description("Show a saved QR code — perfect for sharing your Wi-Fi with guests.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Control Center

/// One-tap scanner launch from Control Center / the Lock Screen.
struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan QR Code"
    static let description = IntentDescription("Opens the QRX scanner.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "qrx://scan")!))
    }
}

struct ScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScanControl") {
            ControlWidgetButton(action: OpenScannerIntent()) {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
        }
        .displayName("Scan QR Code")
        .description("Scan a QR code with QRX.")
    }
}

@main
struct QRXWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PinnedCodeWidget()
        ScanControl()
    }
}
