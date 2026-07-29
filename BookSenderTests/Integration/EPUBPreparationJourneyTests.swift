import Foundation
import Testing
@testable import BookSender

struct EPUBPreparationJourneyTests {
    @Test(arguments: [
        FixtureFactory.EPUBVariant.validEPUB3,
        .missingMimetype,
        .missingContainer,
    ])
    func writesReopensRevalidatesAndPreservesOriginal(
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
        let originalDigest = try FixtureFactory.digest(of: original)
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: SafetyLimits.standard.maximumBookBytes
        )
        let engine = EPUBRepairEngine(
            writer: EPUBArchiveWriter(),
            workspaceStore: workspaceStore
        )

        let result = await engine.prepare(
            source: source,
            workspace: workspace,
            displayName: original.lastPathComponent
        )

        let prepared = try #require(result.preparedBook)
        #expect(result.preparedReport?.health == .healthy)
        #expect(result.comparison?.readiness == .ready)
        #expect(prepared.file.url.lastPathComponent == "prepared.epub")
        #expect(prepared.contentDigest.isEmpty == false)
        #expect(try FixtureFactory.digest(of: original) == originalDigest)
        #expect(prepared.file.url != original)
    }
}
