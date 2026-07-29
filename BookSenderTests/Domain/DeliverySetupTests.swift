import Testing
@testable import BookSender

struct DeliverySetupTests {
    private let validator = DeliverySetupValidator()

    @Test
    func normalizesSetupAndCreatesRevision() throws {
        let draft = DeliverySetupDraft(
            senderAddress: " Reader@Example.com ",
            smtpHost: " SMTP.Example.com ",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: " reader ",
            appPassword: "secret-value",
            kindleAddress: " Reader@Kindle.com "
        )
        let result = validator.validate(draft)
        #expect(result.isValid)
        let setup = try validator.makeSetup(
            from: result.normalizedDraft,
            credentialReference: CredentialReference(
                service: "test",
                account: "reader",
                revision: 3
            ),
            revision: 3
        )
        #expect(setup.senderAddress.value == "reader@example.com")
        #expect(setup.smtpHost.value == "smtp.example.com")
        #expect(setup.kindleAddress.value == "reader@kindle.com")
        #expect(setup.revision == 3)
        #expect(String(describing: setup).contains("secret-value") == false)
    }

    @Test
    func usesRevisionScopedCredentialWithoutExposingPassword() throws {
        let draft = DeliverySetupDraft(
            senderAddress: "reader@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "587",
            securityMode: .startTLS,
            username: "reader",
            appPassword: "provider-secret",
            kindleAddress: "reader@kindle.com"
        )
        let reference = CredentialReference(
            service: "test.smtp",
            account: "revision-4-id",
            revision: 4
        )
        let setup = try validator.makeSetup(
            from: draft,
            credentialReference: reference,
            revision: 4
        )

        #expect(setup.credentialReference.revision == setup.revision)
        #expect(setup.kindleAddress.value == "reader@kindle.com")
        #expect(String(describing: setup).contains("provider-secret") == false)
        #expect(String(describing: reference).contains("provider-secret") == false)
    }

    @Test
    func rejectsInvalidValuesAtTheirFields() {
        let result = validator.validate(DeliverySetupDraft())
        #expect(result.fieldErrors.keys.contains(.senderAddress))
        #expect(result.fieldErrors.keys.contains(.smtpHost))
        #expect(result.fieldErrors.keys.contains(.username))
        #expect(result.fieldErrors.keys.contains(.appPassword))
        #expect(result.fieldErrors.keys.contains(.kindleAddress))
    }

    @Test
    func rejectsInvalidPortHostUsernameAndKindleDestination() {
        let result = validator.validate(
            DeliverySetupDraft(
                senderAddress: "reader@example.com",
                smtpHost: "-invalid.example.com",
                smtpPort: "65536",
                securityMode: .startTLS,
                username: "reader\r\nAUTH",
                appPassword: "secret",
                kindleAddress: "reader@example.com"
            )
        )

        #expect(result.fieldErrors[.smtpHost] == .invalidHost)
        #expect(result.fieldErrors[.smtpPort] == .invalidPort)
        #expect(result.fieldErrors[.username] == .invalidUsername)
        #expect(result.fieldErrors[.kindleAddress] == .kindleDomainRequired)
    }

    @Test
    func permitsBlankPasswordOnlyWhenEditingExistingSetup() {
        var draft = DeliverySetupDraft(
            senderAddress: "reader@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: "reader",
            appPassword: "",
            kindleAddress: "reader@kindle.com"
        )
        #expect(validator.validate(draft).fieldErrors[.appPassword] != nil)
        #expect(validator.validate(draft, requiresPassword: false).fieldErrors[.appPassword] == nil)
        draft.appPassword = "new-secret"
        #expect(validator.validate(draft).isValid)
    }
}
