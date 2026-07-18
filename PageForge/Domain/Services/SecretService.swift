import Foundation

struct SecretService {
    private let store: KeychainSecretStore

    init(store: KeychainSecretStore = KeychainSecretStore()) {
        self.store = store
    }

    func account(for profileName: String) -> String {
        "smtp:\(profileName)"
    }

    func setPassword(profileName: String, secret: String) throws {
        try store.setPassword(account: account(for: profileName), secret: secret)
    }

    func getPassword(profileName: String) throws -> String {
        try store.getPassword(account: account(for: profileName))
    }

    func hasPassword(profileName: String) -> Bool {
        store.hasPassword(account: account(for: profileName))
    }

    func deletePassword(profileName: String) throws {
        try store.deletePassword(account: account(for: profileName))
    }
}
