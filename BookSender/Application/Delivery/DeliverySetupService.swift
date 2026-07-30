import Foundation

actor DeliverySetupService {
    private let validator: DeliverySetupValidator
    private let credentials: any CredentialStoring
    private let preferences: any DeliveryPreferencesStoring
    private let serviceName: String

    init(
        validator: DeliverySetupValidator = DeliverySetupValidator(),
        credentials: any CredentialStoring,
        preferences: any DeliveryPreferencesStoring,
        serviceName: String = "com.rckbrcls.BookSender.smtp"
    ) {
        self.validator = validator
        self.credentials = credentials
        self.preferences = preferences
        self.serviceName = serviceName
    }

    func load() async -> SetupLoadResult {
        switch await preferences.load() {
        case .absent:
            return .incomplete(prefilledDraft: DeliverySetupDraft(), failure: nil)
        case .invalid:
            return .incomplete(
                prefilledDraft: DeliverySetupDraft(),
                failure: failure(
                    .preferencesInvalid,
                    message: "Saved delivery settings need to be entered again."
                )
            )
        case .value(let setup):
            guard await credentials.exists(setup.credentialReference) else {
                return .incomplete(
                    prefilledDraft: DeliverySetupDraft(setup: setup),
                    failure: failure(
                        .credentialMissing,
                        message: "Enter the app password again to complete delivery setup."
                    )
                )
            }
            return .complete(setup)
        }
    }

    func save(
        _ draft: DeliverySetupDraft,
        replacing current: DeliverySetup?
    ) async throws -> DeliverySetup {
        let keepsExistingCredential = draft.appPassword.isEmpty && current != nil
        let validation = validator.validate(
            draft,
            requiresPassword: !keepsExistingCredential
        )
        guard validation.isValid else {
            throw validation.fieldErrors.values.first
                ?? DeliveryValidationError.invalidPort
        }

        if let current, keepsExistingCredential,
           await credentials.exists(current.credentialReference) == false {
            throw failure(
                .credentialMissing,
                message: "Enter the app password again to save these settings."
            )
        }

        let revision = (current?.revision ?? 0) + 1
        let reference: CredentialReference
        let createdCredential: Bool

        if keepsExistingCredential, let current {
            reference = CredentialReference(
                service: current.credentialReference.service,
                account: current.credentialReference.account,
                revision: revision
            )
            createdCredential = false
        } else {
            reference = try await credentials.save(
                secret: draft.appPassword,
                service: serviceName,
                account: "revision-\(revision)-\(UUID().uuidString)",
                revision: revision
            )
            createdCredential = true
        }

        do {
            let setup = try validator.makeSetup(
                from: validation.normalizedDraft,
                credentialReference: reference,
                revision: revision,
                requiresPassword: !keepsExistingCredential
            )
            try await preferences.save(setup)
            if createdCredential,
               let old = current?.credentialReference,
               old != reference {
                try? await credentials.delete(old)
            }
            return setup
        } catch {
            if createdCredential {
                try? await credentials.delete(reference)
            }
            throw error
        }
    }

    func clear(_ setup: DeliverySetup?) async -> SanitizedFailure? {
        await preferences.clear()
        guard let setup else { return nil }
        do {
            try await credentials.delete(setup.credentialReference)
            return nil
        } catch let failure as SanitizedFailure {
            return failure
        } catch {
            return failure(
                .credentialDelete,
                message: "The stored app password could not be removed."
            )
        }
    }

    private func failure(
        _ code: DiagnosticCode,
        message: String
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: .credential,
            code: code,
            message: message,
            recoveryAction: .editSetup
        )
    }
}
