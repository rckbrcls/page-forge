import Foundation
import Testing
@testable import BookSender

struct OriginalPreservationTests {
    @Test(arguments: [
        FixtureFactory.EPUBVariant.validEPUB3,
        .missingMimetype,
        .invalidContainer,
        .pathTraversal,
    ])
    func originalRemainsByteForByteUnchangedAcrossPreparationOutcomes(
        variant: FixtureFactory.EPUBVariant
    ) async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let workspace = try await workspaceStore.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let original = try FixtureFactory.makeEPUB(variant, in: stores.rootURL)
        let before = try Data(contentsOf: original)
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: SafetyLimits.standard.maximumBookBytes
        )

        _ = await EPUBRepairEngine(
            writer: EPUBArchiveWriter(),
            workspaceStore: workspaceStore
        ).prepare(
            source: source,
            workspace: workspace,
            displayName: original.lastPathComponent
        )

        #expect(try Data(contentsOf: original) == before)
    }
}
