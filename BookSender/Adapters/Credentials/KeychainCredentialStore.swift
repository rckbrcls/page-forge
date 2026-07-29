import Foundation
import Security

actor KeychainCredentialStore: CredentialStoring {
    func save(secret: String, service: String, account: String) throws -> CredentialReference {
        guard !secret.isEmpty, let data = secret.data(using: .utf8) else {
            throw failure("credential.empty")
        }
        let reference = CredentialReference(service: service, account: account)
        var query = baseQuery(reference)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw failure("credential.save") }
        } else if status != errSecSuccess {
            throw failure("credential.save")
        }
        return reference
    }

    func read(_ reference: CredentialReference) throws -> String {
        var query = baseQuery(reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8)
        else { throw failure("credential.read") }
        return secret
    }

    func delete(_ reference: CredentialReference) throws {
        let status = SecItemDelete(baseQuery(reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw failure("credential.delete")
        }
    }

    private func baseQuery(_ reference: CredentialReference) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: reference.service,
            kSecAttrAccount as String: reference.account,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .credential,
            code: code,
            message: "The app password could not be stored securely.",
            recoveryAction: .editSetup
        )
    }
}
