import Testing
@testable import QRCore

@Suite("URL safety heuristics")
struct URLSafetyTests {
    typealias Flag = URLSafety.Report.Flag

    @Test(arguments: [
        "https://example.com",
        "https://www.apple.com/store?item=1",
        "https://sub.domain.example.co.uk/path#frag",
    ])
    func cleanURLsAreClear(_ url: String) {
        let report = URLSafety.analyze(url)
        #expect(report.flags.isEmpty)
        #expect(report.verdict == .clear)
    }

    @Test func embeddedCredentialsAreSuspicious() {
        let report = URLSafety.analyze("https://apple.com@evil.example/login")
        #expect(report.flags.contains(.embeddedCredentials))
        #expect(report.verdict == .suspicious)
    }

    @Test func punycodeHostIsSuspicious() {
        let report = URLSafety.analyze("https://xn--pple-43d.com")
        #expect(report.flags.contains(.punycodeHost))
        #expect(report.verdict == .suspicious)
    }

    @Test(arguments: ["http://192.168.4.20/admin", "https://93.184.216.34/pay"])
    func ipHostsAreSuspicious(_ url: String) {
        let report = URLSafety.analyze(url)
        #expect(report.flags.contains(.ipAddressHost))
        #expect(report.verdict == .suspicious)
    }

    @Test(arguments: ["javascript:alert(1)", "data:text/html;base64,PHNjcmlwdD4="])
    func scriptSchemesAreSuspicious(_ url: String) {
        let report = URLSafety.analyze(url)
        #expect(report.flags == [.scriptScheme])
        #expect(report.verdict == .suspicious)
    }

    @Test func plainHTTPIsCaution() {
        let report = URLSafety.analyze("http://example.com")
        #expect(report.flags == [.insecureScheme])
        #expect(report.verdict == .caution)
    }

    @Test(arguments: ["https://bit.ly/3xYzAbC", "https://t.co/abcdef", "https://tinyurl.com/foo"])
    func shortenersAreCaution(_ url: String) {
        let report = URLSafety.analyze(url)
        #expect(report.flags.contains(.urlShortener))
        #expect(report.verdict == .caution)
    }

    @Test func unusualPortIsCaution() {
        let report = URLSafety.analyze("https://example.com:8443/login")
        #expect(report.flags.contains(.nonStandardPort))
        #expect(report.verdict == .caution)
    }

    @Test func standardPortsAreNotFlagged() {
        #expect(URLSafety.analyze("https://example.com:443/x").flags.isEmpty)
        let httpDefault = URLSafety.analyze("http://example.com:80/x")
        #expect(!httpDefault.flags.contains(.nonStandardPort))
    }

    @Test func combinedTricksAccumulateFlags() {
        let report = URLSafety.analyze("http://login@203.0.113.9:8080/verify")
        #expect(report.flags.contains(.insecureScheme))
        #expect(report.flags.contains(.embeddedCredentials))
        #expect(report.flags.contains(.ipAddressHost))
        #expect(report.flags.contains(.nonStandardPort))
        #expect(report.verdict == .suspicious)
    }

    @Test func hostCasingDoesNotDodgeChecks() {
        #expect(URLSafety.analyze("https://BIT.LY/abc").flags.contains(.urlShortener))
        #expect(URLSafety.analyze("https://XN--PPLE-43D.com").flags.contains(.punycodeHost))
    }

    @Test func everyFlagHasAnExplanation() {
        for flag in Flag.allCases {
            #expect(!flag.explanation.isEmpty)
        }
    }
}
