import Foundation

actor PipelineActor: BatchPipelining {
    private var batch = CurrentBatch(
        id: UUID(),
        items: [],
        phase: .editing
    )
    private var attempts: [UUID: DeliveryAttempt] = [:]
    private var eventContinuation: AsyncStream<PipelineEvent>.Continuation?
    private var activeTask: Task<Void, Never>?

    private let intakeService: BookIntakeService
    private let epubPreparer: any EPUBPreparing
    private let pdfPreparer: any PDFEligibilityChecking
    private let deliveryService: BookDeliveryService
    private let workspaceStore: any WorkspaceStoring
    private let historyService: SendHistoryService

    nonisolated let events: AsyncStream<PipelineEvent>

    init(
        intakeService: BookIntakeService,
        epubPreparer: any EPUBPreparing,
        pdfPreparer: any PDFEligibilityChecking,
        deliveryService: BookDeliveryService,
        workspaceStore: any WorkspaceStoring,
        historyService: SendHistoryService
    ) {
        self.intakeService = intakeService
        self.epubPreparer = epubPreparer
        self.pdfPreparer = pdfPreparer
        self.deliveryService = deliveryService
        self.workspaceStore = workspaceStore
        self.historyService = historyService

        var continuation: AsyncStream<PipelineEvent>.Continuation?
        events = AsyncStream { continuation = $0 }
        eventContinuation = continuation
    }

    func snapshot() -> CurrentBatch {
        batch
    }

    func deliveryAttempts() -> [DeliveryAttempt] {
        attempts.values.sorted { $0.startedAt < $1.startedAt }
    }

    func add(_ urls: [URL]) {
        guard !urls.isEmpty,
              activeTask == nil,
              batch.phase.permitsEditing,
              batch.activeSnapshot == nil
        else {
            return
        }
        batch.phase = .importing
        emit(.batchChanged)
        activeTask = Task { [weak self] in
            await self?.runIntake(urls)
        }
    }

    func remove(_ itemID: UUID) async {
        guard activeTask == nil,
              batch.phase.permitsEditing,
              batch.activeSnapshot == nil
        else {
            return
        }
        guard let item = batch.items.first(where: { $0.id == itemID }) else {
            return
        }
        batch.items.removeAll { $0.id == itemID }
        if let staged = item.stagedSource {
            await workspaceStore.cleanup(
                WorkspaceReference(
                    batchID: batch.id,
                    itemID: item.id,
                    rootURL: staged.url.deletingLastPathComponent()
                )
            )
        }
        reconcileEditingPhase()
        emit(.batchChanged)
    }

    func clear() async {
        guard activeTask == nil,
              (
                  batch.phase.permitsEditing
                      || batch.phase == .completed
              ),
              batch.activeSnapshot == nil
        else {
            return
        }
        let oldBatchID = batch.id
        guard await workspaceStore.clearBatch(oldBatchID) else {
            return
        }
        batch = CurrentBatch(id: UUID(), items: [], phase: .editing)
        attempts.removeAll()
        emit(.batchChanged)
    }

    func confirmation(
        setup: ValidatedDeliverySetup,
        kind: ConfirmedBatchKind = .initial
    ) -> ConfirmedBatchSummary? {
        guard activeTask == nil,
              !batch.phase.hasConfirmedSend
        else {
            return nil
        }

        let selected: [BatchItem]
        switch kind {
        case .initial:
            selected = batch.items.filter {
                guard $0.preparation == .ready else { return false }
                if case .notScheduled = $0.delivery { return true }
                return false
            }
        case .retryFailed:
            selected = batch.items.filter {
                if case .failed = $0.delivery { return true }
                return false
            }
        }

        let eligible = selected.compactMap { item -> ConfirmedBatchItem? in
            guard let prepared = item.preparedBook else { return nil }
            let priorFailure: SanitizedFailure?
            if case .failed(let failure) = item.delivery {
                priorFailure = failure
            } else {
                priorFailure = nil
            }
            return ConfirmedBatchItem(
                id: item.id,
                displayName: item.displayName,
                preparedFile: prepared.file,
                format: prepared.format,
                byteCount: prepared.byteCount,
                contentDigest: prepared.contentDigest,
                priorDefinitiveFailure: priorFailure
            )
        }
        guard !eligible.isEmpty, eligible.count == selected.count else {
            return nil
        }
        let selectedIDs = Set(selected.map(\.id))
        let snapshot = ConfirmedBatchSnapshot(
            id: UUID(),
            setup: setup,
            eligibleItems: eligible,
            excludedItemIDs: batch.items
                .filter { !selectedIDs.contains($0.id) }
                .map(\.id),
            confirmedAt: Date(),
            kind: kind
        )
        batch.activeSnapshot = snapshot
        batch.completedCount = 0
        batch.phase = .readyForConfirmation
        emit(.batchChanged)
        return ConfirmedBatchSummary(
            id: snapshot.id,
            destination: snapshot.setup.kindleAddress.value,
            eligibleCount: snapshot.eligibleItems.count,
            excludedCount: snapshot.excludedItemIDs.count,
            kind: snapshot.kind
        )
    }

    func releaseConfirmation(_ snapshotID: UUID) {
        guard activeTask == nil,
              batch.activeSnapshot?.id == snapshotID,
              batch.phase == .readyForConfirmation
        else {
            return
        }
        batch.activeSnapshot = nil
        reconcileEditingPhase()
        emit(.batchChanged)
    }

    func send(snapshotID: UUID) {
        guard activeTask == nil,
              batch.phase == .readyForConfirmation,
              let snapshot = batch.activeSnapshot,
              snapshot.id == snapshotID
        else {
            return
        }
        batch.phase = .sending
        emit(.batchChanged)
        activeTask = Task { [weak self] in
            await self?.runDelivery(snapshot)
        }
    }

    func cancel() async {
        guard let activeTask,
              batch.phase == .importing
                || batch.phase == .preparing
                || batch.phase == .sending
        else {
            return
        }
        batch.phase = .cancelling
        emit(.batchChanged)
        activeTask.cancel()
        await deliveryService.cancelActiveAttempt()
        await activeTask.value
    }

    func canEditSetup() -> Bool {
        !batch.phase.hasConfirmedSend && batch.activeSnapshot == nil
    }

    private func runIntake(_ urls: [URL]) async {
        let outcomes = await intakeService.intake(
            urls,
            batchID: batch.id,
            existing: batch.items
        )
        for outcome in outcomes {
            batch.items.append(outcome.item)
            emit(.intakeOutcome(outcome.item.id))
            emit(.batchChanged)

            guard case .accepted(let item) = outcome else { continue }
            if Task.isCancelled {
                updatePreparation(item.id, to: .cancelled)
                continue
            }
            await prepare(item)
        }
        if Task.isCancelled {
            markPendingPreparationCancelled()
        }
        reconcileEditingPhase()
        activeTask = nil
        emit(.batchChanged)
    }

    private func prepare(_ item: BatchItem) async {
        guard let format = item.format,
              let source = item.stagedSource
        else {
            updatePreparation(
                item.id,
                to: .needsAttention(
                    failure(
                        .pipelineMissingStagedSource,
                        family: .filesystem
                    )
                )
            )
            return
        }

        batch.phase = .preparing
        updatePreparation(item.id, to: .preparing)
        emit(.preparing(item.id))
        emit(.batchChanged)

        let result: PreparationResult
        switch format {
        case .pdf:
            result = await pdfPreparer.prepare(
                itemID: item.id,
                source: source,
                displayName: item.displayName
            )
        case .epub:
            result = await epubPreparer.prepare(
                source: source,
                workspace: WorkspaceReference(
                    batchID: batch.id,
                    itemID: item.id,
                    rootURL: source.url.deletingLastPathComponent()
                ),
                displayName: item.displayName
            )
        }

        guard let index = batch.items.firstIndex(where: { $0.id == item.id })
        else {
            return
        }
        batch.items[index].findings = result.originalReport?.findings ?? []
        batch.items[index].appliedActions = result.appliedActions
        batch.items[index].preparedBook = result.preparedBook
        if let preparedBook = result.preparedBook {
            batch.items[index].health = .healthy
            batch.items[index].preparation = .ready
            emit(.ready(item.id))
            _ = preparedBook
        } else if let failure = result.failure {
            if failure.code == .repairCancelled
                || failure.code == .pdfCancelled
                || failure.code == .xmlCancelled {
                batch.items[index].preparation = .cancelled
                emit(.cancelled(item.id))
            } else {
                batch.items[index].health = result.originalReport?.health
                batch.items[index].preparation = .needsAttention(failure)
                emit(.needsAttention(item.id, failure))
            }
        } else {
            let failure = failure(
                .pipelinePreparationResult,
                family: .filesystem
            )
            batch.items[index].preparation = .needsAttention(failure)
            emit(.needsAttention(item.id, failure))
        }
        emit(.batchChanged)
    }

    private func runDelivery(_ snapshot: ConfirmedBatchSnapshot) async {
        var completed = 0
        for (offset, confirmedItem) in snapshot.eligibleItems.enumerated() {
            if Task.isCancelled {
                markPendingDeliveryCancelled(
                    snapshot.eligibleItems.dropFirst(offset)
                )
                break
            }
            guard let index = batch.items.firstIndex(where: {
                $0.id == confirmedItem.id
            }) else {
                completed += 1
                continue
            }

            let attemptID = UUID()
            attempts[attemptID] = DeliveryAttempt(
                id: attemptID,
                snapshotID: snapshot.id,
                itemID: confirmedItem.id,
                setupRevision: snapshot.setup.revision,
                stage: .connecting,
                dataTransmissionStarted: false,
                startedAt: Date(),
                completedAt: nil,
                outcome: nil
            )
            batch.items[index].delivery = .sending(.connecting)
            emit(
                .sending(
                    confirmedItem.id,
                    DeliveryProgress(
                        stage: .connecting,
                        dataTransmissionStarted: false
                    )
                )
            )
            emit(.batchChanged)

            let outcome = await deliveryService.deliver(
                confirmedItem,
                in: snapshot
            ) { [weak self] progress in
                await self?.apply(
                    progress,
                    itemID: confirmedItem.id,
                    attemptID: attemptID
                )
            }
            await apply(
                outcome,
                itemID: confirmedItem.id,
                attemptID: attemptID
            )
            completed += 1
            batch.completedCount = completed
            emit(
                .batchProgress(
                    completed: completed,
                    total: snapshot.eligibleItems.count
                )
            )
            emit(.batchChanged)
        }

        if batch.phase == .cancelling {
            markPendingDeliveryCancelled(
                snapshot.eligibleItems.dropFirst(completed)
            )
        }
        batch.activeSnapshot = nil
        batch.phase = .completed
        activeTask = nil
        emit(.batchCompleted(batch.id))
        emit(.batchChanged)
    }

    private func apply(
        _ progress: DeliveryProgress,
        itemID: UUID,
        attemptID: UUID
    ) {
        guard let index = batch.items.firstIndex(where: { $0.id == itemID }),
              var attempt = attempts[attemptID],
              attempt.outcome == nil
        else {
            return
        }
        attempt.stage = progress.stage
        attempt.dataTransmissionStarted =
            attempt.dataTransmissionStarted || progress.dataTransmissionStarted
        attempts[attemptID] = attempt
        batch.items[index].delivery = .sending(progress.stage)
        emit(.sending(itemID, progress))
        emit(.batchChanged)
    }

    private func apply(
        _ outcome: TerminalOutcome,
        itemID: UUID,
        attemptID: UUID
    ) async {
        guard let index = batch.items.firstIndex(where: { $0.id == itemID }),
              var attempt = attempts[attemptID]
        else {
            return
        }
        let completedAt = Date()
        attempt.completedAt = completedAt
        attempt.outcome = outcome
        attempts[attemptID] = attempt
        switch outcome {
        case .submitted:
            batch.items[index].delivery = .submitted
            let receipt = SubmissionReceipt(
                attemptID: attemptID,
                batchID: batch.id,
                snapshotID: attempt.snapshotID,
                itemID: itemID,
                displayName: batch.items[index].displayName,
                acceptedAt: completedAt
            )
            do {
                try await historyService.record(receipt)
                emit(.submitted(receipt))
            } catch let failure as HistoryFailure {
                emit(.historyPersistenceFailed(receipt, failure))
            } catch {
                emit(
                    .historyPersistenceFailed(
                        receipt,
                        HistoryFailure(operation: .record, code: .write)
                    )
                )
            }
        case .failed(let failure):
            batch.items[index].delivery = .failed(failure)
            emit(.failed(itemID, failure))
        case .cancelled:
            batch.items[index].delivery = .cancelled
            emit(.cancelled(itemID))
        case .deliveryUnknown(let failure):
            batch.items[index].delivery = .deliveryUnknown(failure)
            emit(.deliveryUnknown(itemID, failure))
        }
    }

    private func markPendingPreparationCancelled() {
        for index in batch.items.indices {
            switch batch.items[index].preparation {
            case .waiting, .checking, .preparing:
                batch.items[index].preparation = .cancelled
                emit(.cancelled(batch.items[index].id))
            case .ready, .needsAttention, .excluded, .cancelled:
                break
            }
        }
    }

    private func markPendingDeliveryCancelled(
        _ items: ArraySlice<ConfirmedBatchItem>
    ) {
        for item in items {
            guard let index = batch.items.firstIndex(where: {
                $0.id == item.id
            }) else {
                continue
            }
            if case .notScheduled = batch.items[index].delivery {
                batch.items[index].delivery = .cancelled
                emit(.cancelled(item.id))
            }
        }
    }

    private func updatePreparation(
        _ itemID: UUID,
        to state: PreparationState
    ) {
        guard let index = batch.items.firstIndex(where: { $0.id == itemID })
        else {
            return
        }
        batch.items[index].preparation = state
    }

    private func reconcileEditingPhase() {
        if batch.items.contains(where: { $0.preparation == .ready }) {
            batch.phase = .readyForConfirmation
        } else {
            batch.phase = .editing
        }
    }

    private func emit(_ kind: PipelineEvent.Kind) {
        eventContinuation?.yield(
            PipelineEvent(batchID: batch.id, kind: kind)
        )
    }

    private func failure(
        _ code: DiagnosticCode,
        family: FailureFamily = .repair
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: family,
            code: code,
            message: "This book could not be processed safely.",
            recoveryAction: .reviewBook
        )
    }
}
