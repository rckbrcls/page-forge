import Foundation

struct EmailAddress: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) throws {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalized.count <= 254,
              normalized.unicodeScalars.allSatisfy(\.isASCII),
              normalized.range(
                of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#,
                options: .regularExpression
              ) != nil
        else {
            throw DeliveryValidationError.invalidEmail
        }
        self.value = normalized
    }
}

struct SMTPHost: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) throws {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let labels = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard normalized.count <= 253,
              labels.count >= 2,
              labels.allSatisfy({
                  guard let first = $0.first, let last = $0.last else {
                      return false
                  }
                  return $0.count <= 63
                      && (first.isLetter || first.isNumber)
                      && (last.isLetter || last.isNumber)
              }),
              normalized.range(
                of: #"^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$"#,
                options: .regularExpression
              ) != nil
        else {
            throw DeliveryValidationError.invalidHost
        }
        self.value = normalized
    }
}

enum SecurityMode: String, CaseIterable, Codable, Sendable {
    case implicitTLS
    case startTLS

    var title: String {
        switch self {
        case .implicitTLS: "Implicit TLS"
        case .startTLS: "STARTTLS"
        }
    }
}

struct CredentialReference: Codable, Hashable, Sendable {
    let service: String
    let account: String
    let revision: Int

    init(service: String, account: String, revision: Int = 0) {
        self.service = service
        self.account = account
        self.revision = revision
    }
}

struct DeliverySetup: Codable, Equatable, Sendable {
    let senderAddress: EmailAddress
    let smtpHost: SMTPHost
    let smtpPort: UInt16
    let securityMode: SecurityMode
    let username: String
    let credentialReference: CredentialReference
    let kindleAddress: EmailAddress
    let revision: Int
}

typealias ValidatedDeliverySetup = DeliverySetup

enum SetupLoadResult: Equatable, Sendable {
    case complete(ValidatedDeliverySetup)
    case incomplete(prefilledDraft: DeliverySetupDraft, failure: SanitizedFailure?)
}

enum DeliveryPreferencesLoadResult: Sendable {
    case absent
    case value(DeliverySetup)
    case invalid
}

struct DeliverySetupDraft: Equatable, Sendable {
    var senderAddress = ""
    var smtpHost = ""
    var smtpPort = "465"
    var securityMode = SecurityMode.implicitTLS
    var username = ""
    var appPassword = ""
    var kindleAddress = ""

    init(
        senderAddress: String = "",
        smtpHost: String = "",
        smtpPort: String = "465",
        securityMode: SecurityMode = .implicitTLS,
        username: String = "",
        appPassword: String = "",
        kindleAddress: String = ""
    ) {
        self.senderAddress = senderAddress
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.securityMode = securityMode
        self.username = username
        self.appPassword = appPassword
        self.kindleAddress = kindleAddress
    }

    init(setup: DeliverySetup) {
        senderAddress = setup.senderAddress.value
        smtpHost = setup.smtpHost.value
        smtpPort = String(setup.smtpPort)
        securityMode = setup.securityMode
        username = setup.username
        appPassword = ""
        kindleAddress = setup.kindleAddress.value
    }
}

enum DeliveryField: String, Hashable, Sendable {
    case senderAddress
    case smtpHost
    case smtpPort
    case username
    case appPassword
    case kindleAddress
}

enum DeliveryValidationError: Error, Equatable, Sendable {
    case required(DeliveryField)
    case invalidEmail
    case invalidHost
    case invalidPort
    case invalidUsername
    case kindleDomainRequired
}

struct DeliveryValidationResult: Sendable {
    let normalizedDraft: DeliverySetupDraft
    let fieldErrors: [DeliveryField: DeliveryValidationError]

    var isValid: Bool { fieldErrors.isEmpty }
}
