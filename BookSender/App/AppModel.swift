import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Route {
        case deliverySetup
        case sendBook
    }

    var route: Route = .deliverySetup
    var setupDraft = DeliverySetupDraft()
    var setup: DeliverySetup?
    var setupErrors: [DeliveryField: DeliveryValidationError] = [:]
    var isSavingSetup = false
    var setupMessage: String?
    var items: [BatchItem] = []
    var isImporting = false
    var isShowingConfirmation = false
    var isSending = false
    var aggregateMessage: String?

    let windowCoordinator = WindowCoordinator()

    private let workspaceStore: WorkspaceStore
    private let pipeline: PipelineActor
    private let intakeService: BookIntakeService
    private let setupService: DeliverySetupService
    private let credentialStore: KeychainCredentialStore
    @ObservationIgnored
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    init() {
        let workspaceStore = WorkspaceStore()
        let pipeline = PipelineActor()
        let credentials = KeychainCredentialStore()
        let preferences = DeliveryPreferencesStore()
        self.workspaceStore = workspaceStore
        self.pipeline = pipeline
        self.credentialStore = credentials
        intakeService = BookIntakeService(workspaceStore: workspaceStore)
        setupService = DeliverySetupService(credentials: credentials, preferences: preferences)

        observationTask = Task { [weak self] in
            guard let self else { return }
            for await event in pipeline.events {
                self.project(event)
            }
        }
        Task { await loadSetup() }
    }

    deinit {
        observationTask?.cancel()
    }

    func loadSetup() async {
        setup = await setupService.load()
        route = setup == nil ? .deliverySetup : .sendBook
        if let setup {
            setupDraft.senderAddress = setup.senderAddress.value
            setupDraft.smtpHost = setup.smtpHost.value
            setupDraft.smtpPort = String(setup.smtpPort)
            setupDraft.securityMode = setup.securityMode
            setupDraft.username = setup.username
            setupDraft.kindleAddress = setup.kindleAddress.value
            setupDraft.appPassword = ""
        }
    }

    func saveSetup() {
        guard !isSavingSetup else { return }
        isSavingSetup = true
        setupMessage = nil
        let draft = setupDraft
        let existing = setup
        Task {
            do {
                let saved = try await setupService.save(draft, replacing: existing)
                setup = saved
                setupDraft.appPassword = ""
                setupErrors = [:]
                route = .sendBook
            } catch let error as DeliveryValidationError {
                let field = field(for: error)
                setupErrors = field.map { [$0: error] } ?? [:]
            } catch {
                setupMessage = "Delivery setup could not be saved."
            }
            isSavingSetup = false
        }
    }

    func editSetup() {
        route = .deliverySetup
    }

    func cancelSetupEditing() {
        if setup != nil { route = .sendBook }
    }

    func addBooks(_ urls: [URL]) {
        guard !urls.isEmpty, !isImporting else { return }
        isImporting = true
        let existing = Set(items.map(\.sourceIdentity))
        let batchID = Task { await pipeline.snapshot().id }
        Task {
            let id = await batchID.value
            let added = await intakeService.intake(urls, batchID: id, existing: existing)
            await pipeline.append(added)
            items.append(contentsOf: added)
            for item in added where item.format == .epub {
                await prepareEPUB(item, batchID: id)
            }
            isImporting = false
        }
    }

    func remove(_ itemID: UUID) {
        Task {
            await pipeline.remove(itemID)
            items.removeAll { $0.id == itemID }
        }
    }

    func clear() {
        Task {
            await pipeline.clear()
            items = []
            aggregateMessage = nil
        }
    }

    var eligibleCount: Int {
        items.filter { $0.preparation == .ready }.count
    }

    var excludedCount: Int {
        items.count - eligibleCount
    }

    func requestSendConfirmation() {
        guard eligibleCount > 0, setup != nil else { return }
        isShowingConfirmation = true
    }

    func confirmSend() {
        isShowingConfirmation = false
        aggregateMessage = "SMTP delivery is not available until the protocol implementation is validated."
    }

    private func prepareEPUB(_ item: BatchItem, batchID: UUID) async {
        var updated = item
        updated.preparation = .preparing
        replaceLocally(updated)
        await pipeline.replace(updated)
        do {
            let workspace = WorkspaceReference(
                batchID: batchID,
                itemID: item.id,
                rootURL: item.stagedSource.url.deletingLastPathComponent()
            )
            let engine = EPUBRepairEngine(
                writer: EPUBArchiveWriter(),
                workspaceStore: workspaceStore
            )
            let prepared = try await engine.prepare(
                source: item.stagedSource,
                workspace: workspace,
                displayName: item.displayName
            )
            updated.preparedBook = prepared
            updated.preparation = .ready
            updated.health = .healthy
        } catch let failure as SanitizedFailure {
            updated.preparation = .needsAttention(failure)
        } catch {
            updated.preparation = .needsAttention(
                SanitizedFailure(
                    family: .repair,
                    code: "repair.failed",
                    message: "This EPUB could not be prepared safely.",
                    recoveryAction: .reviewBook
                )
            )
        }
        replaceLocally(updated)
        await pipeline.replace(updated)
    }

    private func replaceLocally(_ item: BatchItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    private func project(_ event: PipelineEvent) {
        switch event {
        case .batchProgress(let completed, let total):
            aggregateMessage = "\(completed) of \(total) finished"
        case .batchCompleted:
            isSending = false
            aggregateMessage = "Batch complete"
        default:
            break
        }
    }

    private func field(for error: DeliveryValidationError) -> DeliveryField? {
        switch error {
        case .required(let field): field
        case .invalidEmail: .senderAddress
        case .invalidHost: .smtpHost
        case .invalidPort: .smtpPort
        case .invalidUsername: .username
        case .kindleDomainRequired: .kindleAddress
        }
    }
}
