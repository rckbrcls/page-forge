import Foundation

struct TestStores {
    let rootURL: URL
    let defaults: UserDefaults
    let defaultsSuiteName: String
    let keychainServiceName: String

    static func make() throws -> TestStores {
        let identifier = UUID().uuidString
        let root = FileManager.default.temporaryDirectory
            .appending(component: "BookSenderTests-\(identifier)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let suite = "com.rckbrcls.BookSenderTests.\(identifier)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw TestStoreError.defaultsUnavailable
        }
        defaults.removePersistentDomain(forName: suite)
        return TestStores(
            rootURL: root,
            defaults: defaults,
            defaultsSuiteName: suite,
            keychainServiceName: "com.rckbrcls.BookSenderTests.smtp.\(identifier)"
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: rootURL)
    }
}

enum TestStoreError: Error {
    case defaultsUnavailable
}

