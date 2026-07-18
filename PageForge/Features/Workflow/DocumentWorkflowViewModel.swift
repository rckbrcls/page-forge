import AppKit
import Foundation

protocol WorkflowMetadataServicing {
    func inspect(source: URL) throws -> BookMetadata
    func update(source: URL, title: String?, author: String?) throws -> BookMetadata
}

protocol WorkflowRepairing {
    func repair(
        source: URL,
        mode: RepairMode,
        output: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> RepairResult
}

extension MetadataService: WorkflowMetadataServicing {}
extension RepairService: WorkflowRepairing {}

@MainActor
final class DocumentWorkflowViewModel: ObservableObject {
    @Published private(set) var queue: DocumentQueue
    @Published var selectedProfileName = "default"
    @Published private(set) var deliveryProfileNames: [String] = []
    @Published var statusMessage: String?
    @Published var isSending = false
    @Published var isSaving = false
    @Published var inspectedMetadata: BookMetadata?
    @Published var metadataTitle = ""
    @Published var metadataAuthor = ""

    private let intakeService: DocumentIntakeService
    private var preparer: (any DocumentPreparing)?
    private var exporter: any PreparedOutputExporting
    private var delivery: (any DocumentDelivering)?
    private var metadataService: (any WorkflowMetadataServicing)?
    private var repairService: (any WorkflowRepairing)?
    private weak var appState: AppState?
    private var preparationTask: Task<Void, Never>?
    private var deliveryTask: Task<Void, Never>?

    init(
        intakeService: DocumentIntakeService = DocumentIntakeService(),
        preparer: (any DocumentPreparing)? = nil,
        exporter: any PreparedOutputExporting = PreparedOutputExporter(),
        delivery: (any DocumentDelivering)? = nil,
        metadataService: (any WorkflowMetadataServicing)? = nil,
        repairService: (any WorkflowRepairing)? = nil,
        initialQueue: DocumentQueue = DocumentQueue()
    ) {
        self.queue = initialQueue
        self.intakeService = intakeService
        self.preparer = preparer
        self.exporter = exporter
        self.delivery = delivery
        self.metadataService = metadataService
        self.repairService = repairService
    }

    func bind(appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState
        if preparer == nil {
            preparer = DocumentPreparationService(
                readinessService: appState.readinessService,
                conversionService: appState.conversionService
            )
        }
        if delivery == nil {
            delivery = appState.deliveryService
        }
        if metadataService == nil {
            metadataService = appState.metadataService
        }
        if repairService == nil {
            repairService = appState.repairService
        }
        refreshDeliveryProfiles()
    }

    func refreshDeliveryProfiles() {
        guard let config = try? appState?.configService.load() else { return }
        deliveryProfileNames = config.profiles.keys.sorted()
        if !deliveryProfileNames.contains(selectedProfileName) {
            selectedProfileName = config.defaultProfile
        }
    }

    func addFiles(_ urls: [URL]) {
        let scopedAccess = urls.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStartAccess) in zip(urls, scopedAccess) where didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let identities = Set(queue.items.map(\.canonicalIdentity))
        let summary = intakeService.intake(urls: urls, existingIdentities: identities)
        queue.items.append(contentsOf: summary.outcomes.compactMap(\.acceptedItem))
        queue.intakeSummary = summary
        statusMessage = "Added \(summary.acceptedCount) file(s); rejected \(summary.rejectedCount)."
    }

    func setSelected(_ id: UUID, selected: Bool) {
        mutateItem(id) { $0.isSelected = selected }
    }

    func selectAll(_ selected: Bool) {
        for index in queue.items.indices {
            queue.items[index].isSelected = selected
        }
    }

    func removeSelected() {
        guard !queue.isProcessing else { return }
        queue.items.removeAll(\.isSelected)
    }

    func remove(_ id: UUID) {
        guard !queue.isProcessing else { return }
        queue.items.removeAll { $0.id == id }
    }

    func retry(_ id: UUID) {
        mutateItem(id) { _ = $0.resetForRetry() }
    }

    func prepareSelected(overwrite: Bool = false) {
        guard let preparer, let appState, queue.canPrepare else { return }
        let ids = queue.selectedPreparationEligibleItems.map(\.id)
        queue.isProcessing = true
        statusMessage = "Preparing \(ids.count) file(s)"

        preparationTask = Task.detached { [weak self] in
            for id in ids {
                if Task.isCancelled {
                    await self?.cancelQueuedItem(id)
                    continue
                }
                guard let snapshot = await self?.item(id) else { continue }
                let jobID = await appState.jobCoordinator.enqueue(
                    kind: .readinessPrepare,
                    sources: [snapshot.sourceURL],
                    message: "Queued \(snapshot.displayName)"
                )
                await appState.jobCoordinator.start(id: jobID, message: "Preparing \(snapshot.displayName)")
                await self?.beginItem(id)

                do {
                    let result = try preparer.prepare(
                        source: snapshot.sourceURL,
                        format: snapshot.format,
                        overwrite: overwrite
                    ) { progress in
                        Task { @MainActor in
                            self?.updateProgress(id, progress: progress, jobID: jobID)
                        }
                    }
                    await self?.completeItem(id, result: result)
                    await appState.jobCoordinator.succeed(
                        id: jobID,
                        resultRef: result.preparedOutput?.outputURL.path,
                        message: "Prepared \(snapshot.displayName)"
                    )
                } catch {
                    await self?.failItem(id, error: error)
                    await appState.jobCoordinator.fail(id: jobID, message: error.localizedDescription)
                }
            }
            await self?.finishPreparation()
        }
    }

    func cancelPendingPreparation() {
        preparationTask?.cancel()
        for index in queue.items.indices where queue.items[index].preparationState == .queued {
            _ = queue.items[index].cancelIfQueued()
        }
        statusMessage = "Pending preparation cancelled. The active operation may finish."
    }

    func saveSelected(to directory: URL, replacingExisting: Bool = false) {
        let items = queue.selectedReadyItems
        guard !items.isEmpty else { return }
        let outputs = items.compactMap(\.preparedOutput)
        let exporter = exporter
        isSaving = true
        Task.detached { [weak self] in
            let results = exporter.export(
                outputs: outputs,
                destinationDirectory: directory,
                conflictPolicy: replacingExisting ? .replaceConfirmed : .failIfExists
            )
            await MainActor.run {
                guard let self else { return }
                for result in results {
                    guard let item = self.queue.items.first(where: {
                        $0.preparedOutput?.outputURL.standardizedFileURL == result.sourceOutputURL.standardizedFileURL
                    }) else { continue }
                    self.mutateItem(item.id) { $0.saveResult = result }
                }
                self.isSaving = false
                let successes = results.filter { $0.state == .succeeded }.count
                self.statusMessage = "Saved \(successes) of \(results.count) file(s)."
            }
        }
    }

    func sendSelected() {
        guard let delivery else { return }
        let items = queue.selectedReadyItems
        guard let first = items.first, let firstOutput = first.preparedOutput else { return }
        do {
            _ = try delivery.validateForSend(source: firstOutput.outputURL, profileName: selectedProfileName)
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        let profile = selectedProfileName
        isSending = true
        deliveryTask = Task.detached { [weak self] in
            for item in items {
                guard !Task.isCancelled else { break }
                guard let output = item.preparedOutput else { continue }
                let result: DocumentDeliveryResult
                do {
                    let sent = try delivery.send(source: output.outputURL, profileName: profile)
                    result = DocumentDeliveryResult(
                        outputURL: output.outputURL,
                        profileName: sent.profileName,
                        kindleEmail: sent.kindleEmail,
                        state: .succeeded,
                        message: "Sent to \(sent.kindleEmail)"
                    )
                } catch {
                    result = DocumentDeliveryResult(
                        outputURL: output.outputURL,
                        profileName: profile,
                        kindleEmail: nil,
                        state: .failed,
                        message: error.localizedDescription
                    )
                }
                await MainActor.run { self?.mutateItem(item.id) { $0.deliveryResult = result } }
            }
            await MainActor.run {
                self?.isSending = false
                self?.deliveryTask = nil
                self?.statusMessage = "Send operation finished."
            }
        }
    }

    func cancelPendingDelivery() {
        deliveryTask?.cancel()
        statusMessage = "Pending delivery cancelled. The active send may finish."
    }

    var shouldOfferSettingsRecovery: Bool {
        queue.items.contains { $0.issue?.recoveryAction == .openSettings }
            || statusMessage?.localizedCaseInsensitiveContains("settings") == true
    }

    func revealOutput(_ id: UUID) {
        guard let url = queue.items.first(where: { $0.id == id })?.preparedOutput?.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func inspectMetadata(_ id: UUID) {
        guard canInspectMetadata(id),
              let metadataService,
              let source = queue.items.first(where: { $0.id == id })?.sourceURL
        else {
            return
        }
        do {
            let metadata = try metadataService.inspect(source: source)
            inspectedMetadata = metadata
            metadataTitle = metadata.fields["Title"] ?? ""
            metadataAuthor = metadata.fields["Author(s)"] ?? metadata.fields["Authors"] ?? ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func saveMetadata() {
        guard let metadataService, let metadata = inspectedMetadata else { return }
        do {
            inspectedMetadata = try metadataService.update(
                source: metadata.path,
                title: metadataTitle,
                author: metadataAuthor
            )
            statusMessage = "Metadata updated"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func canInspectMetadata(_ id: UUID) -> Bool {
        queue.items.contains { $0.id == id && $0.isSelected }
    }

    func canAggressivelyRepair(_ id: UUID) -> Bool {
        queue.items.contains {
            $0.id == id
                && $0.isSelected
                && $0.format == .epub
                && [.needsAttention, .failed].contains($0.preparationState)
        }
    }

    func aggressiveRepair(_ id: UUID) {
        aggressiveRepair(id, confirmed: true)
    }

    func aggressiveRepair(_ id: UUID, confirmed: Bool) {
        guard confirmed,
              canAggressivelyRepair(id),
              let repairService,
              let item = queue.items.first(where: { $0.id == id })
        else {
            return
        }
        let source = item.sourceURL
        Task.detached { [weak self] in
            do {
                _ = try repairService.repair(
                    source: source,
                    mode: .aggressive,
                    output: nil,
                    overwrite: false,
                    onProgress: nil
                )
                await MainActor.run { self?.statusMessage = "Aggressive repair completed for \(item.displayName)" }
            } catch {
                await MainActor.run { self?.statusMessage = error.localizedDescription }
            }
        }
    }

    private func item(_ id: UUID) -> DocumentItem? {
        queue.items.first(where: { $0.id == id })
    }

    private func mutateItem(_ id: UUID, _ mutation: (inout DocumentItem) -> Void) {
        guard let index = queue.items.firstIndex(where: { $0.id == id }) else { return }
        mutation(&queue.items[index])
    }

    private func beginItem(_ id: UUID) {
        queue.activeItemID = id
        mutateItem(id) { $0.beginPreparation(message: "Validating document") }
    }

    private func updateProgress(_ id: UUID, progress: PreparationProgress, jobID: UUID) {
        mutateItem(id) {
            $0.progressMessage = progress.message
            $0.progressFraction = progress.fraction
        }
        appState?.jobCoordinator.update(id: jobID, message: progress.message, percent: progress.fraction)
    }

    private func completeItem(_ id: UUID, result: DocumentPreparationResult) {
        mutateItem(id) { $0.reconcilePreparation(report: result.report, output: result.preparedOutput) }
    }

    private func failItem(_ id: UUID, error: Error) {
        mutateItem(id) { $0.failPreparation(with: issue(for: error)) }
    }

    private func cancelQueuedItem(_ id: UUID) {
        mutateItem(id) { _ = $0.cancelIfQueued() }
    }

    private func finishPreparation() {
        queue.isProcessing = false
        queue.activeItemID = nil
        preparationTask = nil
        statusMessage = "Preparation finished: \(queue.completedCount) ready, \(queue.failedCount) failed."
    }

    private func issue(for error: Error) -> OperationIssue {
        let message = error.localizedDescription
        if let domain = error as? DomainError {
            switch domain {
            case .dependency:
                return OperationIssue(category: .dependency, message: message, recoveryAction: .openSettings)
            case .filesystem:
                return OperationIssue(category: .filesystem, message: message, recoveryAction: .retry)
            case .conversion:
                return OperationIssue(category: .conversion, message: message, recoveryAction: .retry)
            case .repair:
                return OperationIssue(category: .repair, message: message, recoveryAction: .retry)
            case .configuration:
                return OperationIssue(category: .configuration, message: message, recoveryAction: .openSettings)
            case .delivery:
                return OperationIssue(category: .delivery, message: message, recoveryAction: .retry)
            case .validation:
                return OperationIssue(category: .validation, message: message, recoveryAction: .retry)
            case .cancelled:
                return OperationIssue(category: .cancelled, message: message)
            }
        }
        return OperationIssue(category: .validation, message: message, recoveryAction: .retry)
    }
}
