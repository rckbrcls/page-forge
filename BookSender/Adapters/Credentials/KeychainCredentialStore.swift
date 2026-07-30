import Foundation
import Security

actor KeychainCredentialStore: CredentialStoring {
    func save(
        secret: String,
        service: String,
        account: String,
        revision: Int
    ) throws -> CredentialReference {
        guard !secret.isEmpty,
              revision > 0,
              let data = secret.data(using: .utf8)
        else {
            throw failure("credential.empty")
        }

        let reference = CredentialReference(
            service: service,
            account: account,
            revision: revision
        )
        var query = identityQuery(reference)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw failure("credential.save")
        }
        return reference
    }

    func read(_ reference: CredentialReference) throws -> String {
        var query = identityQuery(reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8),
              !secret.isEmpty
        else {
            throw failure("credential.read")
        }
        return secret
    }

    func exists(_ reference: CredentialReference) -> Bool {
        var query = identityQuery(reference)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func delete(_ reference: CredentialReference) throws {
        let query = identityQuery(reference)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw failure("credential.delete")
        }
    }

    private func identityQuery(_ reference: CredentialReference) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: reference.service,
            kSecAttrAccount as String: reference.account,
        ]
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .credential,
            code: code,
            message: "The app password could not be accessed securely.",
            recoveryAction: .editSetup
        )
    }
}
