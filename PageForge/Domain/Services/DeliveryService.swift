import Foundation
import AppKit

struct DeliveryService {
    private let configService: ConfigService
    private let secretService: SecretService
    private let smtpClient: SMTPClient
    private let handoffURL: URL

    init(
        configService: ConfigService = ConfigService(),
        secretService: SecretService = SecretService(),
        smtpClient: SMTPClient = SMTPClient(),
        handoffURL: URL = URL(string: "https://www.amazon.com/sendtokindle")!
    ) {
        self.configService = configService
        self.secretService = secretService
        self.smtpClient = smtpClient
        self.handoffURL = handoffURL
    }

    func isProfileSendReady(profileName: String?) throws -> Bool {
        let profile = try configService.profile(named: profileName)
        return profile.isStructurallySendReady(hasSecret: secretService.hasPassword(profileName: profile.name))
    }

    func send(source: URL, profileName: String?) throws -> SendResult {
        let input = try FilePathValidator.requireExistingFile(source)
        let profile = try configService.profile(named: profileName)
        guard profile.isStructurallySendReady(hasSecret: secretService.hasPassword(profileName: profile.name)) else {
            throw DomainError.configuration(
                "Profile `\(profile.name)` is incomplete. Finish setup in Settings."
            )
        }
        let password = try secretService.getPassword(profileName: profile.name)
        try smtpClient.send(
            host: profile.smtpHost,
            port: profile.smtpPort,
            useTLS: profile.useTLS,
            username: profile.loginUsername,
            password: password,
            from: profile.senderEmail,
            to: profile.kindleEmail,
            subject: input.deletingPathExtension().lastPathComponent,
            attachmentURL: input
        )
        return SendResult(
            inputPath: input,
            senderEmail: profile.senderEmail,
            kindleEmail: profile.kindleEmail,
            profileName: profile.name
        )
    }

    func openHandoff() {
        NSWorkspace.shared.open(handoffURL)
    }
}
