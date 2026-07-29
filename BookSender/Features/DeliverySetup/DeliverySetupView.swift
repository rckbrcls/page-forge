import SwiftUI

struct DeliverySetupView: View {
    @Bindable var model: AppModel
    let shortcutService: ShortcutService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Delivery Setup")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Connect the email account approved to send books to your Kindle.")
                        .foregroundStyle(.secondary)
                }

                form

                Divider()
                ShortcutPreferenceSection(disable: shortcutService.disable)

                if let setupMessage = model.setupMessage {
                    Label(setupMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("deliverySetup.error")
                }

                HStack {
                    if model.setup != nil {
                        Button("Cancel", action: model.cancelSetupEditing)
                            .keyboardShortcut(.cancelAction)
                    }
                    Spacer()
                    Button {
                        model.saveSetup()
                    } label: {
                        if model.isSavingSetup {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save Setup")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isSavingSetup)
                    .accessibilityIdentifier("deliverySetup.save")
                }
            }
            .frame(maxWidth: 560)
            .padding(40)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
            field("Sender Address", text: $model.setupDraft.senderAddress, field: .senderAddress)
            field("SMTP Host", text: $model.setupDraft.smtpHost, field: .smtpHost)
            field("SMTP Port", text: $model.setupDraft.smtpPort, field: .smtpPort)
            GridRow {
                Text("Security Mode")
                    .fontWeight(.medium)
                Picker("", selection: $model.setupDraft.securityMode) {
                    ForEach(SecurityMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Security Mode")
                .accessibilityIdentifier("deliverySetup.securityMode")
            }
            field("Username", text: $model.setupDraft.username, field: .username)
            GridRow(alignment: .top) {
                Text("App Password")
                    .fontWeight(.medium)
                VStack(alignment: .leading, spacing: 4) {
                    SecureField(
                        model.setup == nil ? "" : "Enter a new password to update setup",
                        text: $model.setupDraft.appPassword
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("deliverySetup.appPassword")
                    fieldError(.appPassword)
                }
            }
            field("Kindle Address", text: $model.setupDraft.kindleAddress, field: .kindleAddress)
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: DeliveryField
    ) -> some View {
        GridRow(alignment: .top) {
            Text(title)
                .fontWeight(.medium)
            VStack(alignment: .leading, spacing: 4) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("deliverySetup.\(field.rawValue)")
                fieldError(field)
            }
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
