import Foundation
import Testing
@testable import BookSender

struct FileSendHistoryStoreTests {
    @Test
    func missingStoreLoadsEmptyAndRoundTripsVersionOneEnvelope() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)
        let record = HistoryTestFixtures.record()

        #expect(try await store.load().isEmpty)
        try await store.replace(with: [record])

        #expect(try await store.load() == [record])
    }

    @Test
    func rejectsFilesLargerThanOneMiBBeforeDecoding() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)
        try FileManager.default.createDirectory(
            at: stores.historyRootURL,
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x41, count: FileSendHistoryStore.maximumFileBytes + 1)
            .write(to: store.fileURL)

        await #expect(throws: HistoryFailure.self) {
            _ = try await store.load()
        }
    }

    @Test
    func corruptOrUnsupportedDataIsNotSilentlyRepaired() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)
        try FileManager.default.createDirectory(
            at: stores.historyRootURL,
            withIntermediateDirectories: true
        )
        let original = Data(#"{"schemaVersion":99,"records":[]}"#.utf8)
        try original.write(to: store.fileURL)

        do {
            _ = try await store.load()
            Issue.record("Expected unsupported history schema rejection.")
        } catch let failure as HistoryFailure {
            #expect(failure.code == .unsupportedSchema)
            #expect(failure.operation == .load)
        }
        #expect(try Data(contentsOf: store.fileURL) == original)
    }

    @Test
    func clearRemovesOnlyTheHistoryFile() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)
        try await store.replace(with: [HistoryTestFixtures.record()])
        let neighbor = stores.historyRootURL.appending(component: "keep.txt")
        try Data("keep".utf8).write(to: neighbor)

        try await store.clear()

        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        #expect(FileManager.default.fileExists(atPath: neighbor.path))
    }

    @Test
    func createsOwnerOnlyDirectoryAndFilePermissions() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)

        try await store.replace(with: [HistoryTestFixtures.record()])

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: stores.historyRootURL.path
        )
        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: store.fileURL.path
        )
        #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test
    func replacementPublishesOnlyTheCompleteNewEnvelope() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)
        let first = HistoryTestFixtures.record()
        let second = HistoryTestFixtures.record(
            id: HistoryTestFixtures.secondID,
            acceptedAt: HistoryTestFixtures.secondDate
        )

        try await store.replace(with: [first])
        try await store.replace(with: [second, first])

        #expect(try await store.load() == [second, first])
        let names = try FileManager.default.contentsOfDirectory(
            atPath: stores.historyRootURL.path
        )
        #expect(names == ["history-v1.json"])
    }

    @Test
    func malformedEmptyFileReportsDecodeWithoutChangingIt() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let store = FileSendHistoryStore(rootURL: stores.historyRootURL)
        try FileManager.default.createDirectory(
            at: stores.historyRootURL,
            withIntermediateDirectories: true
        )
        try Data().write(to: store.fileURL)

        do {
            _ = try await store.load()
            Issue.record("Expected an empty history file to be rejected.")
        } catch let failure as HistoryFailure {
            #expect(failure.code == .decode)
            #expect(failure.operation == .load)
        }
        #expect(try Data(contentsOf: store.fileURL).isEmpty)
    }

    @Test
    func unavailableRootProducesTypedWriteFailure() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let rootFile = stores.rootURL.appending(component: "not-a-directory")
        try Data("occupied".utf8).write(to: rootFile)
        let store = FileSendHistoryStore(rootURL: rootFile)

        do {
            try await store.replace(with: [HistoryTestFixtures.record()])
            Issue.record("Expected unavailable storage to reject the write.")
        } catch let failure as HistoryFailure {
            #expect(failure.code == .write)
            #expect(failure.operation == .record)
        }
    }

    @Test
    func clearFailurePreservesExistingEncodedHistory() async throws {
        let store = FailingClearHistoryStore(
            records: [HistoryTestFixtures.record()]
        )
        let service = SendHistoryService(store: store)
        let before = try await service.snapshot()

        do {
            try await service.clear()
            Issue.record("Expected the controlled clear to fail.")
        } catch let failure as HistoryFailure {
            #expect(failure.code == .clear)
        }
        await service.invalidateCache()
        #expect(try await service.snapshot().records == before.records)
    }
}

private actor FailingClearHistoryStore: SendHistoryStoring {
    let records: [SubmissionRecord]

    init(records: [SubmissionRecord]) {
        self.records = records
    }

    func load() -> [SubmissionRecord] {
        records
    }

    func replace(with records: [SubmissionRecord]) {}

    func clear() throws {
        throw HistoryFailure(operation: .clear, code: .clear)
    }
}
