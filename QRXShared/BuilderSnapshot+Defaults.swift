import QRCore

/// Factory used by the Share Extension, which builds SavedCode records
/// without a BuilderModel. Raw values must match the app's ContentType /
/// LogoSource / LogoBacking enums so the record opens cleanly in the builder.
nonisolated extension BuilderSnapshot {
    static func url(_ urlString: String) -> BuilderSnapshot {
        base(contentType: "URL", urlString: urlString)
    }

    static func text(_ text: String) -> BuilderSnapshot {
        base(contentType: "Text", text: text)
    }

    private static func base(contentType: String, urlString: String = "", text: String = "") -> BuilderSnapshot {
        BuilderSnapshot(
            contentType: contentType,
            urlString: urlString,
            text: text,
            wifiSSID: "",
            wifiPassword: "",
            wifiSecurity: "WPA",
            wifiHidden: false,
            emailTo: "",
            emailSubject: "",
            phoneNumber: "",
            contactName: "",
            contactOrg: "",
            contactPhone: "",
            contactEmail: "",
            contactWebsite: "",
            logoSource: "None",
            photoLogoData: nil,
            monogramText: "",
            monogramColor: .white,
            monogramBackground: RGBAColor(red: 0.1, green: 0.45, blue: 0.95),
            logoSizeFraction: 0.22,
            logoBacking: "roundedRect",
            logoKnockout: true
        )
    }
}
