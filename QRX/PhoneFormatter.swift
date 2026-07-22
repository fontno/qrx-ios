import Foundation

/// Lightweight as-you-type phone formatting. NANP numbers (10 digits, or 11
/// with a leading 1) get "(555) 010-0123" styling; other international
/// numbers are left as "+digits" — no guessing at foreign grouping rules.
/// The formatted string is display-only; QRPayload sanitizes before encoding.
enum PhoneFormatter {
    static func format(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let hasPlus = trimmed.hasPrefix("+")
        var digits = trimmed.filter(\.isNumber)

        var countryPrefix = ""
        if digits.count == 11, digits.first == "1" {
            countryPrefix = "+1 "
            digits.removeFirst()
        } else if hasPlus {
            return digits.isEmpty ? "" : "+" + digits
        }

        guard digits.count <= 10 else { return digits }
        let d = Array(digits)
        switch d.count {
        case 0:
            return ""
        case 1...3:
            return countryPrefix + String(d)
        case 4...7:
            return countryPrefix + "\(String(d[0..<3]))-\(String(d[3...]))"
        default:
            return countryPrefix + "(\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6...]))"
        }
    }
}
