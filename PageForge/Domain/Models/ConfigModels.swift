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

    init(
        defaultProfile: String = "default",
        profiles: [String: DeliveryProfile] = ["default": DeliveryProfile()]
    ) {
        self.defaultProfile = defaultProfile
        self.profiles = profiles
    }
}

struct SendResult: Equatable, Sendable {
    var inputPath: URL
    var senderEmail: String
    var kindleEmail: String
    var profileName: String
}
