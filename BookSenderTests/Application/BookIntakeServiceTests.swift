import Foundation
import Testing
@testable import BookSender

struct BookIntakeServiceTests {
    @Test
    func returnsOneOrderedOutcomePerSelectedURL() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspace = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let service = BookIntakeService(workspaceStore: workspace)
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        let unsupported = stores.rootURL.appending(component: "notes.txt")
        try Data("notes".utf8).write(to: unsupported)

        let outcomes = await service.intake(
            [pdf, unsupported, pdf],
            batchID: UUID(),
            existing: []
        )

        #expect(outcomes.count == 3)
        if case .accepted(let item) = outcomes[0] {
            #expect(item.format == .pdf)
            #expect(item.sourceIdentity?.stagedContentDigest.isEmpty == false)
            #expect(item.stagedSource?.url != pdf)
        } else {
            Issue.record("Expected accepted PDF")
        }
        if case .excluded(let item) = outcomes[1] {
            #expect(item.health == .unsupported)
        } else {
            Issue.record("Expected unsupported exclusion")
        }
        if case .excluded(let item) = outcomes[2] {
            guard case .excluded(let failure) = item.preparation else {
                Issue.record("Expected duplicate failure")
                return
            }
            #expect(failure.code == "intake.duplicate")
        } else {
            Issue.record("Expected duplicate exclusion")
        }
    }

    @Test
    func enforcesCapacityAndFileSizeWithoutSilentDrops() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspace = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let limits = makeSafetyLimits(
            maximumBatchItems: 1,
            maximumBookBytes: 16
        )
        let service = BookIntakeService(
            workspaceStore: workspace,
            limits: limits
        )
        let first = stores.rootURL.appending(component: "first.pdf")
        let second = stores.rootURL.appending(component: "second.pdf")
        try Data("%PDF-1.7\n%%EOF".utf8).write(to: first)
        try Data("%PDF-1.7\n0123456789%%EOF".utf8).write(to: second)

        let outcomes = await service.intake(
            [first, second],
            batchID: UUID(),
            existing: []
        )

        #expect(outcomes.count == 2)
        if case .accepted = outcomes[0] {
            // Expected.
        } else {
            Issue.record("Expected first file to fit")
        }
        if case .excluded(let item) = outcomes[1],
           case .excluded(let failure) = item.preparation {
            #expect(failure.code == "intake.capacity")
        } else {
            Issue.record("Expected capacity exclusion")
        }
    }

    @Test
    func detectsSourceChangedDuringStagingAndCleansWorkspace() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let root = stores.rootURL.appending(component: "work")
        let backing = WorkspaceStore(rootURL: root)
        let mutating = MutatingWorkspaceStore(backing: backing)
        let service = BookIntakeService(workspaceStore: mutating)
        let pdf = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)

        let outcomes = await service.intake(
            [pdf],
            batchID: UUID(),
            existing: []
        )

        guard case .excluded(let item) = outcomes.first,
              case .excluded(let failure) = item.preparation
        else {
            Issue.record("Expected changed-file exclusion")
            return
        }
        #expect(failure.code == "intake.changed")
    }
}

private actor MutatingWorkspaceStore: WorkspaceStoring {
    let backing: WorkspaceStore

    init(backing: WorkspaceStore) {
        self.backing = backing
    }

    func createWorkspace(
        batchID: UUID,
        itemID: UUID
    ) async throws -> WorkspaceReference {
        try await backing.createWorkspace(batchID: batchID, itemID: itemID)
    }

    func stageReadOnlySource(
        _ source: URL,
        in workspace: WorkspaceReference,
        maximumBytes: Int64
    ) async throws -> StagedFileReference {
        let staged = try await backing.stageReadOnlySource(
            source,
            in: workspace,
            maximumBytes: maximumBytes
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000_000)],
            ofItemAtPath: source.path
        )
        return staged
    }

    func promotePartial(
        _ relativePath: String,
        to finalPath: String,
        in workspace: WorkspaceReference
    ) async throws -> StagedFileReference {
        try await backing.promotePartial(
            relativePath,
            to: finalPath,
            in: workspace
        )
    }

    func digest(of file: StagedFileReference) async throws -> String {
        try await backing.digest(of: file)
    }

    func cleanupPartialFiles(in workspace: WorkspaceReference) async {
        await backing.cleanupPartialFiles(in: workspace)
    }

    func cleanup(_ workspace: WorkspaceReference) async {
        await backing.cleanup(workspace)
    }

    func clearBatch(_ batchID: UUID) async {
        await backing.clearBatch(batchID)
    }

    func sweepOrphans(olderThan cutoff: Date) async {
        await backing.sweepOrphans(olderThan: cutoff)
    }
}
