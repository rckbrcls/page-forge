import Foundation

struct DeliverySetupValidator: Sendable {
    func validate(
        _ draft: DeliverySetupDraft,
        requiresPassword: Bool = true
    ) -> DeliveryValidationResult {
        var normalized = draft
        normalized.senderAddress = draft.senderAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.smtpHost = draft.smtpHost.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.smtpPort = draft.smtpPort.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.kindleAddress = draft.kindleAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        var errors: [DeliveryField: DeliveryValidationError] = [:]
        validateRequired(normalized.senderAddress, field: .senderAddress, errors: &errors)
        validateRequired(normalized.smtpHost, field: .smtpHost, errors: &errors)
        validateRequired(normalized.smtpPort, field: .smtpPort, errors: &errors)
        validateRequired(normalized.username, field: .username, errors: &errors)
        if requiresPassword {
            validateRequired(normalized.appPassword, field: .appPassword, errors: &errors)
        }
        validateRequired(normalized.kindleAddress, field: .kindleAddress, errors: &errors)

        if errors[.senderAddress] == nil, (try? EmailAddress(normalized.senderAddress)) == nil {
            errors[.senderAddress] = .invalidEmail
        }
        if errors[.smtpHost] == nil, (try? SMTPHost(normalized.smtpHost)) == nil {
            errors[.smtpHost] = .invalidHost
        }
        if errors[.smtpPort] == nil,
           (UInt16(normalized.smtpPort).map { $0 > 0 } != true) {
            errors[.smtpPort] = .invalidPort
        }
        if errors[.username] == nil,
           normalized.username.contains(where: { $0.isNewline || $0.isControl }) {
            errors[.username] = .invalidUsername
        }
        if errors[.kindleAddress] == nil {
            if let address = try? EmailAddress(normalized.kindleAddress) {
                if !address.value.hasSuffix("@kindle.com") {
                    errors[.kindleAddress] = .kindleDomainRequired
                }
            } else {
                errors[.kindleAddress] = .invalidEmail
            }
        }
        return DeliveryValidationResult(normalizedDraft: normalized, fieldErrors: errors)
    }

    func makeSetup(
        from draft: DeliverySetupDraft,
        credentialReference: CredentialReference,
        revision: Int,
        requiresPassword: Bool = true
    ) throws -> DeliverySetup {
        let validation = validate(draft, requiresPassword: requiresPassword)
        guard validation.isValid,
              let port = UInt16(validation.normalizedDraft.smtpPort)
        else {
            throw validation.fieldErrors.values.first ?? .invalidPort
        }
        return DeliverySetup(
            senderAddress: try EmailAddress(validation.normalizedDraft.senderAddress),
            smtpHost: try SMTPHost(validation.normalizedDraft.smtpHost),
            smtpPort: port,
            securityMode: validation.normalizedDraft.securityMode,
            username: validation.normalizedDraft.username,
            credentialReference: credentialReference,
            kindleAddress: try EmailAddress(validation.normalizedDraft.kindleAddress),
            revision: revision
        )
    }

    private func validateRequired(
        _ value: String,
        field: DeliveryField,
        errors: inout [DeliveryField: DeliveryValidationError]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors[field] = .required(field)
        }
    }
}
