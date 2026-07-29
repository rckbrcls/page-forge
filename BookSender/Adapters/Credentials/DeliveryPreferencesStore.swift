import Foundation

actor DeliveryPreferencesStore: DeliveryPreferencesStoring {
    static let storageKey = "deliverySetup"

    private let defaults: UserDefaults

    init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:))
            ?? .standard
    }

    func load() -> DeliveryPreferencesLoadResult {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .absent
        }
        guard let setup = try? JSONDecoder().decode(DeliverySetup.self, from: data),
              setup.revision > 0,
              setup.credentialReference.revision == setup.revision
        else {
            return .invalid
        }
        return .value(setup)
    }

    func save(_ setup: DeliverySetup) throws {
        guard setup.revision > 0,
              setup.credentialReference.revision == setup.revision
        else {
            throw SanitizedFailure(
                family: .credential,
                code: "preferences.invalid-revision",
                message: "Delivery settings could not be saved consistently.",
                recoveryAction: .editSetup
            )
        }
        let data = try JSONEncoder().encode(setup)
        defaults.set(data, forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
