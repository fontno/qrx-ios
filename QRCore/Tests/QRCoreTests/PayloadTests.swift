import Testing
@testable import QRCore

@Suite("Payload encoding")
struct PayloadTests {
    // MARK: URL

    @Test func urlPrependsSchemeWhenMissing() {
        #expect(QRPayload.url("example.com") == "https://example.com")
    }

    @Test(arguments: ["https://example.com", "http://x.dev", "ftp://files.example.com"])
    func urlKeepsExistingScheme(_ input: String) {
        #expect(QRPayload.url(input) == input)
    }

    @Test func urlTrimsWhitespace() {
        #expect(QRPayload.url("  example.com \n") == "https://example.com")
    }

    @Test func emptyURLProducesEmptyPayload() {
        #expect(QRPayload.url("   ") == "")
    }

    // MARK: Wi-Fi

    @Test func wifiBasic() {
        let p = QRPayload.wifi(ssid: "HomeNet", password: "hunter2", security: .wpa, hidden: false)
        #expect(p == "WIFI:T:WPA;S:HomeNet;P:hunter2;;")
    }

    @Test func wifiEscapesSpecialCharacters() {
        let p = QRPayload.wifi(ssid: #"my;net,work:"a"\z"#, password: "p;w", security: .wpa, hidden: false)
        #expect(p == #"WIFI:T:WPA;S:my\;net\,work\:\"a\"\\z;P:p\;w;;"#)
    }

    @Test func wifiOpenNetworkOmitsPassword() {
        let p = QRPayload.wifi(ssid: "Cafe", password: "ignored", security: .none, hidden: false)
        #expect(p == "WIFI:T:nopass;S:Cafe;;")
    }

    @Test func wifiHiddenFlag() {
        let p = QRPayload.wifi(ssid: "Secret", password: "x", security: .wep, hidden: true)
        #expect(p == "WIFI:T:WEP;S:Secret;P:x;H:true;;")
    }

    @Test func wifiEmptySSIDProducesEmptyPayload() {
        #expect(QRPayload.wifi(ssid: "", password: "x", security: .wpa, hidden: false) == "")
    }

    // MARK: Email / phone

    @Test func emailWithSubjectPercentEncodes() {
        let p = QRPayload.email(to: "hi@example.com", subject: "Hello there & more")
        #expect(p.hasPrefix("mailto:hi@example.com?subject="))
        #expect(!p.contains(" "))
    }

    @Test func emailWithoutSubject() {
        #expect(QRPayload.email(to: "hi@example.com", subject: "") == "mailto:hi@example.com")
    }

    @Test func phoneSanitizesFormatting() {
        #expect(QRPayload.phone(" +1 555 0100 ") == "tel:+15550100")
        #expect(QRPayload.phone("(555) 010-0123") == "tel:5550100123")
        #expect(QRPayload.phone("+1 (555) 010-0123") == "tel:+15550100123")
        #expect(QRPayload.phone("no digits") == "")
        #expect(QRPayload.phone("") == "")
    }

    @Test func vCardPhoneIsSanitized() {
        let p = QRPayload.contact(name: "Ada", org: "", phone: "(555) 010-0123", email: "", website: "")
        #expect(p.contains("TEL:5550100123"))
    }

    // MARK: vCard

    @Test func vCardFullContact() {
        let p = QRPayload.contact(name: "Ada Lovelace", org: "Analytical", phone: "+1555", email: "ada@example.com", website: "example.com")
        let lines = p.components(separatedBy: "\r\n")
        #expect(lines.first == "BEGIN:VCARD")
        #expect(lines.last == "END:VCARD")
        #expect(lines.contains("VERSION:3.0"))
        #expect(lines.contains("FN:Ada Lovelace"))
        #expect(lines.contains("ORG:Analytical"))
        #expect(lines.contains("TEL:+1555"))
        #expect(lines.contains("EMAIL:ada@example.com"))
        #expect(lines.contains("URL:example.com"))
    }

    @Test func vCardOmitsEmptyFields() {
        let p = QRPayload.contact(name: "Solo", org: "", phone: "", email: "", website: "")
        #expect(!p.contains("ORG:"))
        #expect(!p.contains("TEL:"))
        #expect(!p.contains("EMAIL:"))
        #expect(!p.contains("URL:"))
    }

    @Test func vCardEscapesReservedCharacters() {
        let p = QRPayload.contact(name: "Smith; Jones, Inc", org: "", phone: "", email: "", website: "")
        #expect(p.contains(#"FN:Smith\; Jones\, Inc"#))
    }

    @Test func vCardRequiresName() {
        #expect(QRPayload.contact(name: "  ", org: "X", phone: "1", email: "e", website: "w") == "")
    }
}
