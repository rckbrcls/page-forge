import Foundation

enum DocumentFormat: String, Codable, CaseIterable, Sendable {
    case epub
    case mobi
    case pdf
}

enum PreparationState: String, Codable, CaseIterable, Sendable {
    case queued
    case preparing
    case ready
    case needsAttention
    case blocked
    case failed
    case cancelled
}

enum OutputActionState: String, Codable, CaseIterable, Sendable {
    case idle
    case inProgress
    case succeeded
    case failed
}

enum QueueState: String, Codable, CaseIterable, Sendable {
    case empty
    case readyToPrepare
    case processing
    case partiallyCompleted
    case completed
}

enum IntakeRejectionReason: String, Codable, CaseIterable, Sendable {
    case unsupportedType
    case duplicate
    case notLocalFile
    case notRegularFile
    case unreadable
    case missing
    case accessDenied
    case resolutionFailed
}

enum OutputConflictPolicy: String, Codable, CaseIterable, Sendable {
    case failIfExists
    case replaceConfirmed
}

enum IssueCategory: String, Codable, CaseIterable, Sendable {
    case intake
    case dependency
    case validation
    case filesystem
    case conversion
    case repair
    case configuration
    case delivery
    case cancelled
}

enum RecoveryAction: String, Codable, CaseIterable, Sendable {
    case retry
    case openSettings
    case chooseAnotherFolder
    case revealFile
}

struct SecurityScopedAccess: Equatable, Sendable {
    var bookmarkData: Data?
    var isAccessActive: Bool

    init(bookmarkData: Data? = nil, isAccessActive: Bool = false) {
        self.bookmarkData = bookmarkData
        self.isAccessActive = isAccessActive
    }
}

struct OperationIssue: Equatable, Sendable {
    var category: IssueCategory
    var message: String
    var recoveryAction: RecoveryAction?

    init(
        category: IssueCategory,
        message: String,
        recoveryAction: RecoveryAction? = nil
    ) {
        self.category = category
        self.message = message
        self.recoveryAction = recoveryAction
    }
}

struct PreparedOutput: Equatable, Sendable {
    var sourceURL: URL
    var outputURL: URL
    var format: DocumentFormat
    var sizeBytes: Int64
    var readinessStatus: ReadinessStatus
    var createdAt: Date

    init(
        sourceURL: URL,
        outputURL: URL,
        format: DocumentFormat = .epub,
        sizeBytes: Int64,
        readinessStatus: ReadinessStatus,
        createdAt: Date = Date()
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.format = format
        self.sizeBytes = sizeBytes
        self.readinessStatus = readinessStatus
        self.createdAt = createdAt
    }
}

struct ExportRequest: Equatable, Sendable {
    var outputs: [PreparedOutput]
    var destinationDirectory: URL
    var conflictPolicy: OutputConflictPolicy

    init(
        outputs: [PreparedOutput],
        destinationDirectory: URL,
        conflictPolicy: OutputConflictPolicy = .failIfExists
    ) {
        self.outputs = outputs
        self.destinationDirectory = destinationDirectory
        self.conflictPolicy = conflictPolicy
    }
}

struct ExportResult: Equatable, Sendable {
    var sourceOutputURL: URL
    var destinationURL: URL
    var state: OutputActionState
    var message: String
}

struct DeliveryRequest: Equatable, Sendable {
    var outputs: [PreparedOutput]
    var profileName: String
}

struct DocumentDeliveryResult: Equatable, Sendable {
    var outputURL: URL
    var profileName: String
    var kindleEmail: String?
    var state: OutputActionState
    var message: String
}

struct DocumentItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var sourceURL: URL
    var canonicalIdentity: String
    var displayName: String
    var format: DocumentFormat
    var isSelected: Bool
    var preparationState: PreparationState
    var progressMessage: String?
    var progressFraction: Double? {
        didSet {
            progressFraction = progressFraction.map { min(max($0, 0), 1) }
        }
    }
    var readinessReport: ReadinessReport?
    var preparedOutput: PreparedOutput?
    var issue: OperationIssue?
    var saveResult: ExportResult?
    var deliveryResult: DocumentDeliveryResult?
    var securityAccess: SecurityScopedAccess?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        canonicalIdentity: String,
        displayName: String? = nil,
        format: DocumentFormat,
        isSelected: Bool = true,
        preparationState: PreparationState = .queued,
        progressMessage: String? = nil,
        progressFraction: Double? = nil,
        readinessReport: ReadinessReport? = nil,
        preparedOutput: PreparedOutput? = nil,
        issue: OperationIssue? = nil,
        saveResult: ExportResult? = nil,
        deliveryResult: DocumentDeliveryResult? = nil,
        securityAccess: SecurityScopedAccess? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.canonicalIdentity = canonicalIdentity
        self.displayName = displayName ?? sourceURL.lastPathComponent
        self.format = format
        self.isSelected = isSelected
        self.preparationState = preparationState
        self.progressMessage = progressMessage
        self.progressFraction = progressFraction.map { min(max($0, 0), 1) }
        self.readinessReport = readinessReport
        self.preparedOutput = preparedOutput
        self.issue = issue
        self.saveResult = saveResult
        self.deliveryResult = deliveryResult
        self.securityAccess = securityAccess
    }

    var saveState: OutputActionState {
        saveResult?.state ?? .idle
    }

    var deliveryState: OutputActionState {
        deliveryResult?.state ?? .idle
    }

    var isPreparationEligible: Bool {
        switch preparationState {
        case .queued, .needsAttention, .blocked, .failed, .cancelled:
            return true
        case .preparing, .ready:
            return false
        }
    }

    var isOutputEligible: Bool {
        guard isSelected,
              preparationState == .ready,
              let preparedOutput
        else {
            return false
        }

        return FileManager.default.isReadableFile(atPath: preparedOutput.outputURL.path)
    }

    mutating func beginPreparation(message: String? = nil) {
        preparationState = .preparing
        progressMessage = message
        progressFraction = nil
        issue = nil
    }

    mutating func reconcilePreparation(
        report: ReadinessReport,
        output: PreparedOutput?
    ) {
        readinessReport = report
        progressMessage = nil
        progressFraction = 1

        switch report.status {
        case .ready:
            guard let output,
                  FileManager.default.isReadableFile(atPath: output.outputURL.path)
            else {
                preparedOutput = nil
                preparationState = .failed
                issue = OperationIssue(
                    category: .filesystem,
                    message: "The prepared output is missing or unreadable.",
                    recoveryAction: .retry
                )
                return
            }
            preparedOutput = output
            preparationState = .ready
            issue = nil
        case .needsFixes:
            preparedOutput = output
            preparationState = .needsAttention
        case .blocked:
            preparedOutput = nil
            preparationState = .blocked
        }
    }

    mutating func failPreparation(with issue: OperationIssue) {
        preparationState = .failed
        progressMessage = nil
        progressFraction = nil
        self.issue = issue
    }

    @discardableResult
    mutating func resetForRetry() -> Bool {
        guard [.needsAttention, .blocked, .failed, .cancelled].contains(preparationState) else {
            return false
        }

        preparationState = .queued
        progressMessage = nil
        progressFraction = nil
        readinessReport = nil
        preparedOutput = nil
        issue = nil
        return true
    }

    @discardableResult
    mutating func cancelIfQueued() -> Bool {
        guard preparationState == .queued else { return false }
        preparationState = .cancelled
        issue = OperationIssue(category: .cancelled, message: "Preparation was cancelled.")
        return true
    }
}

struct IntakeRejection: Equatable, Sendable {
    var reason: IntakeRejectionReason
    var message: String
}

struct IntakeOutcome: Equatable, Sendable {
    let originalURL: URL
    let acceptedItem: DocumentItem?
    let rejection: IntakeRejection?
    let inputIndex: Int

    init(originalURL: URL, acceptedItem: DocumentItem, inputIndex: Int) {
        self.originalURL = originalURL
        self.acceptedItem = acceptedItem
        self.rejection = nil
        self.inputIndex = inputIndex
    }

    init(originalURL: URL, rejection: IntakeRejection, inputIndex: Int) {
        self.originalURL = originalURL
        self.acceptedItem = nil
        self.rejection = rejection
        self.inputIndex = inputIndex
    }
}

struct IntakeSummary: Equatable, Sendable {
    var outcomes: [IntakeOutcome]

    init(outcomes: [IntakeOutcome]) {
        self.outcomes = outcomes.sorted { $0.inputIndex < $1.inputIndex }
    }

    var acceptedCount: Int {
        outcomes.filter { $0.acceptedItem != nil }.count
    }

    var rejectedCount: Int {
        outcomes.filter { $0.rejection != nil }.count
    }
}

struct DocumentQueue: Equatable, Sendable {
    var items: [DocumentItem]
    var isProcessing: Bool
    var activeItemID: UUID?
    var intakeSummary: IntakeSummary?

    init(
        items: [DocumentItem] = [],
        isProcessing: Bool = false,
        activeItemID: UUID? = nil,
        intakeSummary: IntakeSummary? = nil
    ) {
        self.items = items
        self.isProcessing = isProcessing
        self.activeItemID = activeItemID
        self.intakeSummary = intakeSummary
    }

    var selectedItems: [DocumentItem] {
        items.filter(\.isSelected)
    }

    var selectedQueuedItems: [DocumentItem] {
        selectedItems.filter { $0.preparationState == .queued }
    }

    var selectedPreparationEligibleItems: [DocumentItem] {
        selectedItems.filter(\.isPreparationEligible)
    }

    var selectedReadyItems: [DocumentItem] {
        selectedItems.filter(\.isOutputEligible)
    }

    var state: QueueState {
        guard !items.isEmpty else { return .empty }
        if isProcessing || items.contains(where: { $0.preparationState == .preparing }) {
            return .processing
        }
        if items.contains(where: { $0.preparationState == .queued }) {
            return .readyToPrepare
        }

        let readyCount = items.filter { $0.preparationState == .ready }.count
        return readyCount > 0 && readyCount < items.count ? .partiallyCompleted : .completed
    }

    var completedCount: Int {
        items.filter { $0.preparationState == .ready }.count
    }

    var failedCount: Int {
        items.filter { $0.preparationState == .failed }.count
    }

    var attentionCount: Int {
        items.filter { $0.preparationState == .needsAttention }.count
    }

    var blockedCount: Int {
        items.filter { $0.preparationState == .blocked }.count
    }

    var canPrepare: Bool {
        !isProcessing && !selectedPreparationEligibleItems.isEmpty
    }

    var canSaveFiles: Bool {
        !selectedReadyItems.isEmpty
    }

    var canSendToKindle: Bool {
        !selectedReadyItems.isEmpty
    }

    var canRemove: Bool {
        !selectedItems.isEmpty && !isProcessing
    }

    var canRetry: Bool {
        selectedItems.contains {
            [.needsAttention, .blocked, .failed, .cancelled].contains($0.preparationState)
        }
    }
}
