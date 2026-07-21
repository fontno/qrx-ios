import Observation
import QRCore
import SwiftUI
import UIKit

enum ContentType: String, CaseIterable, Identifiable {
    case url = "URL"
    case text = "Text"
    case wifi = "Wi-Fi"
    case contact = "Contact"
    case email = "Email"
    case phone = "Phone"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .url: "link"
        case .text: "text.alignleft"
        case .wifi: "wifi"
        case .contact: "person.crop.circle"
        case .email: "envelope"
        case .phone: "phone"
        }
    }
}

enum LogoSource: String, CaseIterable, Identifiable {
    case none = "None"
    case photo = "Photo"
    case monogram = "Monogram"

    var id: String { rawValue }
}

@Observable
final class BuilderModel {
    init() {
        #if DEBUG
        // UI-test hook: PHPicker is out-of-process and can't be automated
        // reliably, so inject a square photo logo directly.
        if CommandLine.arguments.contains("--test-square-logo") {
            photoLogoData = Self.debugSquareImage()
            logoSource = .photo
            syncLogo()
        }
        #endif
    }

    #if DEBUG
    private static func debugSquareImage() -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { ctx in
            UIColor(red: 0.85, green: 0.12, blue: 0.2, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        }.pngData()
    }
    #endif

    var contentType: ContentType = .url

    var urlString = "https://example.com"
    var text = ""
    var wifiSSID = ""
    var wifiPassword = ""
    var wifiSecurity: WifiSecurity = .wpa
    var wifiHidden = false
    var emailTo = ""
    var emailSubject = ""
    var phoneNumber = ""
    var contactName = ""
    var contactOrg = ""
    var contactPhone = ""
    var contactEmail = ""
    var contactWebsite = ""

    var design = QRDesign(quietZone: 2)

    // Logo state. The photo/monogram sources each keep their own inputs so
    // switching back and forth doesn't lose work.
    var logoSource: LogoSource = .none
    var photoLogoData: Data?
    var monogramText = ""
    var monogramColor: RGBAColor = .white
    var monogramBackground = RGBAColor(red: 0.1, green: 0.45, blue: 0.95)
    var logoSizeFraction: Double = 0.22
    var logoBacking: LogoBacking = .roundedRect
    var logoKnockout = true

    var payload: String {
        switch contentType {
        case .url: QRPayload.url(urlString)
        case .text: text
        case .wifi: QRPayload.wifi(ssid: wifiSSID, password: wifiPassword, security: wifiSecurity, hidden: wifiHidden)
        case .contact: QRPayload.contact(name: contactName, org: contactOrg, phone: contactPhone, email: contactEmail, website: contactWebsite)
        case .email: QRPayload.email(to: emailTo, subject: emailSubject)
        case .phone: QRPayload.phone(phoneNumber)
        }
    }

    /// Recomputes design.logo from the current logo inputs.
    func syncLogo() {
        let data: Data? = switch logoSource {
        case .none: nil
        case .photo: photoLogoData
        case .monogram: monogramText.isEmpty ? nil : MonogramFactory.image(
            text: monogramText, textColor: monogramColor, backgroundColor: monogramBackground)
        }
        design.logo = data.map {
            LogoOptions(imageData: $0, sizeFraction: logoSizeFraction, backing: logoBacking, knockout: logoKnockout)
        }
    }

    // MARK: - Foreground fill bridging (solid vs gradient controls)

    var isGradient: Bool {
        get {
            if case .linearGradient = design.foreground { return true }
            return false
        }
        set {
            if newValue {
                let c1 = design.foreground.primaryColor
                design.foreground = .linearGradient(c1, gradientSecondColor, angleDegrees: gradientAngle)
            } else {
                design.foreground = .solid(design.foreground.primaryColor)
            }
        }
    }

    private var gradientSecondColor = RGBAColor(red: 0.35, green: 0.2, blue: 0.85)
    private var gradientAngle: Double = 45

    var foregroundColor: RGBAColor {
        get { design.foreground.primaryColor }
        set {
            switch design.foreground {
            case .solid: design.foreground = .solid(newValue)
            case .linearGradient(_, let c2, let angle):
                design.foreground = .linearGradient(newValue, c2, angleDegrees: angle)
            }
        }
    }

    var secondaryColor: RGBAColor {
        get {
            if case .linearGradient(_, let c2, _) = design.foreground { return c2 }
            return gradientSecondColor
        }
        set {
            gradientSecondColor = newValue
            if case .linearGradient(let c1, _, let angle) = design.foreground {
                design.foreground = .linearGradient(c1, newValue, angleDegrees: angle)
            }
        }
    }

    var angleDegrees: Double {
        get {
            if case .linearGradient(_, _, let angle) = design.foreground { return angle }
            return gradientAngle
        }
        set {
            gradientAngle = newValue
            if case .linearGradient(let c1, let c2, _) = design.foreground {
                design.foreground = .linearGradient(c1, c2, angleDegrees: newValue)
            }
        }
    }

    var hasFrame: Bool {
        get { design.frame != nil }
        set { design.frame = newValue ? QRFrame(text: frameTextStorage, color: frameColorStorage) : nil }
    }

    private var frameTextStorage = "SCAN ME"
    private var frameColorStorage = RGBAColor.black

    var frameText: String {
        get { design.frame?.text ?? frameTextStorage }
        set {
            frameTextStorage = newValue
            design.frame?.text = newValue
        }
    }

    var frameColor: RGBAColor {
        get { design.frame?.color ?? frameColorStorage }
        set {
            frameColorStorage = newValue
            design.frame?.color = newValue
        }
    }

    var hasCustomEyeColors: Bool {
        get { design.eyeColor != nil }
        set {
            if newValue {
                design.eyeColor = design.foreground.primaryColor
                design.pupilColor = design.foreground.primaryColor
            } else {
                design.eyeColor = nil
                design.pupilColor = nil
            }
        }
    }
}

extension Binding where Value == Color {
    /// Bridges an RGBAColor binding to SwiftUI's ColorPicker.
    init(rgba: Binding<RGBAColor>) {
        self.init(
            get: { rgba.wrappedValue.color },
            set: { rgba.wrappedValue = RGBAColor($0) }
        )
    }

    init(rgba: Binding<RGBAColor?>, default defaultColor: RGBAColor) {
        self.init(
            get: { (rgba.wrappedValue ?? defaultColor).color },
            set: { rgba.wrappedValue = RGBAColor($0) }
        )
    }
}
