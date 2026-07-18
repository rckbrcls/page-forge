import Foundation

struct ConfigService {
    private let store: ConfigStore

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
    }

    func load() throws -> AppConfig {
        try store.load()
    }

    func save(_ config: AppConfig) throws {
        try store.save(config)
    }

    func upsertProfile(_ profile: DeliveryProfile, makeDefault: Bool = true) throws {
        var config = try load()
        config.profiles[profile.name] = profile
        if makeDefault {
            config.defaultProfile = profile.name
        }
        try save(config)
    }

    func defaultProfile() throws -> DeliveryProfile {
        let config = try load()
        if let profile = config.profiles[config.defaultProfile] {
            return profile
        }
        guard let first = config.profiles.values.sorted(by: { $0.name < $1.name }).first else {
            return DeliveryProfile()
        }
        return first
    }

    func profile(named name: String?) throws -> DeliveryProfile {
        let config = try load()
        let key = name ?? config.defaultProfile
        guard let profile = config.profiles[key] else {
            throw DomainError.configuration("Profile not found: \(key)")
        }
        return profile
    }
}
