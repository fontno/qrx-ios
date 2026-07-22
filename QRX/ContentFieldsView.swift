import QRCore
import SwiftUI

struct ContentFieldsView: View {
    @Bindable var model: BuilderModel

    var body: some View {
        Section {
            Picker("Type", selection: $model.contentType) {
                ForEach(ContentType.allCases) { type in
                    Label(type.rawValue, systemImage: type.icon).tag(type)
                }
            }

            switch model.contentType {
            case .url:
                TextField("example.com", text: $model.urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .text:
                TextField("Your text", text: $model.text, axis: .vertical)
                    .lineLimit(1...4)
            case .wifi:
                TextField("Network name (SSID)", text: $model.wifiSSID)
                    .autocorrectionDisabled()
                Picker("Security", selection: $model.wifiSecurity) {
                    ForEach(WifiSecurity.allCases) { sec in
                        Text(sec.displayName).tag(sec)
                    }
                }
                if model.wifiSecurity != .none {
                    TextField("Password", text: $model.wifiPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Toggle("Hidden network", isOn: $model.wifiHidden)
            case .contact:
                TextField("Name", text: $model.contactName)
                TextField("Company (optional)", text: $model.contactOrg)
                TextField("Phone (optional)", text: $model.contactPhone)
                    .keyboardType(.phonePad)
                    .onChange(of: model.contactPhone) { _, newValue in
                        let formatted = PhoneFormatter.format(newValue)
                        if formatted != newValue {
                            model.contactPhone = formatted
                        }
                    }
                TextField("Email (optional)", text: $model.contactEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Website (optional)", text: $model.contactWebsite)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            case .email:
                TextField("Email address", text: $model.emailTo)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Subject (optional)", text: $model.emailSubject)
            case .phone:
                TextField("Phone number", text: $model.phoneNumber)
                    .keyboardType(.phonePad)
                    .onChange(of: model.phoneNumber) { _, newValue in
                        let formatted = PhoneFormatter.format(newValue)
                        if formatted != newValue {
                            model.phoneNumber = formatted
                        }
                    }
            }
        }
    }
}
