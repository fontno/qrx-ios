import QRCore
import Testing
@testable import QRX

@Suite("BuilderModel payload computation")
struct BuilderPayloadTests {
    @Test func urlContent() {
        let model = BuilderModel()
        model.contentType = .url
        model.urlString = "example.com"
        #expect(model.payload == "https://example.com")
    }

    @Test func wifiContent() {
        let model = BuilderModel()
        model.contentType = .wifi
        model.wifiSSID = "HomeNet"
        model.wifiPassword = "secret"
        model.wifiSecurity = .wpa
        #expect(model.payload == "WIFI:T:WPA;S:HomeNet;P:secret;;")
    }

    @Test func emptyRequiredFieldMeansEmptyPayload() {
        let model = BuilderModel()
        model.contentType = .wifi
        model.wifiSSID = ""
        #expect(model.payload.isEmpty)
    }

    @Test func suggestedNamePerContentType() {
        let model = BuilderModel()
        model.contentType = .url
        model.urlString = "https://mybrand.dev/path"
        #expect(model.suggestedName == "mybrand.dev")

        model.contentType = .wifi
        model.wifiSSID = "CafeGuest"
        #expect(model.suggestedName == "CafeGuest")

        model.contentType = .contact
        model.contactName = "Ada Lovelace"
        #expect(model.suggestedName == "Ada Lovelace")

        model.contentType = .text
        model.text = ""
        #expect(model.suggestedName == "QR Code")
    }
}

@Suite("BuilderModel design bridging")
struct BuilderDesignBridgingTests {
    @Test func gradientToggleKeepsPrimaryColor() {
        let model = BuilderModel()
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        model.foregroundColor = red

        model.isGradient = true
        guard case .linearGradient(let c1, _, _) = model.design.foreground else {
            Issue.record("expected gradient")
            return
        }
        #expect(c1 == red)

        model.isGradient = false
        #expect(model.design.foreground == .solid(red))
    }

    @Test func eyeColorToggle() {
        let model = BuilderModel()
        #expect(model.design.eyeColor == nil)

        model.hasCustomEyeColors = true
        #expect(model.design.eyeColor == model.foregroundColor)
        #expect(model.design.pupilColor == model.foregroundColor)

        model.hasCustomEyeColors = false
        #expect(model.design.eyeColor == nil)
        #expect(model.design.pupilColor == nil)
    }

    @Test func frameBridging() {
        let model = BuilderModel()
        #expect(model.design.frame == nil)

        model.hasFrame = true
        #expect(model.design.frame?.text == "SCAN ME")

        model.frameText = "VISIT US"
        #expect(model.design.frame?.text == "VISIT US")

        model.hasFrame = false
        #expect(model.design.frame == nil)

        // Re-enabling remembers the custom text.
        model.hasFrame = true
        #expect(model.design.frame?.text == "VISIT US")
    }

    @Test func monogramLogoSync() {
        let model = BuilderModel()
        model.logoSource = .monogram
        model.monogramText = "BX"
        model.syncLogo()
        #expect(model.design.logo != nil)

        model.logoSource = .none
        model.syncLogo()
        #expect(model.design.logo == nil)
    }

    @Test func emptyMonogramProducesNoLogo() {
        let model = BuilderModel()
        model.logoSource = .monogram
        model.monogramText = ""
        model.syncLogo()
        #expect(model.design.logo == nil)
    }
}

@Suite("Builder snapshot round-trip")
struct BuilderSnapshotTests {
    @Test func allFieldsSurviveRoundTrip() {
        let original = BuilderModel()
        original.contentType = .wifi
        original.wifiSSID = "Round;Trip"
        original.wifiPassword = "p@ss"
        original.wifiSecurity = .wep
        original.wifiHidden = true
        original.logoSource = .monogram
        original.monogramText = "RT"
        original.logoSizeFraction = 0.27
        original.logoBacking = .circle
        original.logoKnockout = false
        original.syncLogo()

        let restored = BuilderModel()
        restored.apply(original.snapshot())

        #expect(restored.payload == original.payload)
        #expect(restored.wifiSSID == original.wifiSSID)
        #expect(restored.wifiSecurity == original.wifiSecurity)
        #expect(restored.wifiHidden == original.wifiHidden)
        #expect(restored.logoSource == original.logoSource)
        #expect(restored.monogramText == original.monogramText)
        #expect(restored.logoSizeFraction == original.logoSizeFraction)
        #expect(restored.logoBacking == original.logoBacking)
        #expect(restored.logoKnockout == original.logoKnockout)
    }
}
