import SwiftUI

enum DeliverySetupPresentation {
    case onboarding
    case settings
}

struct DeliverySetupView: View {
    @Bindable var model: AppModel
    let presentation: DeliverySetupPresentation
    @FocusState private var focusedField: DeliveryField?

    var body: some View {
        Group {
            if presentation == .settings {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        setupFields
                        feedbackContent
                        actionButtons
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
                .scrollIndicators(.visible)
                .accessibilityIdentifier("settings.delivery.scroll")
            } else {
                Form {
                    Section {
                        setupFields
                    } header: {
                        Text("Delivery Setup")
                            .font(.largeTitle.weight(.bold))
                    }

                    if deliveryFeedback?.failure != nil
                        || model.setupMessage != nil {
                        Section {
                            feedbackContent
                        }
                    }

                    Section {
                        actionButtons
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(maxWidth: 560)
                .padding(32)
            }
        }
        .onAppear {
            consumeFocusRequestIfNeeded(
                model.notificationCenter.focusRequest
            )
        }
        .onChange(of: model.notificationCenter.focusRequest) { _, request in
            consumeFocusRequestIfNeeded(request)
        }
    }

    @ViewBuilder
    private var feedbackContent: some View {
        if let failure = deliveryFeedback?.failure {
            FailureDetailView(
                presentation: failure,
                diagnosticEvent: model.currentDiagnosticEvent,
                copyErrorDetails: {
                    model.copyCurrentErrorDetails(
                        destination: notificationDestination
                    )
                },
                performRecovery: handleRecovery
            )
        } else if let setupMessage = model.setupMessage {
            Label(setupMessage, systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
                .accessibilityIdentifier("deliverySetup.error")
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            model.saveSetup(destination: notificationDestination)
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
        .padding(.top, 20)
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canSaveSetup)
        .accessibilityIdentifier("deliverySetup.save")

        if presentation == .settings, model.setup != nil {
            Button("Delete Delivery Setup", role: .destructive) {
                model.deleteSetup(destination: .settings)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(.red)
            .disabled(!model.canSaveSetup)
            .accessibilityHint(
                model.canSaveSetup
                    ? "Deletes saved delivery settings and the stored app password."
                    : "Wait for the current operation to finish."
            )
            .accessibilityIdentifier("deliverySetup.delete")
        }
    }

    @ViewBuilder
    private var setupFields: some View {
        field("Sender Address", text: $model.setupDraft.senderAddress, field: .senderAddress)
        field("SMTP Host", text: $model.setupDraft.smtpHost, field: .smtpHost)
        field("SMTP Port", text: $model.setupDraft.smtpPort, field: .smtpPort)

        VStack(alignment: .leading, spacing: 6) {
            settingsFieldLabel("Security Mode")

            Picker("Security Mode", selection: $model.setupDraft.securityMode) {
                ForEach(SecurityMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .accessibilityLabel("Security Mode")
            .accessibilityIdentifier("deliverySetup.securityMode")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)

        field("Username", text: $model.setupDraft.username, field: .username)

        VStack(alignment: .leading, spacing: 6) {
            settingsFieldLabel("App Password")

            SecureField(
                "",
                text: $model.setupDraft.appPassword,
                prompt: Text(
                    model.setup == nil ? "App Password" : "New App Password (optional)"
                )
            )
            .labelsHidden()
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .appPassword)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                inputBorder(for: .appPassword)
            }
            .accessibilityLabel("App Password")
            .accessibilityIdentifier("deliverySetup.appPassword")
            fieldError(.appPassword)
        }
        .frame(maxWidth: .infinity)

        field("Kindle Address", text: $model.setupDraft.kindleAddress, field: .kindleAddress)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: DeliveryField
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            settingsFieldLabel(title)

            TextField("", text: text, prompt: Text(title))
                .labelsHidden()
                .textFieldStyle(.plain)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Color(nsColor: .textBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    inputBorder(for: field)
                }
                .accessibilityLabel(title)
                .accessibilityIdentifier("deliverySetup.\(field.rawValue)")
            fieldError(field)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func settingsFieldLabel(_ title: String) -> some View {
        if presentation == .settings {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func fieldError(_ field: DeliveryField) -> some View {
        if let error = model.setupErrors[field] {
            Text(message(for: error))
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityLabel("Error: \(message(for: error))")
        }
    }

    private func inputBorder(for field: DeliveryField) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                focusedField == field
                    ? Color.accentColor
                    : Color(nsColor: .separatorColor),
                lineWidth: focusedField == field ? 3 : 1
            )
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

    private func handleRecovery(_ action: RecoveryAction) {
        if action == .editSetup {
            focusedField = .appPassword
        }
    }

    private func consumeFocusRequestIfNeeded(
        _ request: NotificationFocusRequest?
    ) {
        guard let request,
              request.destination == notificationDestination,
              request.action == .editSetup
        else { return }
        focusedField = .appPassword
        model.notificationCenter.consumeFocusRequest(id: request.id)
    }

    private var notificationDestination: NotificationDestination {
        presentation == .settings ? .settings : .main
    }

    private var deliveryFeedback: ActionFeedback? {
        model.feedback(for: .deliverySetup)
    }
}
