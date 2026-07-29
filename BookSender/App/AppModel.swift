import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Route {
        case deliverySetup
        case sendBook
    }

    enum SettingsTab: Hashable {
        case delivery
        case shortcut
    }

    var route: Route = .deliverySetup
    var settingsTab: SettingsTab = .delivery
    var setupDraft = DeliverySetupDraft()
    var setup: DeliverySetup?
    var setupErrors: [DeliveryField: DeliveryValidationError] = [:]
    var isSavingSetup = false
    var setupMessage: String?
    var batch = BatchPresentation.empty
    var isShowingConfirmation = false
    var pendingConfirmationKind = ConfirmedBatchKind.initial
    var confirmation: ConfirmedBatchSummary?
    var aggregateMessage: String?
    var shortcutPreference = ShortcutPreference(
        isEnabled: true,
        keyCombinationDescription: nil,
        registrationState: .registered
    )

    let windowCoordinator = WindowCoordinator()

    private let dependencies: AppDependencies
    private let pipeline: PipelineActor
    private let setupService: DeliverySetupService
    private let validator = DeliverySetupValidator()
    private var setupMutationVersion = 0
    @ObservationIgnored
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    init(dependencies: AppDependencies = .forCurrentInvocation()) {
        self.dependencies = dependencies
        pipeline = dependencies.pipeline
        setupService = dependencies.setupService

        observationTask = Task { [weak self, pipeline] in
            for await event in pipeline.events {
                guard let self else { return }
                let snapshot = await pipeline.snapshot()
                self.project(event, snapshot: snapshot)
            }
        }
        Task { [weak self] in
            await self?.bootstrapAndLoad()
        }
    }

    deinit {
        observationTask?.cancel()
    }

    var items: [BatchItemPresentation] {
        batch.items
    }

    var isImporting: Bool {
        batch.phase == .importing || batch.phase == .preparing
    }

    var isSending: Bool {
        batch.phase == .sending || batch.phase == .cancelling
    }

    var canCancel: Bool {
        batch.phase == .importing
            || batch.phase == .preparing
            || batch.phase == .sending
    }

    var canEditBatch: Bool {
        batch.phase.permitsEditing
    }

    var canSaveSetup: Bool {
        !isSavingSetup
            && !batch.phase.hasConfirmedSend
            && batch.activeConfirmation == nil
    }

    var eligibleCount: Int {
        if isShowingConfirmation, let confirmation {
            return confirmation.eligibleCount
        }
        switch pendingConfirmationKind {
        case .initial:
            return initialEligibleCount
        case .retryFailed:
            return failedCount
        }
    }

    var initialEligibleCount: Int {
        items.filter {
            guard $0.preparation == .ready else { return false }
            if case .notScheduled = $0.delivery { return true }
            return false
        }.count
    }

    var excludedCount: Int {
        if isShowingConfirmation, let confirmation {
            return confirmation.excludedCount
        }
        return max(0, items.count - eligibleCount)
    }

    var failedCount: Int {
        items.filter {
            if case .failed = $0.delivery { return true }
            return false
        }.count
    }

    var hasDeliveryUnknown: Bool {
        items.contains {
            if case .deliveryUnknown = $0.delivery { return true }
            return false
        }
    }

    func loadSetup() async {
        let version = setupMutationVersion
        let result = await setupService.load()
        guard version == setupMutationVersion else { return }
        apply(result)
    }

    func saveSetup() {
        guard canSaveSetup else { return }
        let keepsExistingCredential = setup != nil && setupDraft.appPassword.isEmpty
        let validation = validator.validate(
            setupDraft,
            requiresPassword: !keepsExistingCredential
        )
        setupErrors = validation.fieldErrors
        guard validation.isValid else { return }

        isSavingSetup = true
        setupMutationVersion += 1
        setupMessage = nil
        let draft = validation.normalizedDraft
        let existing = setup
        Task {
            defer { isSavingSetup = false }
            do {
                let saved = try await setupService.save(
                    draft,
                    replacing: existing
                )
                setup = saved
                setupDraft = DeliverySetupDraft(setup: saved)
                setupErrors = [:]
                setupMessage = nil
                route = .sendBook
            } catch let validationError as DeliveryValidationError {
                setupErrors = [
                    field(for: validationError) ?? .appPassword: validationError,
                ]
            } catch let failure as SanitizedFailure {
                setupMessage = failure.message
            } catch {
                setupMessage = "Delivery setup could not be saved."
            }
        }
    }

    func addBooks(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task {
            await pipeline.add(urls)
        }
    }

    func remove(_ itemID: UUID) {
        Task {
            await pipeline.remove(itemID)
        }
    }

    func clear() {
        Task {
            await pipeline.clear()
            aggregateMessage = nil
        }
    }

    func cancel() {
        Task {
            await pipeline.cancel()
        }
    }

    func requestSendConfirmation() {
        pendingConfirmationKind = .initial
        guard let setup, eligibleCount > 0, !isSending else { return }
        Task {
            guard let summary = await pipeline.confirmation(
                setup: setup,
                kind: .initial
            ) else {
                return
            }
            confirmation = summary
            batch = BatchPresentation(await pipeline.snapshot())
            isShowingConfirmation = true
        }
    }

    func requestRetryConfirmation() {
        pendingConfirmationKind = .retryFailed
        guard let setup, failedCount > 0, !isSending else { return }
        Task {
            guard let summary = await pipeline.confirmation(
                setup: setup,
                kind: .retryFailed
            ) else {
                return
            }
            confirmation = summary
            batch = BatchPresentation(await pipeline.snapshot())
            isShowingConfirmation = true
        }
    }

    func dismissConfirmation() {
        let snapshotID = confirmation?.id
        isShowingConfirmation = false
        confirmation = nil
        pendingConfirmationKind = .initial
        if let snapshotID {
            Task {
                await pipeline.releaseConfirmation(snapshotID)
            }
        }
    }

    func confirmSend() {
        guard let snapshotID = confirmation?.id else { return }
        isShowingConfirmation = false
        confirmation = nil
        pendingConfirmationKind = .initial
        Task {
            await pipeline.send(snapshotID: snapshotID)
        }
    }

    func reconcileRouteForShortcut() async {
        await loadSetup()
    }

    func updateShortcutPreference(_ preference: ShortcutPreference) {
        shortcutPreference = preference
    }

    private func bootstrapAndLoad() async {
        switch dependencies.bootstrapMode {
        case .production:
            break
        case .uiTesting(let reset, let configured):
            let existingResult = await setupService.load()
            if reset {
                let existing: DeliverySetup?
                if case .complete(let setup) = existingResult {
                    existing = setup
                } else {
                    existing = nil
                }
                await setupService.clear(existing)
            }
            if configured {
                let currentResult = await setupService.load()
                if case .complete = currentResult {
                    break
                }
                let draft = DeliverySetupDraft(
                    senderAddress: "ui-test@example.com",
                    smtpHost: "smtp.example.com",
                    smtpPort: "465",
                    securityMode: .implicitTLS,
                    username: "ui-test",
                    appPassword: "ui-test-secret",
                    kindleAddress: "ui-test@kindle.com"
                )
                _ = try? await setupService.save(draft, replacing: nil)
            }
        }
        await dependencies.workspaceStore.sweepOrphans(
            olderThan: Date().addingTimeInterval(-86_400)
        )
        await loadSetup()
        if setup != nil, !dependencies.bootstrapFixtureURLs.isEmpty {
            await pipeline.add(dependencies.bootstrapFixtureURLs)
        }
    }

    private func apply(_ result: SetupLoadResult) {
        switch result {
        case .complete(let loaded):
            setup = loaded
            setupDraft = DeliverySetupDraft(setup: loaded)
            setupMessage = nil
            route = .sendBook
        case .incomplete(let draft, let failure):
            setup = nil
            setupDraft = draft
            setupMessage = failure?.message
            route = .deliverySetup
        }
    }

    private func project(
        _ event: PipelineEvent,
        snapshot: CurrentBatch
    ) {
        batch = BatchPresentation(snapshot)
        switch event {
        case .batchProgress(let completed, let total):
            aggregateMessage = "\(completed) of \(total) finished"
        case .batchCompleted:
            let submitted = items.filter {
                if case .submitted = $0.delivery { return true }
                return false
            }.count
            aggregateMessage = "\(submitted) submitted"
        case .deliveryUnknown:
            aggregateMessage = "Review delivery status before trying again."
        case .batchChanged,
             .intakeOutcome,
             .checking,
             .preparing,
             .ready,
             .needsAttention,
             .sending,
             .submitted,
             .failed,
             .cancelled:
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
