import Foundation

/// Offline, heuristic red-flag analysis for scanned URLs. Deliberately not a
/// cloud reputation lookup — QRX never phones home with what you scan. These
/// heuristics target the structural tricks QR phishing actually uses.
public enum URLSafety {
    public struct Report: Equatable, Sendable {
        public enum Flag: String, CaseIterable, Equatable, Sendable {
            /// javascript: or data: — executable payloads dressed as links.
            case scriptScheme
            /// https://apple.com@evil.com — everything before @ is a decoy.
            case embeddedCredentials
            /// Raw IP instead of a domain — no identity to verify.
            case ipAddressHost
            /// xn-- punycode — can imitate familiar domains with lookalike glyphs.
            case punycodeHost
            /// Plain http: — traffic and destination are unprotected.
            case insecureScheme
            /// Link shortener — the real destination is hidden.
            case urlShortener
            /// Unusual port for web traffic.
            case nonStandardPort

            public var explanation: String {
                switch self {
                case .scriptScheme: "This isn't a normal link — it tries to run code directly."
                case .embeddedCredentials: "The address hides its real destination behind an \u{201C}@\u{201D} — a common phishing trick."
                case .ipAddressHost: "Points at a raw IP address instead of a named website."
                case .punycodeHost: "The domain uses lookalike characters that can imitate a familiar site."
                case .insecureScheme: "Uses insecure http — the connection isn't encrypted."
                case .urlShortener: "A link shortener hides where this actually goes."
                case .nonStandardPort: "Uses an unusual network port for a website."
                }
            }
        }

        public enum Verdict: Equatable, Sendable {
            case clear
            case caution
            case suspicious
        }

        public let flags: [Flag]

        public var verdict: Verdict {
            if flags.contains(where: { [.scriptScheme, .embeddedCredentials, .punycodeHost, .ipAddressHost].contains($0) }) {
                return .suspicious
            }
            return flags.isEmpty ? .clear : .caution
        }
    }

    /// Hosts that exist to hide destinations. Not exhaustive — a heuristic.
    static let shortenerHosts: Set<String> = [
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "is.gd", "ow.ly", "buff.ly",
        "cutt.ly", "rebrand.ly", "shorturl.at", "rb.gy", "tiny.cc", "lnkd.in",
        "s.id", "t.ly", "shorte.st",
    ]

    public static func analyze(_ raw: String) -> Report {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var flags: [Report.Flag] = []

        guard let components = URLComponents(string: trimmed) else {
            return Report(flags: [])
        }
        let scheme = components.scheme?.lowercased()

        if scheme == "javascript" || scheme == "data" {
            flags.append(.scriptScheme)
            return Report(flags: flags)
        }
        if scheme == "http" {
            flags.append(.insecureScheme)
        }
        if let user = components.user, !user.isEmpty {
            flags.append(.embeddedCredentials)
        }

        // components.host decodes punycode to Unicode; use the encoded form
        // so xn-- prefixes stay visible.
        let host = (components.encodedHost ?? components.host ?? "").lowercased()
        if !host.isEmpty {
            if isIPAddress(host) {
                flags.append(.ipAddressHost)
            }
            let hasPunycodeLabel = host.split(separator: ".").contains { $0.hasPrefix("xn--") }
            let hasNonASCII = host.contains { !$0.isASCII }
            if hasPunycodeLabel || hasNonASCII {
                flags.append(.punycodeHost)
            }
            if shortenerHosts.contains(host) || shortenerHosts.contains(host.replacingOccurrences(of: "www.", with: "")) {
                flags.append(.urlShortener)
            }
        }

        if let port = components.port, scheme == "http" || scheme == "https", ![80, 443].contains(port) {
            flags.append(.nonStandardPort)
        }

        return Report(flags: flags)
    }

    private static func isIPAddress(_ host: String) -> Bool {
        // IPv6 hosts parse with colons; IPv4 is four numeric octets.
        if host.contains(":") { return true }
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
    }
}
