import XCTest
@testable import PageForge

final class DocumentDeliveryWorkflowTests: XCTestCase {
    func testPreflightRequiresExplicitCompleteProfileAndReadableOutput() throws {
        let fixture = try TemporaryDocumentFactory()
        let attachment = try fixture.makeEPUB(named: "Ready.epub")
        let config = DeliveryConfigStub(profile: completeProfile)
        let secrets = DeliverySecretStub(secret: "app-password")
        let smtp = SMTPSendingSpy()
        let service = DeliveryService(configService: config, secretService: secrets, smtpClient: smtp)
        let output = makeOutput(attachment)

        XCTAssertThrowsError(try service.preflight(outputs: [output], profileName: nil)) { error in
            XCTAssertEqual(error as? DomainError, .configuration("Select a delivery profile before sending."))
        }

        secrets.hasSecret = false
        XCTAssertThrowsError(try service.preflight(outputs: [output], profileName: "kindle")) { error in
            guard case DomainError.configuration(let message) = error else {
                return XCTFail("Expected configuration error, got \(error)")
            }
            XCTAssertTrue(message.contains("incomplete"))
        }
        XCTAssertTrue(smtp.attachments.isEmpty)
    }

    func testSendPreservesStableOrder() throws {
        let fixture = try TemporaryDocumentFactory()
        let first = try fixture.makeEPUB(named: "First.epub")
        let second = try fixture.makeEPUB(named: "Second.epub")
        let smtp = SMTPSendingSpy()
        let service = makeService(smtp: smtp)

        let results = try service.send(
            outputs: [makeOutput(first), makeOutput(second)],
            profileName: "kindle"
        )

        XCTAssertEqual(smtp.attachments, [first, second])
        XCTAssertEqual(results.map(\.outputURL), [first, second])
        XCTAssertEqual(results.map(\.state), [.succeeded, .succeeded])
    }

    func testMissingAttachmentFailsIndependentlyAndPreservesLaterSuccess() throws {
        let fixture = try TemporaryDocumentFactory()
        let missing = fixture.directoryURL.appendingPathComponent("Missing.epub")
        let readable = try fixture.makeEPUB(named: "Readable.epub")
        let smtp = SMTPSendingSpy()
        let service = makeService(smtp: smtp)

        let results = try service.send(
            outputs: [makeOutput(missing), makeOutput(readable)],
            profileName: "kindle"
        )

        XCTAssertEqual(results.map(\.state), [.failed, .succeeded])
        XCTAssertEqual(smtp.attachments, [readable])
    }

    func testOversizedAttachmentFailsBeforeSMTPSubmission() throws {
        let fixture = try TemporaryDocumentFactory()
        let oversized = fixture.directoryURL.appendingPathComponent("Oversized.epub")
        XCTAssertTrue(FileManager.default.createFile(atPath: oversized.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(DeliveryService.maximumAttachmentBytes + 1))
        try handle.close()
        let valid = try fixture.makeEPUB(named: "Valid.epub")
        let smtp = SMTPSendingSpy()
        let service = makeService(smtp: smtp)

        let results = try service.send(
            outputs: [makeOutput(oversized), makeOutput(valid)],
            profileName: "kindle"
        )

        XCTAssertEqual(results.map(\.state), [.failed, .succeeded])
        XCTAssertTrue(results[0].message.contains("200 MB"))
        XCTAssertEqual(smtp.attachments, [valid])
    }

    func testSMTPFailureIsRedactedAndDoesNotDiscardPriorSuccess() throws {
        let fixture = try TemporaryDocumentFactory()
        let first = try fixture.makeEPUB(named: "First.epub")
        let second = try fixture.makeEPUB(named: "Second.epub")
        let secret = "super-secret-password"
        let smtp = SMTPSendingSpy()
        smtp.failureByFilename[second.lastPathComponent] = DomainError.delivery("Rejected \(secret)")
        let service = DeliveryService(
            configService: DeliveryConfigStub(profile: completeProfile),
            secretService: DeliverySecretStub(secret: secret),
            smtpClient: smtp
        )

        let results = try service.send(
            outputs: [makeOutput(first), makeOutput(second)],
            profileName: "kindle"
        )

        XCTAssertEqual(results.map(\.state), [.succeeded, .failed])
        XCTAssertFalse(results[1].message.contains(secret))
        XCTAssertTrue(results[1].message.contains("[REDACTED]"))
        XCTAssertEqual(smtp.attachments, [first, second])
    }

    private var completeProfile: DeliveryProfile {
        DeliveryProfile(
            name: "kindle",
            senderEmail: "reader@example.com",
            kindleEmail: "reader@kindle.com",
            smtpHost: "smtp.example.com",
            smtpPort: 587,
            smtpUsername: "reader@example.com",
            useTLS: true
        )
    }

    private func makeService(smtp: SMTPSendingSpy) -> DeliveryService {
        DeliveryService(
            configService: DeliveryConfigStub(profile: completeProfile),
            secretService: DeliverySecretStub(secret: "app-password"),
            smtpClient: smtp
        )
    }

    private func makeOutput(_ url: URL) -> PreparedOutput {
        PreparedOutput(
            sourceURL: url,
            outputURL: url,
            sizeBytes: 0,
            readinessStatus: .ready
        )
    }
}

private final class DeliveryConfigStub: DeliveryConfigProviding {
    let profile: DeliveryProfile

    init(profile: DeliveryProfile) {
        self.profile = profile
    }

    func profile(named name: String?) throws -> DeliveryProfile {
        guard name == profile.name else {
            throw DomainError.configuration("Profile not found: \(name ?? "nil")")
        }
        return profile
    }
}

private final class DeliverySecretStub: DeliverySecretProviding {
    var hasSecret = true
    let secret: String

    init(secret: String) {
        self.secret = secret
    }

    func getPassword(profileName: String) throws -> String {
        guard hasSecret else {
            throw DomainError.configuration("Password is unavailable.")
        }
        return secret
    }

    func hasPassword(profileName: String) -> Bool {
        hasSecret
    }
}

private final class SMTPSendingSpy: SMTPSending {
    var attachments: [URL] = []
    var failureByFilename: [String: Error] = [:]

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
    ) throws {
        attachments.append(attachmentURL)
        if let error = failureByFilename[attachmentURL.lastPathComponent] {
            throw error
        }
    }
}
