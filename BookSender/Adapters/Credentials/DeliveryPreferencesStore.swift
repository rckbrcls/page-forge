import Foundation

actor DeliveryPreferencesStore: DeliveryPreferencesStoring {
    private let defaults: UserDefaults
    private let key = "deliverySetup"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DeliverySetup? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DeliverySetup.self, from: data)
    }

    func save(_ setup: DeliverySetup) throws {
        let data = try JSONEncoder().encode(setup)
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
