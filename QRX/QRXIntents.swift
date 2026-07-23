import AppIntents
import Foundation
import QRCore
import SwiftData
import UIKit
import UniformTypeIdentifiers
import WidgetKit

/// Pure render logic behind MakeQRCodeIntent, factored out for unit testing.
nonisolated enum IntentQRRenderer {
    /// URLs get scheme normalization; anything else encodes as plain text.
    static func payload(for content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") {
            return QRPayload.url(trimmed)
        }
        return trimmed
    }

    static func renderPNG(content: String) -> Data? {
        let payload = payload(for: content)
        guard !payload.isEmpty,
              let matrix = QRMatrix(payload: payload, correction: .quartile) else { return nil }
        let design = QRDesign(moduleShape: .rounded, eyeShape: .rounded)
        return QRRenderer.render(matrix: matrix, design: design, pixelSize: 1024).pngData()
    }
}

/// "Make a QR for this" — the Shortcuts building block. Runs in the
/// background without opening the app and returns a PNG file.
struct MakeQRCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Make QR Code"
    static let description = IntentDescription(
        "Creates a QR code image from text or a link.",
        categoryName: "Create"
    )

    @Parameter(title: "Content", inputOptions: String.IntentInputOptions(keyboardType: .URL))
    var content: String

    @Parameter(title: "Save to Library", default: false)
    var saveToLibrary: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Make a QR code for \(\.$content)") {
            \.$saveToLibrary
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let png = IntentQRRenderer.renderPNG(content: content) else {
            throw MakeQRCodeError.nothingToEncode
        }

        if saveToLibrary {
            let payload = IntentQRRenderer.payload(for: content)
            let isURL = payload.lowercased().hasPrefix("http")
            let container = try SharedStore.makeContainer()
            let context = ModelContext(container)
            let code = SavedCode(name: isURL ? (URL(string: payload)?.host() ?? "Link") : String(payload.prefix(24)))
            code.payload = payload
            code.typeLabel = isURL ? "URL" : "Text"
            let snapshot: BuilderSnapshot = isURL ? .url(content) : .text(payload)
            code.contentData = (try? JSONEncoder().encode(snapshot)) ?? Data()
            code.designData = (try? JSONEncoder().encode(QRDesign(moduleShape: .rounded, eyeShape: .rounded))) ?? Data()
            context.insert(code)
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }

        let file = IntentFile(data: png, filename: "qrcode.png", type: .png)
        return .result(value: file)
    }

    enum MakeQRCodeError: Error, CustomLocalizedStringResourceConvertible {
        case nothingToEncode

        var localizedStringResource: LocalizedStringResource {
            "There's nothing to encode — provide text or a link."
        }
    }
}

/// Opens a saved code full screen — "show my Wi-Fi code".
struct ShowCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Saved QR Code"
    static let description = IntentDescription(
        "Shows a saved QR code full screen, ready to scan.",
        categoryName: "Library"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Code")
    var code: CodeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$code) full screen")
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "qrx://present/\(code.id.uuidString)") else {
            throw MakeQRCodeIntent.MakeQRCodeError.nothingToEncode
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct QRXShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MakeQRCodeIntent(),
            phrases: [
                "Make a QR code in \(.applicationName)",
                "Create a QR code with \(.applicationName)",
            ],
            shortTitle: "Make QR Code",
            systemImageName: "qrcode"
        )
        AppShortcut(
            intent: ShowCodeIntent(),
            phrases: [
                "Show my QR code in \(.applicationName)",
                "Show my \(.applicationName) code",
            ],
            shortTitle: "Show Code",
            systemImageName: "qrcode.viewfinder"
        )
    }
}
