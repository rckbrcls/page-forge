import Foundation

struct EmailAddress: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) throws {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count <= 254,
              normalized.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
        else { throw DeliveryValidationError.invalidEmail }
        self.value = normalized
    }
}

struct SMTPHost: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) throws {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let labels = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard normalized.count <= 253,
              labels.count >= 2,
              labels.allSatisfy({ !$0.isEmpty && $0.count <= 63 }),
              normalized.range(of: #"^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$"#, options: .regularExpression) != nil
        else { throw DeliveryValidationError.invalidHost }
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

struct DeliverySetupDraft: Equatable, Sendable {
    var senderAddress = ""
    var smtpHost = ""
    var smtpPort = "465"
    var securityMode = SecurityMode.implicitTLS
    var username = ""
    var appPassword = ""
    var kindleAddress = ""
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
