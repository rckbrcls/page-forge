import Testing
@testable import BookSender

struct DeliverySetupServiceTests {
    @Test
    func initialSaveAndLoadRequireCredentialExistence() async throws {
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let service = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: "test.smtp"
        )

        let saved = try await service.save(validDraft(), replacing: nil)
        #expect(saved.revision == 1)
        #expect(saved.credentialReference.revision == 1)
        guard case .complete(let loaded) = await service.load() else {
            Issue.record("Expected complete setup")
            return
        }
        #expect(loaded == saved)
    }

    @Test
    func blankPasswordReusesCredentialIdentityAndAdvancesRevision() async throws {
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let service = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: "test.smtp"
        )
        let first = try await service.save(validDraft(), replacing: nil)
        var edited = validDraft()
        edited.appPassword = ""
        edited.smtpPort = "587"

        let second = try await service.save(edited, replacing: first)
        #expect(second.revision == 2)
        #expect(second.credentialReference.account == first.credentialReference.account)
        #expect(second.credentialReference.revision == 2)
        #expect(await credentials.exists(second.credentialReference))
    }

    @Test
    func preferenceFailureDeletesOnlyNewCredentialAndPreservesOld() async throws {
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let service = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: "test.smtp"
        )
        let first = try await service.save(validDraft(), replacing: nil)
        await preferences.setSaveFailure(
            sanitizedFailure("preferences.save", family: .credential)
        )
        var replacement = validDraft()
        replacement.appPassword = "replacement-secret"

        await #expect(throws: SanitizedFailure.self) {
            _ = try await service.save(replacement, replacing: first)
        }
        #expect(await credentials.exists(first.credentialReference))
        #expect(await preferences.savedSetups.last == first)
    }

    @Test
    func successfulReplacementDeletesOldCredentialAfterPreferencesCommit() async throws {
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let service = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: "test.smtp"
        )
        let first = try await service.save(validDraft(), replacing: nil)
        var replacement = validDraft()
        replacement.appPassword = "replacement-secret"

        let second = try await service.save(replacement, replacing: first)

        #expect(second.credentialReference != first.credentialReference)
        #expect(await credentials.exists(second.credentialReference))
        #expect(await credentials.exists(first.credentialReference) == false)
    }

    @Test
    func credentialSaveFailureDoesNotChangePreferences() async throws {
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let service = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: "test.smtp"
        )
        await credentials.setSaveFailure(
            sanitizedFailure("credential.save", family: .credential)
        )

        await #expect(throws: SanitizedFailure.self) {
            _ = try await service.save(validDraft(), replacing: nil)
        }
        #expect(await preferences.savedSetups.isEmpty)
    }

    @Test
    func missingCredentialLoadsIncompleteWithSafeDraft() async throws {
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let setup = try makeSetup(revision: 1)
        await preferences.setResult(.value(setup))
        let service = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: "test.smtp"
        )

        guard case .incomplete(let draft, let failure) = await service.load()
        else {
            Issue.record("Expected incomplete setup")
            return
        }
        #expect(draft.senderAddress == setup.senderAddress.value)
        #expect(draft.appPassword.isEmpty)
        #expect(failure?.code == "credential.missing")
    }

    private func validDraft() -> DeliverySetupDraft {
        DeliverySetupDraft(
            senderAddress: "reader@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: "reader",
            appPassword: "provider-secret",
            kindleAddress: "reader@kindle.com"
        )
    }

    private func makeSetup(revision: Int) throws -> DeliverySetup {
        try DeliverySetupValidator().makeSetup(
            from: validDraft(),
            credentialReference: CredentialReference(
                service: "test.smtp",
                account: "revision-\(revision)",
                revision: revision
            ),
            revision: revision
        )
    }
}
