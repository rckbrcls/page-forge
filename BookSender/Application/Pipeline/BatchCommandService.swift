import Foundation

actor BatchCommandService {
    private let pipeline: PipelineActor

    init(pipeline: PipelineActor) {
        self.pipeline = pipeline
    }

    func remove(_ itemID: UUID) async {
        await pipeline.remove(itemID)
    }

    func clear() async {
        await pipeline.clear()
    }

    func cancel() async {
        await pipeline.cancel()
    }

    func failedItemIDs() async -> [UUID] {
        let batch = await pipeline.snapshot()
        return batch.items.compactMap { item in
            if case .failed = item.delivery { return item.id }
            return nil
        }
    }

    func retrySnapshot(
        setup: ValidatedDeliverySetup
    ) async -> ConfirmedBatchSummary? {
        await pipeline.confirmation(setup: setup, kind: .retryFailed)
    }
}
