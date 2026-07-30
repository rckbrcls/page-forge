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
    private(set) var hasResolvedInitialSetup = false
    var settingsTab: SettingsTab = .delivery
    var sendBookTab: SendBookTab = .default
    var setupDraft = DeliverySetupDraft()
    var setup: DeliverySetup?
    var setupErrors: [DeliveryField: DeliveryValidationError] = [:]
    var isSavingSetup = false
    var setupMessage: String?
    private(set) var feedbackByScope: [FeedbackScope: ActionFeedback] = [:]
    private(set) var currentDiagnosticEvent: DiagnosticEvent?
    private(set) var diagnosticEventsByOperation: [UUID: DiagnosticEvent] = [:]
    private(set) var currentCopyFeedback: ActionFeedback?
    var batch = BatchPresentation.empty
    var isShowingConfirmation = false
    var isShowingResetConfirmation = false
    var isShowingClearHistoryConfirmation = false
    private(set) var isClearingHistory = false
    private(set) var historySnapshot = SendHistorySnapshot.empty
    private(set) var historyLoadState = SendHistoryLoadState.idle
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
    private let historyService: SendHistoryService
    private let setupService: DeliverySetupService
    private let validator = DeliverySetupValidator()
    private let feedbackService = ActionFeedbackService()
    private let failurePresentationService = FailurePresentationService()
    private let diagnosticService: DiagnosticService
    private let diagnosticFormatter: DiagnosticFormatter
    private let diagnosticClipboard: any DiagnosticClipboard
    private let feedbackSleep: FeedbackSleep
    private var setupMutationVersion = 0
    @ObservationIgnored
    private var replacedTerminalFeedbackByScope:
        [FeedbackScope: ActionFeedback] = [:]
    @ObservationIgnored
    private var feedbackExpiryTasks:
        [FeedbackScope: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var copyFeedbackExpiryTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    init(dependencies: AppDependencies = .forCurrentInvocation()) {
        self.dependencies = dependencies
        pipeline = dependencies.pipeline
        historyService = dependencies.historyService
        setupService = dependencies.setupService
        diagnosticService = dependencies.diagnosticService
        diagnosticFormatter = dependencies.diagnosticFormatter
        diagnosticClipboard = dependencies.diagnosticClipboard
        feedbackSleep = dependencies.feedbackSleep

        let opening = feedbackService.acknowledged(
            scope: .application,
            action: .restoreApplication,
            title: "Opening Book Sender…"
        )
        feedbackByScope[.application] = feedbackService.inProgress(
            from: opening,
            title: "Opening Book Sender…"
        )

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
        feedbackExpiryTasks.values.forEach { $0.cancel() }
        copyFeedbackExpiryTask?.cancel()
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

    var canStartAnotherSend: Bool {
        batch.canStartAnotherSend && !isSending
    }

    var latestFeedback: ActionFeedback? {
        feedbackByScope.values.max { lhs, rhs in
            lhs.updatedAt < rhs.updatedAt
        }
    }

    func feedback(for scope: FeedbackScope) -> ActionFeedback? {
        feedbackByScope[scope]
    }

    func diagnosticEvent(for operationID: UUID) -> DiagnosticEvent? {
        diagnosticEventsByOperation[operationID]
    }

    func loadSetup() async {
        let version = setupMutationVersion
        let result = await setupService.load()
        guard version == setupMutationVersion else { return }
        apply(result)
    }

    func saveSetup() {
        guard canSaveSetup else { return }
        let lifecycle = beginFeedback(
            scope: .deliverySetup,
            action: .saveDeliverySetup,
            title: "Saving delivery setup…"
        )
        setupMessage = nil
        let keepsExistingCredential = setup != nil && setupDraft.appPassword.isEmpty
        let validation = validator.validate(
            setupDraft,
            requiresPassword: !keepsExistingCredential
        )
        setupErrors = validation.fieldErrors
        guard validation.isValid else {
            let failure = SanitizedFailure(
                family: .credential,
                code: .deliverySetupValidation,
                message: "Review the highlighted delivery setup fields.",
                recoveryAction: .editSetup,
                evidence: DiagnosticEvidence(
                    phase: .inputValidation,
                    retryDisposition: .editSetup
                )
            )
            finishFeedback(
                lifecycle,
                state: .failed,
                title: "Delivery setup needs attention.",
                message: failure.message,
                failure: failure
            )
            return
        }

        isSavingSetup = true
        setupMutationVersion += 1
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
                finishFeedback(
                    lifecycle,
                    state: .succeeded,
                    title: "Setup saved. App password stored securely."
                )
            } catch let validationError as DeliveryValidationError {
                setupErrors = [
                    field(for: validationError) ?? .appPassword: validationError,
                ]
                let failure = SanitizedFailure(
                    family: .credential,
                    code: .deliverySetupValidation,
                    message: "Review the highlighted delivery setup fields.",
                    recoveryAction: .editSetup,
                    evidence: DiagnosticEvidence(
                        phase: .inputValidation,
                        retryDisposition: .editSetup
                    )
                )
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "Delivery setup needs attention.",
                    message: failure.message,
                    failure: failure
                )
            } catch let failure as SanitizedFailure {
                setupMessage = failure.message
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "Delivery setup was not saved.",
                    message: failure.message,
                    failure: failure
                )
            } catch {
                let failure = SanitizedFailure(
                    family: .credential,
                    code: .unexpectedCredential,
                    message: "Delivery setup could not be saved.",
                    recoveryAction: .editSetup,
                    evidence: DiagnosticEvidence(
                        phase: .credentialWrite,
                        retryDisposition: .editSetup
                    )
                )
                setupMessage = failure.message
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "Delivery setup was not saved.",
                    message: failure.message,
                    failure: failure
                )
            }
        }
    }

    func deleteSetup() {
        guard canSaveSetup, let existing = setup else { return }
        isSavingSetup = true
        setupMutationVersion += 1
        let lifecycle = beginFeedback(
            scope: .deliverySetup,
            action: .deleteDeliverySetup,
            title: "Deleting delivery setup…"
        )
        Task {
            let clearFailure = await setupService.clear(existing)
            setup = nil
            setupDraft = DeliverySetupDraft()
            setupErrors = [:]
            setupMessage = nil
            route = .deliverySetup
            isSavingSetup = false
            if let clearFailure {
                finishFeedback(
                    lifecycle,
                    state: .partial,
                    title: "Delivery setup removed with a Keychain warning.",
                    message: "Review the stored app password in Keychain.",
                    failure: clearFailure
                )
            } else {
                finishFeedback(
                    lifecycle,
                    state: .succeeded,
                    title: "Delivery setup deleted."
                )
            }
        }
    }

    func addBooks(_ urls: [URL]) {
        guard !urls.isEmpty else {
            let lifecycle = beginFeedback(
                scope: .batch,
                action: .addBooks,
                title: "Checking dropped items…"
            )
            finishFeedback(
                lifecycle,
                state: .failed,
                title: "No supported books were added.",
                failure: SanitizedFailure(
                    family: .intake,
                    code: .intakeUnsupported,
                    message: "Choose an EPUB or PDF book.",
                    recoveryAction: .chooseAnotherFile
                )
            )
            return
        }
        _ = beginFeedback(
            scope: .batch,
            action: .addBooks,
            title: urls.count == 1 ? "Adding book…" : "Adding books…"
        )
        Task {
            await pipeline.add(urls)
        }
    }

    func ensureHistoryLoaded() {
        guard historyLoadState == .idle else { return }
        loadHistory()
    }

    func retryHistoryLoad() {
        loadHistory()
    }

    func requestClearHistory() {
        guard !historySnapshot.records.isEmpty, !isClearingHistory else {
            return
        }
        isShowingClearHistoryConfirmation = true
    }

    func cancelClearHistory() {
        isShowingClearHistoryConfirmation = false
    }

    func confirmClearHistory() {
        guard isShowingClearHistoryConfirmation, !isClearingHistory else {
            return
        }
        isShowingClearHistoryConfirmation = false
        isClearingHistory = true
        let lifecycle = beginFeedback(
            scope: .history,
            action: .clearHistory,
            title: "Clearing send history…"
        )
        Task {
            defer { isClearingHistory = false }
            do {
                try await historyService.clear()
                historySnapshot = try await historyService.snapshot()
                historyLoadState = .loaded
                finishFeedback(
                    lifecycle,
                    state: .succeeded,
                    title: "Send history cleared."
                )
            } catch {
                let historyFailure = normalizedHistoryFailure(
                    error,
                    operation: .clear
                )
                historyLoadState = .loaded
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "Send history was not cleared.",
                    failure: sanitizedHistoryFailure(historyFailure)
                )
            }
        }
    }

    func handleFileImporterFailure() {
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .addBooks,
            title: "Closing file selection…"
        )
        finishFeedback(
            lifecycle,
            state: .cancelled,
            title: "No books were added."
        )
    }

    func copyCurrentErrorDetails() {
        copyErrorDetails(for: currentDiagnosticEvent)
    }

    func copyErrorDetails(for event: DiagnosticEvent?) {
        guard let event else { return }
        let lifecycle = feedbackService.inProgress(
            from: feedbackService.acknowledged(
                scope: .application,
                action: .copyErrorDetails,
                title: "Copying error details…"
            ),
            title: "Copying error details…"
        )
        currentCopyFeedback = lifecycle
        do {
            try diagnosticClipboard.write(diagnosticFormatter.format(event))
            currentCopyFeedback = feedbackService.terminal(
                from: lifecycle,
                state: .succeeded,
                title: "Error details copied."
            )
            scheduleCopyFeedbackExpiry()
        } catch {
            copyFeedbackExpiryTask?.cancel()
            let failure = SanitizedFailure(
                family: .filesystem,
                code: .clipboardWrite,
                message: "The sanitized error details were not copied.",
                recoveryAction: nil,
                evidence: DiagnosticEvidence(
                    phase: .clipboardWrite,
                    retryDisposition: .retrySafe,
                    context: DiagnosticContext(
                        operationID: lifecycle.id
                    )
                )
            )
            currentCopyFeedback = feedbackService.terminal(
                from: lifecycle,
                state: .failed,
                title: "Error details were not copied.",
                message: "The original error remains visible.",
                failure: failurePresentationService.presentation(for: failure)
            )
            recordFailure(
                failure,
                action: .copyErrorDetails,
                outcome: .failed,
                operationID: lifecycle.id,
                retainAsCurrent: false
            )
        }
    }

    func remove(_ itemID: UUID) {
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .removeBook,
            title: "Removing book…"
        )
        Task {
            await pipeline.remove(itemID)
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: "Book removed."
            )
        }
    }

    func clear() {
        let oldBatchID = batch.id
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .clearBatch,
            title: "Clearing batch…"
        )
        Task {
            await pipeline.clear()
            let snapshot = await pipeline.snapshot()
            if snapshot.id == oldBatchID {
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "The batch was not cleared.",
                    failure: batchClearFailure()
                )
            } else {
                batch = BatchPresentation(snapshot)
                aggregateMessage = nil
                finishFeedback(
                    lifecycle,
                    state: .succeeded,
                    title: "Batch cleared."
                )
            }
        }
    }

    func requestStartAnotherSend() {
        guard canStartAnotherSend else { return }
        if hasDeliveryUnknown {
            isShowingResetConfirmation = true
        } else {
            startAnotherSend()
        }
    }

    func cancelStartAnotherSend() {
        isShowingResetConfirmation = false
    }

    func confirmStartAnotherSend() {
        guard isShowingResetConfirmation else { return }
        isShowingResetConfirmation = false
        startAnotherSend()
    }

    func cancel() {
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .cancelOperation,
            title: "Cancelling operation…"
        )
        Task {
            await pipeline.cancel()
            let snapshot = await pipeline.snapshot()
            batch = BatchPresentation(snapshot)
            finishFeedback(
                lifecycle,
                state: hasDeliveryUnknown ? .unknown : .cancelled,
                title: hasDeliveryUnknown
                    ? "Cancellation left a delivery result unknown."
                    : "Operation cancelled.",
                message: hasDeliveryUnknown
                    ? "Check Kindle before retrying."
                    : nil,
                failure: hasDeliveryUnknown
                    ? .deliveryUnknown()
                    : nil
            )
        }
    }

    func requestSendConfirmation() {
        pendingConfirmationKind = .initial
        guard let setup, eligibleCount > 0, !isSending else { return }
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .confirmBatch,
            title: "Preparing confirmation…"
        )
        Task {
            guard let summary = await pipeline.confirmation(
                setup: setup,
                kind: .initial
            ) else {
                finishFeedback(
                    lifecycle,
                    state: .cancelled,
                    title: "Confirmation is no longer available.",
                    message: "Review the current batch before trying again."
                )
                return
            }
            confirmation = summary
            batch = BatchPresentation(await pipeline.snapshot())
            isShowingConfirmation = true
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: "Confirmation ready."
            )
        }
    }

    func requestRetryConfirmation() {
        pendingConfirmationKind = .retryFailed
        guard let setup, failedCount > 0, !isSending else { return }
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .confirmBatch,
            title: "Preparing retry confirmation…"
        )
        Task {
            guard let summary = await pipeline.confirmation(
                setup: setup,
                kind: .retryFailed
            ) else {
                finishFeedback(
                    lifecycle,
                    state: .cancelled,
                    title: "Retry confirmation is no longer available.",
                    message: "Review the failed items before trying again."
                )
                return
            }
            confirmation = summary
            batch = BatchPresentation(await pipeline.snapshot())
            isShowingConfirmation = true
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: "Retry confirmation ready."
            )
        }
    }

    func dismissConfirmation() {
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .dismissConfirmation,
            title: "Dismissing confirmation…"
        )
        let snapshotID = confirmation?.id
        isShowingConfirmation = false
        confirmation = nil
        pendingConfirmationKind = .initial
        if let snapshotID {
            Task {
                await pipeline.releaseConfirmation(snapshotID)
                finishFeedback(
                    lifecycle,
                    state: .succeeded,
                    title: "Confirmation dismissed."
                )
            }
        } else {
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: "Confirmation dismissed."
            )
        }
    }

    func confirmSend() {
        guard let snapshotID = confirmation?.id else { return }
        _ = beginFeedback(
            scope: .batch,
            action: .sendBatch,
            title: pendingConfirmationKind == .retryFailed
                ? "Retrying failed books…"
                : "Sending books…"
        )
        isShowingConfirmation = false
        confirmation = nil
        pendingConfirmationKind = .initial
        Task {
            await pipeline.send(snapshotID: snapshotID)
        }
    }

    func reconcileRouteForShortcut() async {
        await loadSetup()
        let lifecycle = beginFeedback(
            scope: .application,
            action: .restoreApplication,
            title: "Opening Book Sender…"
        )
        finishFeedback(
            lifecycle,
            state: .succeeded,
            title: "Book Sender opened."
        )
    }

    func updateShortcutPreference(_ preference: ShortcutPreference) {
        shortcutPreference = preference
    }

    func publishShortcutFeedback(
        action: FeedbackAction,
        state: FeedbackState,
        title: String,
        failure: SanitizedFailure? = nil
    ) {
        let lifecycle = beginFeedback(
            scope: .shortcut,
            action: action,
            title: state == .inProgress ? title : "Updating shortcut…"
        )
        guard state.isTerminal else { return }
        finishFeedback(
            lifecycle,
            state: state,
            title: title,
            message: failure?.message,
            failure: failure
        )
    }

    func acknowledgeUpdateCheck() {
        let lifecycle = beginFeedback(
            scope: .update,
            action: .checkForUpdates,
            title: "Opening update check…"
        )
        finishFeedback(
            lifecycle,
            state: .succeeded,
            title: "Update check opened."
        )
    }

    private func bootstrapAndLoad() async {
        let slowInitialSetupLoad: Bool
        let shouldResetHistory: Bool
        let shouldSeedHistory: Bool
        switch dependencies.bootstrapMode {
        case .production:
            slowInitialSetupLoad = false
            shouldResetHistory = false
            shouldSeedHistory = false
        case .uiTesting(
            let reset,
            let configured,
            let shouldLoadSlowly,
            let resetHistory,
            let seedHistory,
            _
        ):
            slowInitialSetupLoad = shouldLoadSlowly
            shouldResetHistory = resetHistory
            shouldSeedHistory = seedHistory
            let existingResult = await setupService.load()
            if reset {
                let existing: DeliverySetup?
                if case .complete(let setup) = existingResult {
                    existing = setup
                } else {
                    existing = nil
                }
                _ = await setupService.clear(existing)
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
        if shouldResetHistory {
            try? await historyService.clear()
        }
        if shouldSeedHistory {
            await seedUITestHistory()
        }
        await dependencies.workspaceStore.sweepOrphans(
            olderThan: Date().addingTimeInterval(-86_400)
        )
        if slowInitialSetupLoad {
            try? await Task.sleep(for: .seconds(1))
        }
        await loadSetup()
        await loadHistoryNow()
        hasResolvedInitialSetup = true
        if feedbackByScope[.application]?.state == .inProgress {
            let lifecycle = feedbackByScope[.application]!
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: "Book Sender ready."
            )
        }
        if setup != nil, !dependencies.bootstrapFixtureURLs.isEmpty {
            _ = beginFeedback(
                scope: .batch,
                action: .addBooks,
                title: dependencies.bootstrapFixtureURLs.count == 1
                    ? "Adding book…"
                    : "Adding books…"
            )
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
            finishApplicationRestoration(
                state: .succeeded,
                title: "Saved delivery setup restored."
            )
        case .incomplete(let draft, let failure):
            setup = nil
            setupDraft = draft
            setupMessage = failure?.message
            route = .deliverySetup
            if let failure {
                let lifecycle = beginFeedback(
                    scope: .deliverySetup,
                    action: .restoreApplication,
                    title: "Restoring delivery setup…"
                )
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "Delivery setup needs attention.",
                    message: failure.message,
                    failure: failure
                )
                finishApplicationRestoration(
                    state: .succeeded,
                    title: "Book Sender opened with setup required."
                )
            } else {
                finishApplicationRestoration(
                    state: .succeeded,
                    title: "Delivery setup required."
                )
            }
        }
    }

    func project(
        _ event: PipelineEvent,
        snapshot: CurrentBatch
    ) {
        guard event.batchID == snapshot.id else {
            return
        }
        batch = BatchPresentation(snapshot)
        switch event.kind {
        case .batchProgress(let completed, let total):
            aggregateMessage = "\(completed) of \(total) finished"
            updateProgressFeedback(
                scope: .batch,
                title: "Sending books…",
                message: "\(completed) of \(total) finished."
            )
        case .batchCompleted:
            let submitted = items.filter {
                if case .submitted = $0.delivery { return true }
                return false
            }.count
            aggregateMessage = "\(submitted) submitted"
            completeBatchFeedback()
        case .deliveryUnknown(let itemID, let failure):
            aggregateMessage = "Review delivery status before trying again."
            recordFailure(
                failure,
                action: .sendBook,
                outcome: .uncertain,
                operationID: itemID
            )
        case .checking, .preparing:
            updateProgressFeedback(
                scope: .batch,
                title: "Preparing books…"
            )
        case .needsAttention(let itemID, let failure):
            recordFailure(
                failure,
                action: .prepareBook,
                outcome: .failed,
                operationID: itemID
            )
            completeIntakeFeedbackIfSettled()
        case .intakeOutcome(let itemID):
            if let failure = intakeFailure(for: itemID) {
                recordFailure(
                    failure,
                    action: .addBooks,
                    outcome: .failed,
                    operationID: itemID
                )
            }
            completeIntakeFeedbackIfSettled()
        case .ready:
            completeIntakeFeedbackIfSettled()
        case .sending(_, let progress):
            updateProgressFeedback(
                scope: .batch,
                title: "Sending books…",
                message: deliveryStageMessage(progress.stage)
            )
        case .batchChanged:
            completeIntakeFeedbackIfSettled()
        case .failed(let itemID, let failure):
            recordFailure(
                failure,
                action: .sendBook,
                outcome: .failed,
                operationID: itemID
            )
        case .submitted:
            Task {
                await refreshHistoryAfterSubmission()
            }
        case .historyPersistenceFailed(let receipt, let historyFailure):
            let failure = sanitizedHistoryFailure(historyFailure)
            let lifecycle = beginFeedback(
                scope: .history,
                action: .recordHistory,
                title: "Recording submission…"
            )
            finishFeedback(
                lifecycle,
                state: .partial,
                title: "Book sent, but history was not updated.",
                failure: failure,
                recordDiagnostic: false
            )
            recordFailure(
                failure,
                action: .recordHistory,
                outcome: .failed,
                operationID: receipt.attemptID
            )
        case .cancelled:
            break
        }
    }

    private func loadHistory() {
        guard historyLoadState != .loading else { return }
        Task {
            await loadHistoryNow()
        }
    }

    private func loadHistoryNow() async {
        guard historyLoadState != .loading else { return }
        historyLoadState = .loading
        let lifecycle = beginFeedback(
            scope: .history,
            action: .loadHistory,
            title: "Loading send history…"
        )
        do {
            historySnapshot = try await historyService.snapshot()
            historyLoadState = .loaded
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: "Send history ready."
            )
        } catch {
            let historyFailure = normalizedHistoryFailure(
                error,
                operation: .load
            )
            historyLoadState = .unavailable(historyFailure)
            finishFeedback(
                lifecycle,
                state: .failed,
                title: "Send history is unavailable.",
                failure: sanitizedHistoryFailure(historyFailure)
            )
        }
    }

    private func refreshHistoryAfterSubmission() async {
        do {
            historySnapshot = try await historyService.snapshot()
            historyLoadState = .loaded
        } catch {
            let historyFailure = normalizedHistoryFailure(
                error,
                operation: .load
            )
            historyLoadState = .unavailable(historyFailure)
            let lifecycle = beginFeedback(
                scope: .history,
                action: .loadHistory,
                title: "Refreshing send history…"
            )
            finishFeedback(
                lifecycle,
                state: .failed,
                title: "Send history is unavailable.",
                failure: sanitizedHistoryFailure(historyFailure)
            )
        }
    }

    private func seedUITestHistory() async {
        let baseDate = Date(timeIntervalSince1970: 1_752_422_400)
        let receipts = [
            SubmissionReceipt(
                attemptID: UUID(
                    uuidString: "E034C883-C9C9-4A9C-8375-C4F0965E38AD"
                )!,
                batchID: UUID(),
                snapshotID: UUID(),
                itemID: UUID(),
                displayName: "Newest Submission.pdf",
                acceptedAt: baseDate.addingTimeInterval(7_200)
            ),
            SubmissionReceipt(
                attemptID: UUID(
                    uuidString: "F4A61AD2-F6DC-4A1A-981A-0F55908C8611"
                )!,
                batchID: UUID(),
                snapshotID: UUID(),
                itemID: UUID(),
                displayName: "Repeated Title.epub",
                acceptedAt: baseDate.addingTimeInterval(3_600)
            ),
            SubmissionReceipt(
                attemptID: UUID(
                    uuidString: "0B3A21DB-95DF-49D8-A648-985A287D7072"
                )!,
                batchID: UUID(),
                snapshotID: UUID(),
                itemID: UUID(),
                displayName: "Repeated Title.epub",
                acceptedAt: baseDate
            ),
        ]
        for receipt in receipts {
            try? await historyService.record(receipt)
        }
    }

    private func normalizedHistoryFailure(
        _ error: any Error,
        operation: HistoryOperation
    ) -> HistoryFailure {
        if let failure = error as? HistoryFailure {
            return failure
        }
        let code: HistoryFailureCode = switch operation {
        case .load: .read
        case .record: .write
        case .clear: .clear
        }
        return HistoryFailure(operation: operation, code: code)
    }

    private func sanitizedHistoryFailure(
        _ failure: HistoryFailure
    ) -> SanitizedFailure {
        let diagnosticCode: DiagnosticCode = switch failure.operation {
        case .record:
            .historyWrite
        case .clear:
            .historyClear
        case .load:
            switch failure.code {
            case .unavailable: .historyUnavailable
            case .read, .write, .clear: .historyRead
            case .decode: .historyDecode
            case .unsupportedSchema: .historyUnsupportedSchema
            case .limit: .historyLimit
            }
        }
        let recoveryAction: RecoveryAction? = switch failure.operation {
        case .load: .retryHistoryLoad
        case .record: nil
        case .clear: .retryHistoryClear
        }
        let phase: DiagnosticPhase = switch failure.operation {
        case .load: .historyLoad
        case .record: .historyRecord
        case .clear: .historyClear
        }
        return SanitizedFailure(
            family: .filesystem,
            code: diagnosticCode,
            message: "The local send history operation did not complete.",
            recoveryAction: recoveryAction,
            evidence: DiagnosticEvidence(
                phase: phase,
                retryDisposition: recoveryAction == nil
                    ? .notRetryable
                    : .retrySafe
            )
        )
    }

    private func batchClearFailure() -> SanitizedFailure {
        SanitizedFailure(
            family: .filesystem,
            code: .unexpectedFilesystem,
            message: "The current batch remains available.",
            recoveryAction: nil,
            evidence: DiagnosticEvidence(
                phase: .cleanup,
                retryDisposition: .retrySafe
            )
        )
    }

    private func startAnotherSend() {
        guard canStartAnotherSend else { return }
        let oldBatchID = batch.id
        let oldItemIDs = Set(items.map(\.id))
        let lifecycle = beginFeedback(
            scope: .batch,
            action: .startAnotherSend,
            title: "Starting another send…"
        )
        Task {
            await pipeline.clear()
            let snapshot = await pipeline.snapshot()
            guard snapshot.id != oldBatchID,
                  snapshot.items.isEmpty,
                  snapshot.phase == .editing
            else {
                finishFeedback(
                    lifecycle,
                    state: .failed,
                    title: "The completed batch was not cleared.",
                    failure: batchClearFailure()
                )
                return
            }
            batch = BatchPresentation(snapshot)
            aggregateMessage = nil
            confirmation = nil
            isShowingConfirmation = false
            pendingConfirmationKind = .initial
            for scope in Array(feedbackByScope.keys) {
                switch scope {
                case .batch, .batchItem, .delivery:
                    cancelFeedbackExpiry(for: scope)
                    feedbackByScope.removeValue(forKey: scope)
                    replacedTerminalFeedbackByScope.removeValue(
                        forKey: scope
                    )
                case .application, .deliverySetup, .shortcut, .update, .history:
                    break
                }
            }
            for itemID in oldItemIDs {
                diagnosticEventsByOperation.removeValue(forKey: itemID)
            }
            if let operationID =
                currentDiagnosticEvent?.failure.evidence.context.operationID,
               oldItemIDs.contains(operationID) {
                currentDiagnosticEvent = nil
                currentCopyFeedback = nil
                copyFeedbackExpiryTask?.cancel()
            }
            let ready = feedbackService.terminal(
                from: lifecycle,
                state: .succeeded,
                title: "Ready for another send."
            )
            feedbackByScope[.batch] = ready
            scheduleFeedbackExpiry(for: ready)
            if dependencies.shouldReintakeAfterReset,
               !dependencies.bootstrapFixtureURLs.isEmpty {
                await pipeline.add(dependencies.bootstrapFixtureURLs)
            }
        }
    }

    @discardableResult
    private func beginFeedback(
        scope: FeedbackScope,
        action: FeedbackAction,
        title: String,
        message: String? = nil
    ) -> ActionFeedback {
        cancelFeedbackExpiry(for: scope)
        if let current = feedbackByScope[scope], current.state.isTerminal {
            replacedTerminalFeedbackByScope[scope] = current
        } else {
            replacedTerminalFeedbackByScope[scope] = nil
        }
        let acknowledged = feedbackService.acknowledged(
            scope: scope,
            action: action,
            title: title,
            message: message
        )
        let progress = feedbackService.inProgress(
            from: acknowledged,
            title: title,
            message: message
        )
        feedbackByScope[scope] = progress
        return progress
    }

    private func updateProgressFeedback(
        scope: FeedbackScope,
        title: String,
        message: String? = nil
    ) {
        guard let current = feedbackByScope[scope],
              !current.state.isTerminal
        else {
            return
        }
        let proposed = feedbackService.inProgress(
            from: current,
            title: title,
            message: message
        )
        feedbackByScope[scope] = feedbackService.reconcile(
            current: current,
            proposed: proposed
        )
    }

    private func finishFeedback(
        _ lifecycle: ActionFeedback,
        state: FeedbackState,
        title: String,
        message: String? = nil,
        failure: SanitizedFailure? = nil,
        recordDiagnostic: Bool = true
    ) {
        let presentation = failure.map {
            failurePresentationService.presentation(for: $0)
        }
        let replaced = replacedTerminalFeedbackByScope[lifecycle.scope]
        let isRepeatedFailure = replaced?.action == lifecycle.action
            && replaced?.failure?.code == presentation?.code
            && presentation != nil
        let occurrenceCount = isRepeatedFailure
            ? (replaced?.occurrenceCount ?? 0) + 1
            : 1
        let proposed = feedbackService.terminal(
            from: lifecycle,
            state: state,
            title: title,
            message: presentation?.summary ?? message,
            failure: presentation,
            occurrenceCount: occurrenceCount
        )
        replacedTerminalFeedbackByScope[lifecycle.scope] = nil
        if recordDiagnostic,
           let failure,
           (state == .failed || state == .unknown || state == .partial) {
            recordFailure(
                failure,
                action: lifecycle.action,
                outcome: state == .unknown ? .uncertain : .failed,
                operationID: lifecycle.id,
                occurrenceCount: occurrenceCount
            )
        }
        let current = feedbackByScope[lifecycle.scope]
        feedbackByScope[lifecycle.scope] = feedbackService.reconcile(
            current: current,
            proposed: proposed
        )
        if let current = feedbackByScope[lifecycle.scope] {
            scheduleFeedbackExpiry(for: current)
        }
    }

    private func scheduleFeedbackExpiry(
        for feedback: ActionFeedback
    ) {
        cancelFeedbackExpiry(for: feedback.scope)
        guard case .delayed(let duration) = feedback.dismissal else {
            return
        }
        let scope = feedback.scope
        let feedbackID = feedback.id
        let sleep = feedbackSleep
        feedbackExpiryTasks[scope] = Task { [weak self] in
            do {
                try await sleep(duration)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.expireFeedback(scope: scope, feedbackID: feedbackID)
        }
    }

    private func cancelFeedbackExpiry(
        for scope: FeedbackScope
    ) {
        feedbackExpiryTasks.removeValue(forKey: scope)?.cancel()
    }

    private func expireFeedback(
        scope: FeedbackScope,
        feedbackID: UUID
    ) {
        guard let current = feedbackByScope[scope],
              current.id == feedbackID,
              case .delayed = current.dismissal
        else {
            return
        }
        feedbackByScope.removeValue(forKey: scope)
        feedbackExpiryTasks.removeValue(forKey: scope)
    }

    private func scheduleCopyFeedbackExpiry() {
        copyFeedbackExpiryTask?.cancel()
        guard let feedback = currentCopyFeedback,
              case .delayed(let duration) = feedback.dismissal
        else {
            return
        }
        let feedbackID = feedback.id
        let sleep = feedbackSleep
        copyFeedbackExpiryTask = Task { [weak self] in
            do {
                try await sleep(duration)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  self.currentCopyFeedback?.id == feedbackID
            else {
                return
            }
            self.currentCopyFeedback = nil
            self.copyFeedbackExpiryTask = nil
        }
    }

    private func recordFailure(
        _ failure: SanitizedFailure,
        action: FeedbackAction,
        outcome: DiagnosticOutcome,
        operationID: UUID,
        occurrenceCount: Int = 1,
        retainAsCurrent: Bool = true
    ) {
        let existing = failure.evidence.context
        let contextualized = SanitizedFailure(
            family: failure.family,
            code: failure.code,
            message: failure.message,
            recoveryAction: failure.recoveryAction,
            evidence: DiagnosticEvidence(
                phase: failure.evidence.phase,
                severity: failure.evidence.severity,
                retryDisposition: failure.evidence.retryDisposition,
                providerStatus: failure.evidence.providerStatus,
                context: DiagnosticContext(
                    appVersion: existing.appVersion,
                    operationID: existing.operationID ?? operationID,
                    setupRevision: existing.setupRevision ?? setup?.revision,
                    batchTotal: existing.batchTotal
                        ?? (items.isEmpty ? nil : items.count),
                    batchCompleted: existing.batchCompleted
                        ?? (items.isEmpty ? nil : batch.completedCount),
                    transmissionStarted: existing.transmissionStarted,
                    safetyLimit: existing.safetyLimit
                )
            )
        )
        let event = diagnosticService.makeEvent(
            action: action,
            outcome: outcome,
            failure: contextualized,
            occurrenceCount: occurrenceCount
        )
        if retainAsCurrent {
            currentDiagnosticEvent = event
        }
        if let operationID =
            event.failure.evidence.context.operationID {
            diagnosticEventsByOperation[operationID] = event
        }
        Task {
            _ = await diagnosticService.recordOnce(event)
        }
    }

    private func completeIntakeFeedbackIfSettled() {
        guard let lifecycle = feedbackByScope[.batch],
              lifecycle.action == .addBooks,
              !lifecycle.state.isTerminal,
              !isImporting,
              !items.isEmpty,
              items.allSatisfy({ $0.preparation.isTerminal })
        else {
            return
        }
        let ready = items.filter { $0.preparation == .ready }.count
        let blocked = items.count - ready
        if blocked == 0 {
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: ready == 1 ? "1 book ready." : "\(ready) books ready."
            )
        } else if ready == 0 {
            finishFeedback(
                lifecycle,
                state: .failed,
                title: blocked == 1
                    ? "1 book needs attention."
                    : "\(blocked) books need attention.",
                message: "Review the item details.",
                failure: firstPreparationFailure
                    ?? SanitizedFailure(
                        family: .intake,
                        code: .unexpectedIntake,
                        message: "No added book is ready.",
                        recoveryAction: .chooseAnotherFile
                    ),
                recordDiagnostic: false
            )
        } else {
            finishFeedback(
                lifecycle,
                state: .partial,
                title: "Books added with mixed results.",
                message: "\(ready) ready, \(blocked) need attention."
            )
        }
    }

    private func completeBatchFeedback() {
        guard let lifecycle = feedbackByScope[.batch],
              lifecycle.action == .sendBatch,
              !lifecycle.state.isTerminal
        else {
            return
        }
        let submitted = items.filter { $0.delivery == .submitted }.count
        let failed = items.filter {
            if case .failed = $0.delivery { return true }
            return false
        }.count
        let unknown = items.filter {
            if case .deliveryUnknown = $0.delivery { return true }
            return false
        }.count
        let cancelled = items.filter { $0.delivery == .cancelled }.count
        if submitted > 0, failed == 0, unknown == 0, cancelled == 0 {
            finishFeedback(
                lifecycle,
                state: .succeeded,
                title: submitted == 1
                    ? "1 book submitted."
                    : "\(submitted) books submitted."
            )
        } else if unknown > 0, submitted == 0, failed == 0 {
            finishFeedback(
                lifecycle,
                state: .unknown,
                title: "Delivery result unknown.",
                message: "Check Kindle before retrying.",
                failure: firstUnknownFailure ?? .deliveryUnknown(),
                recordDiagnostic: false
            )
        } else if failed > 0, submitted == 0, unknown == 0, cancelled == 0 {
            finishFeedback(
                lifecycle,
                state: .failed,
                title: failed == 1
                    ? "1 book failed to send."
                    : "\(failed) books failed to send.",
                failure: firstFailedDelivery
                    ?? SanitizedFailure(
                        family: .delivery,
                        code: .unexpectedDelivery,
                        message: "The confirmed delivery failed.",
                        recoveryAction: .retryFailed
                    ),
                recordDiagnostic: false
            )
        } else if cancelled > 0, submitted == 0, failed == 0, unknown == 0 {
            finishFeedback(
                lifecycle,
                state: .cancelled,
                title: "Delivery cancelled."
            )
        } else {
            finishFeedback(
                lifecycle,
                state: .partial,
                title: "Delivery finished with mixed results.",
                message: "\(submitted) submitted, \(failed) failed, \(unknown) unknown."
            )
        }
    }

    private var firstPreparationFailure: SanitizedFailure? {
        items.lazy.compactMap {
            switch $0.preparation {
            case .needsAttention(let failure), .excluded(let failure):
                failure
            case .waiting, .checking, .preparing, .ready, .cancelled:
                nil
            }
        }.first
    }

    private func intakeFailure(for itemID: UUID) -> SanitizedFailure? {
        guard let item = items.first(where: { $0.id == itemID }) else {
            return nil
        }
        if case .excluded(let failure) = item.preparation {
            return failure
        }
        return nil
    }

    private var firstUnknownFailure: SanitizedFailure? {
        items.lazy.compactMap {
            guard case .deliveryUnknown(let failure) = $0.delivery else {
                return nil
            }
            return failure
        }.first
    }

    private var firstFailedDelivery: SanitizedFailure? {
        items.lazy.compactMap {
            guard case .failed(let failure) = $0.delivery else {
                return nil
            }
            return failure
        }.first
    }

    private func deliveryStageMessage(_ stage: DeliveryStage) -> String {
        switch stage {
        case .connecting: "Connecting securely."
        case .securing: "Securing the connection."
        case .authenticating: "Authenticating."
        case .envelope: "Addressing the message."
        case .transmitting: "Transmitting the book."
        case .awaitingAcceptance: "Waiting for final acceptance."
        }
    }

    private func finishApplicationRestoration(
        state: FeedbackState,
        title: String
    ) {
        guard let lifecycle = feedbackByScope[.application],
              lifecycle.action == .restoreApplication,
              !lifecycle.state.isTerminal
        else {
            return
        }
        finishFeedback(
            lifecycle,
            state: state,
            title: title
        )
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
