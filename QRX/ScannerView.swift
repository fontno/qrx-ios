import AVFoundation
import QRCore
import SwiftData
import SwiftUI
import Vision
import VisionKit
import WidgetKit

/// Camera scanner with an offline safety check on scanned links.
struct ScannerView: View {
    @State private var scannedPayload: String?
    @State private var cameraAllowed: Bool?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let scannedPayload {
                    ScanResultView(payload: scannedPayload) {
                        self.scannedPayload = nil
                    }
                } else {
                    scannerBody
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    .accessibilityIdentifier("scanner.close")
                }
            }
        }
        .task {
            // UI-test hook: cameras don't exist on simulators.
            if let injected = ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("--uitest-scan=") }) {
                scannedPayload = String(injected.dropFirst("--uitest-scan=".count))
                return
            }
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    @ViewBuilder
    private var scannerBody: some View {
        if cameraAllowed == true, DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            DataScannerRepresentable { payload in
                scannedPayload = payload
            }
            .ignoresSafeArea(edges: .bottom)
        } else if cameraAllowed == false {
            ContentUnavailableView {
                Label("Camera Access Needed", systemImage: "camera")
            } description: {
                Text("Allow camera access in Settings to scan QR codes.")
            }
        } else if cameraAllowed == true {
            ContentUnavailableView {
                Label("Camera Unavailable", systemImage: "camera")
            } description: {
                Text("Scanning needs a device with a camera.")
            }
        } else {
            ProgressView()
        }
    }
}

// MARK: - Camera

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    scanner.stopScanning()
                    onScan(payload)
                    return
                }
            }
        }
    }
}

// MARK: - Result

/// What kind of thing did we scan? Display-only classification.
enum ScannedKind {
    case url(String)
    case wifi
    case contact
    case phone
    case email
    case text

    init(payload: String) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            self = .url(trimmed)
        } else if lower.hasPrefix("www."), trimmed.contains(".") {
            self = .url("https://" + trimmed)
        } else if lower.hasPrefix("wifi:") {
            self = .wifi
        } else if lower.hasPrefix("begin:vcard") {
            self = .contact
        } else if lower.hasPrefix("tel:") {
            self = .phone
        } else if lower.hasPrefix("mailto:") {
            self = .email
        } else {
            self = .text
        }
    }

    var label: String {
        switch self {
        case .url: "Link"
        case .wifi: "Wi-Fi Network"
        case .contact: "Contact"
        case .phone: "Phone Number"
        case .email: "Email"
        case .text: "Text"
        }
    }

    var icon: String {
        switch self {
        case .url: "link"
        case .wifi: "wifi"
        case .contact: "person.crop.circle"
        case .phone: "phone"
        case .email: "envelope"
        case .text: "text.alignleft"
        }
    }
}

struct ScanResultView: View {
    let payload: String
    let rescan: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var confirmingOpen = false
    @State private var savedToLibrary = false
    @State private var copied = false

    private var kind: ScannedKind { ScannedKind(payload: payload) }

    private var safety: URLSafety.Report? {
        if case .url(let url) = kind {
            return URLSafety.analyze(url)
        }
        return nil
    }

    var body: some View {
        List {
            Section {
                Label(kind.label, systemImage: kind.icon)
                    .font(.headline)
                Text(payload)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(6)
            }

            if let safety {
                Section {
                    safetyCard(safety)
                }
            }

            Section {
                if case .url(let url) = kind {
                    Button {
                        if safety?.verdict == .clear {
                            open(url)
                        } else {
                            confirmingOpen = true
                        }
                    } label: {
                        Label("Open Link", systemImage: "safari")
                    }
                    .accessibilityIdentifier("scanner.open")
                    .confirmationDialog(
                        "This link has warning signs. Open it anyway?",
                        isPresented: $confirmingOpen,
                        titleVisibility: .visible
                    ) {
                        Button("Open Anyway", role: .destructive) {
                            open(url)
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                Button {
                    UIPasteboard.general.string = payload
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                Button {
                    saveToLibrary()
                } label: {
                    Label(savedToLibrary ? "Saved to Library" : "Save to Library",
                          systemImage: savedToLibrary ? "checkmark" : "square.and.arrow.down")
                }
                .disabled(savedToLibrary)
                .accessibilityIdentifier("scanner.save")
            }

            Section {
                Button {
                    rescan()
                } label: {
                    Label("Scan Again", systemImage: "qrcode.viewfinder")
                }
                .accessibilityIdentifier("scanner.rescan")
            }
        }
    }

    @ViewBuilder
    private func safetyCard(_ report: URLSafety.Report) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch report.verdict {
            case .clear:
                Label("No red flags detected", systemImage: "checkmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Looks structurally normal — still only open links from sources you trust.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .caution:
                Label("Be careful with this link", systemImage: "exclamationmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            case .suspicious:
                Label("Suspicious link", systemImage: "xmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            ForEach(report.flags, id: \.self) { flag in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(flag.explanation)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func open(_ url: String) {
        if let parsed = URL(string: url) {
            openURL(parsed)
        }
    }

    private func saveToLibrary() {
        let snapshot: BuilderSnapshot
        let name: String
        switch kind {
        case .url(let url):
            snapshot = .url(url)
            name = URL(string: url)?.host() ?? "Scanned Link"
        default:
            snapshot = .text(payload)
            name = "Scanned \(kind.label)"
        }
        let design = QRDesign(moduleShape: .rounded, eyeShape: .rounded)
        let code = SavedCode(name: name)
        code.payload = payload
        code.typeLabel = kind.label
        code.contentData = (try? JSONEncoder().encode(snapshot)) ?? Data()
        code.designData = (try? JSONEncoder().encode(design)) ?? Data()
        context.insert(code)
        WidgetCenter.shared.reloadAllTimelines()
        savedToLibrary = true
    }
}
