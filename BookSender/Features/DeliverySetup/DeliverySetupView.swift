import SwiftUI

enum DeliverySetupPresentation {
    case onboarding
    case settings
}

struct DeliverySetupView: View {
    @Bindable var model: AppModel
    let presentation: DeliverySetupPresentation

    var body: some View {
        Form {
            if presentation == .onboarding {
                Section {
                    setupFields
                } header: {
                    Text("Delivery Setup")
                        .font(.largeTitle.weight(.bold))
                }
            } else {
                Section {
                    setupFields
                }
            }

            if let setupMessage = model.setupMessage {
                Section {
                    Label(setupMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("deliverySetup.error")
                }
            }

            Section {
                Button {
                    model.saveSetup()
                } label: {
                    Group {
                        if model.isSavingSetup {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Saving setup")
                        } else {
                            Text("Save Setup")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isSavingSetup)
                .accessibilityIdentifier("deliverySetup.save")

                if presentation == .onboarding, model.setup == nil {
                    HStack {
                        Spacer()
                        Button("Preview Send Book", action: model.previewSendBook)
                            .accessibilityIdentifier("deliverySetup.previewSendBook")
                        Spacer()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 560)
        .padding(presentation == .onboarding ? 32 : 20)
    }

    @ViewBuilder
    private var setupFields: some View {
        field("Sender Address", text: $model.setupDraft.senderAddress, field: .senderAddress)
        field("SMTP Host", text: $model.setupDraft.smtpHost, field: .smtpHost)
        field("SMTP Port", text: $model.setupDraft.smtpPort, field: .smtpPort)

        Picker("Security Mode", selection: $model.setupDraft.securityMode) {
            ForEach(SecurityMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .accessibilityIdentifier("deliverySetup.securityMode")

        field("Username", text: $model.setupDraft.username, field: .username)

        LabeledContent("App Password") {
            VStack(alignment: .leading, spacing: 4) {
                SecureField(
                    model.setup == nil ? "" : "Enter a new password to update setup",
                    text: $model.setupDraft.appPassword
                )
                .accessibilityIdentifier("deliverySetup.appPassword")
                fieldError(.appPassword)
            }
            .frame(maxWidth: .infinity)
        }

        field("Kindle Address", text: $model.setupDraft.kindleAddress, field: .kindleAddress)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: DeliveryField
    ) -> some View {
        LabeledContent(title) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("", text: text)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("deliverySetup.\(field.rawValue)")
                fieldError(field)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func fieldError(_ field: DeliveryField) -> some View {
        if let error = model.setupErrors[field] {
            Text(message(for: error))
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func message(for error: DeliveryValidationError) -> String {
        switch error {
        case .required: "This field is required."
        case .invalidEmail: "Enter a valid email address."
        case .invalidHost: "Enter a valid SMTP hostname."
        case .invalidPort: "Enter a port from 1 through 65535."
        case .invalidUsername: "Enter a valid username."
        case .kindleDomainRequired: "Enter an address ending in @kindle.com."
        }
    }
}
