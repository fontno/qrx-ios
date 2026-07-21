import Foundation
import QRCore
import SwiftData

/// All defaults are inline (not in init) so future CloudKit sync and light
/// migrations work without a custom migration plan.
@Model
final class SavedCode {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// The encoded QR payload string, denormalized for rendering rows and
    /// (later) widgets without replaying builder logic.
    var payload: String = ""
    var typeLabel: String = ""
    /// JSON-encoded BuilderSnapshot — restores the builder's form fields.
    var contentData: Data = Data()
    /// JSON-encoded QRDesign.
    var designData: Data = Data()

    init(name: String) {
        self.name = name
    }

    var design: QRDesign? {
        try? JSONDecoder().decode(QRDesign.self, from: designData)
    }
}

/// Everything needed to restore the builder form exactly as the user left it
/// (including inputs not baked into the design, like monogram initials).
struct BuilderSnapshot: Codable {
    var contentType: String
    var urlString: String
    var text: String
    var wifiSSID: String
    var wifiPassword: String
    var wifiSecurity: String
    var wifiHidden: Bool
    var emailTo: String
    var emailSubject: String
    var phoneNumber: String
    var contactName: String
    var contactOrg: String
    var contactPhone: String
    var contactEmail: String
    var contactWebsite: String
    var logoSource: String
    var photoLogoData: Data?
    var monogramText: String
    var monogramColor: RGBAColor
    var monogramBackground: RGBAColor
    var logoSizeFraction: Double
    var logoBacking: String
    var logoKnockout: Bool
}

extension BuilderModel {
    func snapshot() -> BuilderSnapshot {
        BuilderSnapshot(
            contentType: contentType.rawValue,
            urlString: urlString,
            text: text,
            wifiSSID: wifiSSID,
            wifiPassword: wifiPassword,
            wifiSecurity: wifiSecurity.rawValue,
            wifiHidden: wifiHidden,
            emailTo: emailTo,
            emailSubject: emailSubject,
            phoneNumber: phoneNumber,
            contactName: contactName,
            contactOrg: contactOrg,
            contactPhone: contactPhone,
            contactEmail: contactEmail,
            contactWebsite: contactWebsite,
            logoSource: logoSource.rawValue,
            photoLogoData: photoLogoData,
            monogramText: monogramText,
            monogramColor: monogramColor,
            monogramBackground: monogramBackground,
            logoSizeFraction: logoSizeFraction,
            logoBacking: logoBacking.rawValue,
            logoKnockout: logoKnockout
        )
    }

    func apply(_ s: BuilderSnapshot) {
        contentType = ContentType(rawValue: s.contentType) ?? .url
        urlString = s.urlString
        text = s.text
        wifiSSID = s.wifiSSID
        wifiPassword = s.wifiPassword
        wifiSecurity = WifiSecurity(rawValue: s.wifiSecurity) ?? .wpa
        wifiHidden = s.wifiHidden
        emailTo = s.emailTo
        emailSubject = s.emailSubject
        phoneNumber = s.phoneNumber
        contactName = s.contactName
        contactOrg = s.contactOrg
        contactPhone = s.contactPhone
        contactEmail = s.contactEmail
        contactWebsite = s.contactWebsite
        logoSource = LogoSource(rawValue: s.logoSource) ?? .none
        photoLogoData = s.photoLogoData
        monogramText = s.monogramText
        monogramColor = s.monogramColor
        monogramBackground = s.monogramBackground
        logoSizeFraction = s.logoSizeFraction
        logoBacking = LogoBacking(rawValue: s.logoBacking) ?? .roundedRect
        logoKnockout = s.logoKnockout
    }

    /// Loads a saved code back into the builder.
    func load(from code: SavedCode) {
        if let snapshot = try? JSONDecoder().decode(BuilderSnapshot.self, from: code.contentData) {
            apply(snapshot)
        }
        if let design = code.design {
            self.design = design
        }
    }

    /// Writes the builder state into a SavedCode record.
    func write(to code: SavedCode) {
        code.payload = payload
        code.typeLabel = contentType.rawValue
        code.contentData = (try? JSONEncoder().encode(snapshot())) ?? Data()
        code.designData = (try? JSONEncoder().encode(design)) ?? Data()
        code.updatedAt = .now
    }

    var suggestedName: String {
        let name: String = switch contentType {
        case .url: URL(string: payload)?.host() ?? "Link"
        case .text: String(text.prefix(24))
        case .wifi: wifiSSID
        case .contact: contactName
        case .email: emailTo
        case .phone: phoneNumber
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "QR Code" : trimmed
    }
}
