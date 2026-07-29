import Foundation

actor PipelineActor {
    private var batch = CurrentBatch(id: UUID(), items: [], phase: .editing)
    private var eventContinuation: AsyncStream<PipelineEvent>.Continuation?
    private var activeTask: Task<Void, Never>?

    nonisolated let events: AsyncStream<PipelineEvent>

    init() {
        var continuation: AsyncStream<PipelineEvent>.Continuation?
        events = AsyncStream { continuation = $0 }
        eventContinuation = continuation
    }

    func snapshot() -> CurrentBatch { batch }

    func append(_ items: [BatchItem]) {
        guard batch.phase == .editing || batch.phase == .completed else { return }
        for item in items where !batch.items.contains(where: { $0.sourceIdentity == item.sourceIdentity }) {
            batch.items.append(item)
            eventContinuation?.yield(.itemAdded(item.id))
        }
    }

    func replace(_ item: BatchItem) {
        guard let index = batch.items.firstIndex(where: { $0.id == item.id }) else { return }
        batch.items[index] = item
        switch item.preparation {
        case .ready:
            if let preparedBook = item.preparedBook {
                eventContinuation?.yield(.ready(item.id, preparedBook))
            }
        case .needsAttention(let failure), .excluded(let failure):
            eventContinuation?.yield(.needsAttention(item.id, failure))
        default:
            break
        }
    }

    func remove(_ itemID: UUID) {
        guard batch.phase == .editing || batch.phase == .completed else { return }
        batch.items.removeAll { $0.id == itemID }
    }

    func clear() {
        guard batch.phase != .sending && batch.phase != .cancelling else { return }
        batch = CurrentBatch(id: UUID(), items: [], phase: .editing)
    }

    func confirm(setup: DeliverySetup) -> ConfirmedBatchSnapshot {
        let eligible = batch.items.filter { $0.preparation == .ready }.map(\.id)
        let excluded = batch.items.filter { $0.preparation != .ready }.map(\.id)
        let snapshot = ConfirmedBatchSnapshot(
            id: UUID(),
            setupRevision: setup.revision,
            destination: setup.kindleAddress,
            eligibleItemIDs: eligible,
            excludedItemIDs: excluded,
            confirmedAt: Date()
        )
        batch.confirmedSnapshotIdentifier = snapshot.id
        return snapshot
    }

    func send(
        snapshot: ConfirmedBatchSnapshot,
        setup: DeliverySetup,
        delivery: any SMTPDelivering,
        credential: String
    ) {
        guard activeTask == nil else { return }
        batch.phase = .sending
        activeTask = Task {
            var completed = 0
            for itemID in snapshot.eligibleItemIDs {
                if Task.isCancelled {
                    markPendingCancelled(snapshot.eligibleItemIDs.dropFirst(completed))
                    break
                }
                guard let index = batch.items.firstIndex(where: { $0.id == itemID }),
                      let prepared = batch.items[index].preparedBook
                else {
                    completed += 1
                    continue
                }
                batch.items[index].delivery = .sending(.connecting)
                eventContinuation?.yield(.sending(itemID, .connecting))
                let outcome = await delivery.send(book: prepared, setup: setup, credential: credential)
                apply(outcome, to: index)
                completed += 1
                eventContinuation?.yield(.batchProgress(completed: completed, total: snapshot.eligibleItemIDs.count))
            }
            batch.phase = .completed
            eventContinuation?.yield(.batchCompleted(batch.id))
            activeTask = nil
        }
    }

    func cancel(delivery: (any SMTPDelivering)? = nil) async {
        batch.phase = .cancelling
        activeTask?.cancel()
        await delivery?.cancelActiveAttempt()
    }

    private func apply(_ outcome: TerminalOutcome, to index: Int) {
        let id = batch.items[index].id
        switch outcome {
        case .submitted:
            batch.items[index].delivery = .submitted
            eventContinuation?.yield(.submitted(id))
        case .failed(let failure):
            batch.items[index].delivery = .failed(failure)
            eventContinuation?.yield(.failed(id, failure))
        case .cancelled:
            batch.items[index].delivery = .cancelled
            eventContinuation?.yield(.cancelled(id))
        case .deliveryUnknown:
            batch.items[index].delivery = .deliveryUnknown
            eventContinuation?.yield(.deliveryUnknown(id))
        }
    }

    private func markPendingCancelled(_ ids: ArraySlice<UUID>) {
        for id in ids {
            guard let index = batch.items.firstIndex(where: { $0.id == id }) else { continue }
            batch.items[index].delivery = .cancelled
            eventContinuation?.yield(.cancelled(id))
        }
    }
}
