import Foundation

actor DeliverySetupService {
    private let validator: DeliverySetupValidator
    private let credentials: any CredentialStoring
    private let preferences: any DeliveryPreferencesStoring
    private let serviceName = "com.rckbrcls.BookSender.smtp"

    init(
        validator: DeliverySetupValidator = DeliverySetupValidator(),
        credentials: any CredentialStoring,
        preferences: any DeliveryPreferencesStoring
    ) {
        self.validator = validator
        self.credentials = credentials
        self.preferences = preferences
    }

    func load() async -> DeliverySetup? {
        await preferences.load()
    }

    func save(_ draft: DeliverySetupDraft, replacing current: DeliverySetup?) async throws -> DeliverySetup {
        let keepsExistingCredential = draft.appPassword.isEmpty && current != nil
        let validation = validator.validate(draft, requiresPassword: !keepsExistingCredential)
        guard validation.isValid else {
            throw validation.fieldErrors.values.first ?? DeliveryValidationError.invalidPort
        }
        let reference: CredentialReference
        let createdCredential: Bool
        if keepsExistingCredential, let current {
            reference = current.credentialReference
            createdCredential = false
        } else {
            reference = try await credentials.save(
                secret: draft.appPassword,
                service: serviceName,
                account: validation.normalizedDraft.username
            )
            createdCredential = true
        }
        do {
            let setup = try validator.makeSetup(
                from: validation.normalizedDraft,
                credentialReference: reference,
                revision: (current?.revision ?? 0) + 1,
                requiresPassword: !keepsExistingCredential
            )
            try await preferences.save(setup)
            if let old = current?.credentialReference, old != reference {
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
}
