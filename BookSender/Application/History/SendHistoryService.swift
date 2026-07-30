import Foundation

actor SendHistoryService {
    static let maximumRecords = 500

    private let store: any SendHistoryStoring
    private var cachedRecords: [SubmissionRecord]?

    init(store: any SendHistoryStoring) {
        self.store = store
    }

    func snapshot() async throws -> SendHistorySnapshot {
        let records = try await records()
        return SendHistorySnapshot(records: records, loadedAt: Date())
    }

    func record(_ receipt: SubmissionReceipt) async throws {
        var current = try await records()
        guard !current.contains(where: { $0.id == receipt.attemptID }) else {
            return
        }
        current.append(receipt.record)
        current.sort(by: SubmissionRecord.newestFirst)
        if current.count > Self.maximumRecords {
            current = Array(current.prefix(Self.maximumRecords))
        }
        do {
            try await store.replace(with: current)
            cachedRecords = current
        } catch let failure as HistoryFailure {
            throw failure
        } catch {
            throw HistoryFailure(operation: .record, code: .write)
        }
    }

    func clear() async throws {
        do {
            try await store.clear()
            cachedRecords = []
        } catch let failure as HistoryFailure {
            throw failure
        } catch {
            throw HistoryFailure(operation: .clear, code: .clear)
        }
    }

    func invalidateCache() {
        cachedRecords = nil
    }

    private func records() async throws -> [SubmissionRecord] {
        if let cachedRecords {
            return cachedRecords
        }
        do {
            var loaded = try await store.load()
            loaded.sort(by: SubmissionRecord.newestFirst)
            if loaded.count > Self.maximumRecords {
                loaded = Array(loaded.prefix(Self.maximumRecords))
            }
            cachedRecords = loaded
            return loaded
        } catch let failure as HistoryFailure {
            throw failure
        } catch {
            throw HistoryFailure(operation: .load, code: .read)
        }
    }
}
