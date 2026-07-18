import Foundation
import AppKit

protocol DocumentDelivering {
    func validateForSend(source: URL, profileName: String?) throws -> DeliveryProfile
    func send(source: URL, profileName: String?) throws -> SendResult
}

protocol DeliveryConfigProviding {
    func profile(named name: String?) throws -> DeliveryProfile
}

protocol DeliverySecretProviding {
    func getPassword(profileName: String) throws -> String
    func hasPassword(profileName: String) -> Bool
}

protocol SMTPSending {
    func send(
        host: String,
        port: Int,
        useTLS: Bool,
        username: String,
        password: String,
        from: String,
        to: String,
        subject: String,
        attachmentURL: URL
    ) throws
}

extension ConfigService: DeliveryConfigProviding {}
extension SecretService: DeliverySecretProviding {}
extension SMTPClient: SMTPSending {}

struct DeliveryService {
    static let maximumAttachmentBytes: Int64 = 200 * 1024 * 1024

    private let configService: any DeliveryConfigProviding
    private let secretService: any DeliverySecretProviding
    private let smtpClient: any SMTPSending
    private let handoffURL: URL

    init(
        configService: any DeliveryConfigProviding = ConfigService(),
        secretService: any DeliverySecretProviding = SecretService(),
        smtpClient: any SMTPSending = SMTPClient(),
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

    func preflight(outputs: [PreparedOutput], profileName: String?) throws -> DeliveryProfile {
        guard let profileName, !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.configuration("Select a delivery profile before sending.")
        }
        let profile = try configService.profile(named: profileName)
        guard profile.isStructurallySendReady(
            hasSecret: secretService.hasPassword(profileName: profile.name)
        ) else {
            throw DomainError.configuration(
                "Profile `\(profile.name)` is incomplete. Finish setup in Settings."
            )
        }
        guard outputs.contains(where: { FileManager.default.isReadableFile(atPath: $0.outputURL.path) }) else {
            throw DomainError.filesystem("No readable prepared output is available to send.")
        }
        return profile
    }

    func validateForSend(source: URL, profileName: String?) throws -> DeliveryProfile {
        let input = try FilePathValidator.requireExistingFile(source)
        guard FileManager.default.isReadableFile(atPath: input.path) else {
            throw DomainError.filesystem("Prepared output is unreadable: \(input.lastPathComponent)")
        }
        if let size = try? input.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           Int64(size) > Self.maximumAttachmentBytes {
            throw DomainError.delivery("File is larger than the 200 MB Send to Kindle delivery limit.")
        }
        let profile = try configService.profile(named: profileName)
        guard profile.isStructurallySendReady(
            hasSecret: secretService.hasPassword(profileName: profile.name)
        ) else {
            throw DomainError.configuration(
                "Profile `\(profile.name)` is incomplete. Finish setup in Settings."
            )
        }
        return profile
    }

    func send(source: URL, profileName: String?) throws -> SendResult {
        let input = try FilePathValidator.requireExistingFile(source)
        let profile = try validateForSend(source: input, profileName: profileName)
        let password = try secretService.getPassword(profileName: profile.name)
        do {
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
        } catch {
            let safeMessage = error.localizedDescription.replacingOccurrences(
                of: password,
                with: "[REDACTED]"
            )
            throw DomainError.delivery(safeMessage)
        }
        return SendResult(
            inputPath: input,
            senderEmail: profile.senderEmail,
            kindleEmail: profile.kindleEmail,
            profileName: profile.name
        )
    }

    func send(outputs: [PreparedOutput], profileName: String) throws -> [DocumentDeliveryResult] {
        let profile = try preflight(outputs: outputs, profileName: profileName)

        return outputs.map { output in
            do {
                let result = try send(source: output.outputURL, profileName: profile.name)
                return DocumentDeliveryResult(
                    outputURL: output.outputURL,
                    profileName: result.profileName,
                    kindleEmail: result.kindleEmail,
                    state: .succeeded,
                    message: "Sent \(output.outputURL.lastPathComponent) to Kindle."
                )
            } catch {
                return DocumentDeliveryResult(
                    outputURL: output.outputURL,
                    profileName: profile.name,
                    kindleEmail: profile.kindleEmail,
                    state: .failed,
                    message: error.localizedDescription
                )
            }
        }
    }

    func openHandoff() {
        NSWorkspace.shared.open(handoffURL)
    }
}

extension DeliveryService: DocumentDelivering {}
