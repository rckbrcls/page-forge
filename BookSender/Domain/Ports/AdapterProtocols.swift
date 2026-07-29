import Foundation

struct ArchiveEntryDescriptor: Sendable {
    let path: String
    let compressedSize: Int64
    let uncompressedSize: Int64
    let compressionMethod: UInt16
    let isDirectory: Bool
}

protocol EPUBArchiveReading: Sendable {
    func preflight(_ file: StagedFileReference, limits: SafetyLimits) async throws -> [ArchiveEntryDescriptor]
    func data(for path: String, maximumBytes: Int) async throws -> Data
}

protocol EPUBArchiveWriting: Sendable {
    func write(source: StagedFileReference, plan: PreparationPlan, workspace: WorkspaceReference) async throws -> StagedFileReference
}

protocol BoundedXMLParsing: Sendable {
    func parse(_ data: Data, limits: SafetyLimits) async throws -> XMLDocumentProjection
}

struct XMLDocumentProjection: Sendable {
    let rootName: String
    let namespaces: [String: String]
    let elements: [XMLElementProjection]
}

struct XMLElementProjection: Sendable {
    let name: String
    let attributes: [String: String]
    let text: String
}

struct WorkspaceReference: Hashable, Sendable {
    let batchID: UUID
    let itemID: UUID
    let rootURL: URL
}

protocol WorkspaceStoring: Sendable {
    func createWorkspace(batchID: UUID, itemID: UUID) async throws -> WorkspaceReference
    func stageReadOnlySource(_ source: URL, in workspace: WorkspaceReference) async throws -> StagedFileReference
    func promotePartial(_ relativePath: String, to finalPath: String, in workspace: WorkspaceReference) async throws -> StagedFileReference
    func cleanup(_ workspace: WorkspaceReference) async
}

protocol CredentialStoring: Sendable {
    func save(secret: String, service: String, account: String) async throws -> CredentialReference
    func read(_ reference: CredentialReference) async throws -> String
    func delete(_ reference: CredentialReference) async throws
}

protocol DeliveryPreferencesStoring: Sendable {
    func load() async -> DeliverySetup?
    func save(_ setup: DeliverySetup) async throws
    func clear() async
}

struct SMTPEnvelope: Sendable {
    let sender: EmailAddress
    let recipient: EmailAddress
}

protocol SMTPDelivering: Sendable {
    func send(book: PreparedBook, setup: DeliverySetup, credential: String) async -> TerminalOutcome
    func cancelActiveAttempt() async
}
