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
