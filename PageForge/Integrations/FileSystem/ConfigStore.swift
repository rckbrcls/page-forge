import Foundation

struct ConfigStore {
    private let fileManager: FileManager
    private let configURL: URL

    init(fileManager: FileManager = .default, configURL: URL? = nil) {
        self.fileManager = fileManager
        if let configURL {
            self.configURL = configURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.configURL = base
                .appendingPathComponent("PageForge", isDirectory: true)
                .appendingPathComponent("config.json")
        }
    }

    func load() throws -> AppConfig {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return AppConfig()
        }
        let data = try Data(contentsOf: configURL)
        let decoder = JSONDecoder()
        return try decoder.decode(AppConfig.self, from: data)
    }

    func save(_ config: AppConfig) throws {
        try fileManager.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    var url: URL { configURL }
}
