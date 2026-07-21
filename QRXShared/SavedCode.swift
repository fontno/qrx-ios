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
    /// The encoded QR payload string, denormalized so rows and widgets render
    /// without replaying builder logic.
    var payload: String = ""
    var typeLabel: String = ""
    /// Pinned codes surface first in widgets.
    var pinned: Bool = false
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
