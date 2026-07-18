import Foundation
import Security

struct KeychainSecretStore {
    private let service: String

    init(service: String = "page-forge") {
        self.service = service
    }

    func setPassword(account: String, secret: String) throws {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DomainError.configuration("Could not store password in Keychain (status \(status)).")
        }
    }

    func getPassword(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let secret = String(data: data, encoding: .utf8), !secret.isEmpty else {
            throw DomainError.configuration(
                "SMTP password is missing for profile `\(account.replacingOccurrences(of: "smtp:", with: ""))`. Configure it in Settings."
            )
        }
        return secret
    }

    func hasPassword(account: String) -> Bool {
        (try? getPassword(account: account)) != nil
    }

    func deletePassword(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DomainError.configuration("Could not delete password from Keychain (status \(status)).")
        }
    }
}
