import Foundation

struct DeliveryProfile: Identifiable, Equatable, Codable, Sendable {
    var id: String { name }
    var name: String
    var senderEmail: String
    var kindleEmail: String
    var smtpHost: String
    var smtpPort: Int
    var smtpUsername: String
    var useTLS: Bool
    var defaultOutputDir: String

    init(
        name: String = "default",
        senderEmail: String = "",
        kindleEmail: String = "",
        smtpHost: String = "smtp.gmail.com",
        smtpPort: Int = 587,
        smtpUsername: String = "",
        useTLS: Bool = true,
        defaultOutputDir: String = ""
    ) {
        self.name = name
        self.senderEmail = senderEmail
        self.kindleEmail = kindleEmail
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.smtpUsername = smtpUsername
        self.useTLS = useTLS
        self.defaultOutputDir = defaultOutputDir
    }

    var loginUsername: String {
        smtpUsername.isEmpty ? senderEmail : smtpUsername
    }

    func isStructurallySendReady(hasSecret: Bool) -> Bool {
        !senderEmail.isEmpty
            && !kindleEmail.isEmpty
            && !smtpHost.isEmpty
            && smtpPort > 0
            && !loginUsername.isEmpty
            && hasSecret
    }
}

struct AppConfig: Equatable, Codable, Sendable {
    var defaultProfile: String
    var profiles: [String: DeliveryProfile]
    var defaultOutputDirectory: String

    init(
        defaultProfile: String = "default",
        profiles: [String: DeliveryProfile] = ["default": DeliveryProfile()],
        defaultOutputDirectory: String = ""
    ) {
        self.defaultProfile = defaultProfile
        self.profiles = profiles
        self.defaultOutputDirectory = defaultOutputDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case defaultProfile
        case profiles
        case defaultOutputDirectory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultProfile = try container.decodeIfPresent(String.self, forKey: .defaultProfile)
            ?? "default"
        profiles = try container.decodeIfPresent(
            [String: DeliveryProfile].self,
            forKey: .profiles
        ) ?? ["default": DeliveryProfile()]
        defaultOutputDirectory = try container.decodeIfPresent(
            String.self,
            forKey: .defaultOutputDirectory
        ) ?? ""
    }
}

struct SendResult: Equatable, Sendable {
    var inputPath: URL
    var senderEmail: String
    var kindleEmail: String
    var profileName: String
}
