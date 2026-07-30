import Foundation
import Security
import Testing
@testable import BookSender

struct KeychainCredentialStoreTests {
    @Test
    func createsRereadsChecksAndDeletesTraditionalKeychainCredential() async throws {
        let writer = KeychainCredentialStore()
        let service = "com.rckbrcls.BookSenderTests.\(UUID().uuidString)"
        let reference = try await writer.save(
            secret: "test-secret",
            service: service,
            account: "revision-1",
            revision: 1
        )
        defer {
            Task { try? await writer.delete(reference) }
        }

        let reader = KeychainCredentialStore()
        #expect(await reader.exists(reference))
        #expect(try await reader.read(reference) == "test-secret")
        let attributes = try attributes(for: reference)
        #expect(
            (attributes[kSecAttrSynchronizable as String] as? Bool) != true
        )

        try await reader.delete(reference)
        #expect(await writer.exists(reference) == false)
    }

    @Test
    func replacementPreservesPreviousRevisionUntilExplicitDeletion() async throws {
        let store = KeychainCredentialStore()
        let service = "com.rckbrcls.BookSenderTests.\(UUID().uuidString)"
        let first = try await store.save(
            secret: "first",
            service: service,
            account: "revision-1",
            revision: 1
        )
        let second = try await store.save(
            secret: "second",
            service: service,
            account: "revision-2",
            revision: 2
        )
        defer {
            Task {
                try? await store.delete(first)
                try? await store.delete(second)
            }
        }

        #expect(first != second)
        #expect(try await store.read(first) == "first")
        #expect(try await store.read(second) == "second")

        try await store.delete(second)
        #expect(try await store.read(first) == "first")
        #expect(await store.exists(second) == false)
    }

    @Test
    func returnsSanitizedFailuresForMissingOrEmptyCredentials() async {
        let store = KeychainCredentialStore()
        do {
            _ = try await store.save(
                secret: "",
                service: "test",
                account: "empty",
                revision: 1
            )
            Issue.record("Expected empty credential failure")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .credentialEmpty)
            #expect(failure.evidence.phase == .credentialWrite)
            #expect(failure.evidence.providerStatus == nil)
        } catch {
            Issue.record("Expected sanitized credential failure")
        }
        do {
            _ = try await store.read(
                CredentialReference(
                    service: "missing",
                    account: "missing",
                    revision: 1
                )
            )
            Issue.record("Expected missing credential failure")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .credentialRead)
            #expect(failure.evidence.phase == .credentialRead)
            #expect(
                String(describing: failure)
                    .contains(DiagnosticTestFixtures.password) == false
            )
        } catch {
            Issue.record("Expected sanitized credential failure")
        }
    }

    private func attributes(
        for reference: CredentialReference
    ) throws -> [String: Any] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: reference.service,
            kSecAttrAccount as String: reference.account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let attributes = result as? [String: Any]
        else {
            throw KeychainTestError.attributesUnavailable
        }
        return attributes
    }
}

private enum KeychainTestError: Error {
    case attributesUnavailable
}
