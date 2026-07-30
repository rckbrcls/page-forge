import Foundation
import Testing
@testable import BookSender

struct DeliveryPreferencesStoreTests {
    @Test
    func roundTripsOnlyValidatedNonSecretSetup() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = DeliveryPreferencesStore(
            suiteName: stores.defaultsSuiteName
        )
        let setup = try makeSetup(revision: 2)

        try await store.save(setup)
        guard case .value(let loaded) = await store.load() else {
            Issue.record("Expected stored setup")
            return
        }
        #expect(loaded == setup)

        let data = try #require(
            stores.defaults.data(forKey: DeliveryPreferencesStore.storageKey)
        )
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("provider-secret") == false)
        #expect(text.contains("source.snapshot") == false)
        #expect(text.contains("prepared.epub") == false)
    }

    @Test
    func distinguishesInvalidDecodeAndClear() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = DeliveryPreferencesStore(
            suiteName: stores.defaultsSuiteName
        )
        stores.defaults.set(
            Data("{\"invalid\":true}".utf8),
            forKey: DeliveryPreferencesStore.storageKey
        )

        if case .invalid = await store.load() {
            // Expected.
        } else {
            Issue.record("Expected invalid preferences")
        }
        await store.clear()
        if case .absent = await store.load() {
            // Expected.
        } else {
            Issue.record("Expected absent preferences")
        }
    }

    @Test
    func rejectsRevisionMismatchWithPreferenceWriteEvidence() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = DeliveryPreferencesStore(
            suiteName: stores.defaultsSuiteName
        )
        let valid = try makeSetup(revision: 2)
        let mismatched = DeliverySetup(
            senderAddress: valid.senderAddress,
            smtpHost: valid.smtpHost,
            smtpPort: valid.smtpPort,
            securityMode: valid.securityMode,
            username: valid.username,
            credentialReference: CredentialReference(
                service: "test",
                account: "revision-1",
                revision: 1
            ),
            kindleAddress: valid.kindleAddress,
            revision: 2
        )

        do {
            try await store.save(mismatched)
            Issue.record("Expected revision mismatch")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .preferencesInvalidRevision)
            #expect(failure.evidence.phase == .preferenceWrite)
            #expect(failure.evidence.providerStatus == nil)
        }
    }

    private func makeSetup(revision: Int) throws -> DeliverySetup {
        try DeliverySetupValidator().makeSetup(
            from: DeliverySetupDraft(
                senderAddress: "reader@example.com",
                smtpHost: "smtp.example.com",
                smtpPort: "465",
                securityMode: .implicitTLS,
                username: "reader",
                appPassword: "provider-secret",
                kindleAddress: "reader@kindle.com"
            ),
            credentialReference: CredentialReference(
                service: "test",
                account: "revision-\(revision)",
                revision: revision
            ),
            revision: revision
        )
    }
}
