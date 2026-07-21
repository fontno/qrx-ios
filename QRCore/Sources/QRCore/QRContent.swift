import Foundation

public enum WifiSecurity: String, Codable, CaseIterable, Sendable, Identifiable {
    case wpa = "WPA"
    case wep = "WEP"
    case none = "nopass"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wpa: "WPA/WPA2"
        case .wep: "WEP"
        case .none: "None"
        }
    }
}

/// Builds the raw string payload each QR content type encodes.
public enum QRPayload {
    public static func url(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.contains("://") ? trimmed : "https://" + trimmed
    }

    public static func wifi(ssid: String, password: String, security: WifiSecurity, hidden: Bool) -> String {
        guard !ssid.isEmpty else { return "" }
        var s = "WIFI:T:\(security.rawValue);S:\(escapeWifi(ssid));"
        if security != .none, !password.isEmpty {
            s += "P:\(escapeWifi(password));"
        }
        if hidden { s += "H:true;" }
        return s + ";"
    }

    public static func email(to: String, subject: String) -> String {
        let to = to.trimmingCharacters(in: .whitespaces)
        guard !to.isEmpty else { return "" }
        var s = "mailto:\(to)"
        if !subject.isEmpty {
            let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
            s += "?subject=\(encoded)"
        }
        return s
    }

    public static func phone(_ number: String) -> String {
        let number = number.trimmingCharacters(in: .whitespaces)
        return number.isEmpty ? "" : "tel:\(number)"
    }

    public static func contact(name: String, org: String, phone: String, email: String, website: String) -> String {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "" }
        var lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:\(escapeVCard(name))"]
        if !org.isEmpty { lines.append("ORG:\(escapeVCard(org))") }
        if !phone.isEmpty { lines.append("TEL:\(phone)") }
        if !email.isEmpty { lines.append("EMAIL:\(email)") }
        if !website.isEmpty { lines.append("URL:\(escapeVCard(website))") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    /// WIFI: format requires escaping of backslash, then ; , : "
    private static func escapeWifi(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "\\", with: "\\\\")
        for ch in [";", ",", ":", "\""] {
            out = out.replacingOccurrences(of: ch, with: "\\" + ch)
        }
        return out
    }

    private static func escapeVCard(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
