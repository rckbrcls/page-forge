import Foundation
@testable import BookSender

actor MutableTestClock {
    private(set) var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

actor InMemoryCredentialStore: CredentialStoring {
    private var secrets: [String: String] = [:]
    private(set) var savedReferences: [CredentialReference] = []
    private(set) var deletedReferences: [CredentialReference] = []
    var saveFailure: SanitizedFailure?
    var readFailure: SanitizedFailure?

    func save(
        secret: String,
        service: String,
        account: String,
        revision: Int
    ) throws -> CredentialReference {
        if let saveFailure { throw saveFailure }
        let reference = CredentialReference(
            service: service,
            account: account,
            revision: revision
        )
        secrets[key(reference)] = secret
        savedReferences.append(reference)
        return reference
    }

    func read(_ reference: CredentialReference) throws -> String {
        if let readFailure { throw readFailure }
        guard let value = secrets[key(reference)] else {
            throw sanitizedFailure("credential.missing")
        }
        return value
    }

    func exists(_ reference: CredentialReference) -> Bool {
        secrets[key(reference)] != nil
    }

    func delete(_ reference: CredentialReference) {
        secrets.removeValue(forKey: key(reference))
        deletedReferences.append(reference)
    }

    func insert(_ secret: String, for reference: CredentialReference) {
        secrets[key(reference)] = secret
    }

    func setSaveFailure(_ failure: SanitizedFailure?) {
        saveFailure = failure
    }

    func setReadFailure(_ failure: SanitizedFailure?) {
        readFailure = failure
    }

    private func key(_ reference: CredentialReference) -> String {
        "\(reference.service)|\(reference.account)"
    }
}

actor InMemoryPreferencesStore: DeliveryPreferencesStoring {
    var result: DeliveryPreferencesLoadResult = .absent
    var saveFailure: SanitizedFailure?
    private(set) var savedSetups: [DeliverySetup] = []

    func load() -> DeliveryPreferencesLoadResult {
        result
    }

    func save(_ setup: DeliverySetup) throws {
        if let saveFailure { throw saveFailure }
        savedSetups.append(setup)
        result = .value(setup)
    }

    func clear() {
        result = .absent
    }

    func setResult(_ result: DeliveryPreferencesLoadResult) {
        self.result = result
    }

    func setSaveFailure(_ failure: SanitizedFailure?) {
        saveFailure = failure
    }
}

actor StubSMTPTransport: SMTPDelivering {
    var outcomes: [TerminalOutcome]
    var stages: [DeliveryProgress]
    private(set) var sentItemIDs: [UUID] = []
    private(set) var cancellationCount = 0

    init(
        outcomes: [TerminalOutcome],
        stages: [DeliveryProgress] = [
            DeliveryProgress(
                stage: .connecting,
                dataTransmissionStarted: false
            ),
            DeliveryProgress(
                stage: .transmitting,
                dataTransmissionStarted: true
            ),
            DeliveryProgress(
                stage: .awaitingAcceptance,
                dataTransmissionStarted: true
            ),
        ]
    ) {
        self.outcomes = outcomes
        self.stages = stages
    }

    func send(
        book: PreparedBook,
        setup: DeliverySetup,
        credential: String,
        progress: @escaping @Sendable (DeliveryProgress) async -> Void
    ) async -> TerminalOutcome {
        sentItemIDs.append(book.batchItemID)
        for stage in stages {
            if Task.isCancelled {
                return stage.dataTransmissionStarted
                    ? .deliveryUnknown
                    : .cancelled
            }
            await progress(stage)
        }
        return outcomes.isEmpty
            ? .failed(sanitizedFailure("smtp.no-outcome"))
            : outcomes.removeFirst()
    }

    func cancelActiveAttempt() {
        cancellationCount += 1
    }
}

actor StubArchive: EPUBArchiveReading {
    let descriptors: [ArchiveEntryDescriptor]
    let contents: [String: Data]
    let preflightFailure: SanitizedFailure?

    init(
        descriptors: [ArchiveEntryDescriptor],
        contents: [String: Data],
        preflightFailure: SanitizedFailure? = nil
    ) {
        self.descriptors = descriptors
        self.contents = contents
        self.preflightFailure = preflightFailure
    }

    func preflight(
        _ file: StagedFileReference,
        limits: SafetyLimits
    ) throws -> [ArchiveEntryDescriptor] {
        if let preflightFailure { throw preflightFailure }
        return descriptors
    }

    func data(for path: String, maximumBytes: Int) throws -> Data {
        guard let data = contents[path], data.count <= maximumBytes else {
            throw sanitizedFailure("archive.entry-unavailable", family: .archive)
        }
        return data
    }
}

struct FailingArchiveWriter: EPUBArchiveWriting {
    let failure: SanitizedFailure

    func write(
        source: StagedFileReference,
        plan: PreparationPlan,
        workspace: WorkspaceReference,
        limits: SafetyLimits
    ) async throws -> StagedFileReference {
        throw failure
    }
}

func sanitizedFailure(
    _ code: String,
    family: FailureFamily = .delivery
) -> SanitizedFailure {
    SanitizedFailure(
        family: family,
        code: code,
        message: "The operation could not continue.",
        recoveryAction: .retryFailed
    )
}

func makeSafetyLimits(
    maximumBatchItems: Int? = nil,
    maximumBookBytes: Int64? = nil,
    maximumArchiveEntries: Int? = nil,
    maximumCompressedBytes: Int64? = nil,
    maximumExpandedBytes: Int64? = nil,
    maximumEntryBytes: Int64? = nil,
    maximumExpansionRatio: Double? = nil,
    maximumXMLBytes: Int? = nil,
    maximumXMLDepth: Int? = nil,
    maximumXMLElements: Int? = nil,
    maximumXMLAttributesPerElement: Int? = nil,
    maximumXMLTextBytes: Int? = nil,
    maximumSMTPLineBytes: Int? = nil,
    maximumSMTPReplyLines: Int? = nil,
    maximumAttachmentBytes: Int64? = nil,
    operationTimeout: Duration? = nil,
    smtpStageTimeout: Duration? = nil,
    orphanAge: Duration? = nil
) -> SafetyLimits {
    let base = SafetyLimits.standard
    return SafetyLimits(
        version: base.version,
        maximumBatchItems: maximumBatchItems ?? base.maximumBatchItems,
        maximumBookBytes: maximumBookBytes ?? base.maximumBookBytes,
        maximumArchiveEntries: maximumArchiveEntries ?? base.maximumArchiveEntries,
        maximumCompressedBytes: maximumCompressedBytes ?? base.maximumCompressedBytes,
        maximumExpandedBytes: maximumExpandedBytes ?? base.maximumExpandedBytes,
        maximumEntryBytes: maximumEntryBytes ?? base.maximumEntryBytes,
        maximumExpansionRatio: maximumExpansionRatio ?? base.maximumExpansionRatio,
        maximumXMLBytes: maximumXMLBytes ?? base.maximumXMLBytes,
        maximumXMLDepth: maximumXMLDepth ?? base.maximumXMLDepth,
        maximumXMLElements: maximumXMLElements ?? base.maximumXMLElements,
        maximumXMLAttributesPerElement:
            maximumXMLAttributesPerElement
            ?? base.maximumXMLAttributesPerElement,
        maximumXMLTextBytes: maximumXMLTextBytes ?? base.maximumXMLTextBytes,
        maximumSMTPLineBytes: maximumSMTPLineBytes ?? base.maximumSMTPLineBytes,
        maximumSMTPReplyLines: maximumSMTPReplyLines ?? base.maximumSMTPReplyLines,
        maximumAttachmentBytes: maximumAttachmentBytes ?? base.maximumAttachmentBytes,
        operationTimeout: operationTimeout ?? base.operationTimeout,
        smtpStageTimeout: smtpStageTimeout ?? base.smtpStageTimeout,
        orphanAge: orphanAge ?? base.orphanAge
    )
}

struct TestDependencyGraph {
    let dependencies: AppDependencies
    let credentials: InMemoryCredentialStore
    let preferences: InMemoryPreferencesStore
    let transport: StubSMTPTransport

    static func make(
        stores: TestStores,
        outcomes: [TerminalOutcome] = [.submitted]
    ) -> TestDependencyGraph {
        let workspace = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let credentials = InMemoryCredentialStore()
        let preferences = InMemoryPreferencesStore()
        let setupService = DeliverySetupService(
            credentials: credentials,
            preferences: preferences,
            serviceName: stores.keychainServiceName
        )
        let transport = StubSMTPTransport(outcomes: outcomes)
        let delivery = BookDeliveryService(
            credentials: credentials,
            transport: transport
        )
        let pipeline = PipelineActor(
            intakeService: BookIntakeService(workspaceStore: workspace),
            epubPreparer: EPUBRepairEngine(
                writer: EPUBArchiveWriter(),
                workspaceStore: workspace
            ),
            pdfPreparer: PDFEligibilityService(workspaceStore: workspace),
            deliveryService: delivery,
            workspaceStore: workspace
        )
        return TestDependencyGraph(
            dependencies: AppDependencies(
                workspaceStore: workspace,
                setupService: setupService,
                pipeline: pipeline,
                shortcutDefaults: stores.defaults,
                bootstrapMode: .production,
                bootstrapFixtureURLs: []
            ),
            credentials: credentials,
            preferences: preferences,
            transport: transport
        )
    }
}
