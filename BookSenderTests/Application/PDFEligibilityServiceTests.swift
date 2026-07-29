import Foundation
import Testing
@testable import BookSender

struct PDFEligibilityServiceTests {
    @Test
    func preparesImmutablePDFSnapshotWithDigestAndNoConversion() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let batchID = UUID()
        let itemID = UUID()
        let workspace = try await workspaceStore.createWorkspace(
            batchID: batchID,
            itemID: itemID
        )
        let original = try FixtureFactory.makePDF(
            valid: true,
            in: stores.rootURL
        )
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: SafetyLimits.standard.maximumBookBytes
        )
        let before = try Data(contentsOf: source.url)

        let result = await PDFEligibilityService(
            workspaceStore: workspaceStore
        ).prepare(
            itemID: itemID,
            source: source,
            displayName: "Book.pdf"
        )

        let prepared = try #require(result.preparedBook)
        #expect(prepared.file == source)
        #expect(prepared.format == .pdf)
        #expect(prepared.contentDigest == (try await workspaceStore.digest(of: source)))
        #expect(try Data(contentsOf: source.url) == before)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: source.url.path
        )
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o400)
    }

    @Test
    func blocksMalformedPDF() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let workspace = try await workspaceStore.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let original = try FixtureFactory.makePDF(
            valid: false,
            in: stores.rootURL
        )
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: 1_024
        )
        let result = await PDFEligibilityService(
            workspaceStore: workspaceStore
        ).prepare(
            itemID: workspace.itemID,
            source: source,
            displayName: original.lastPathComponent
        )

        #expect(result.preparedBook == nil)
        #expect(result.failure?.code == "pdf.signature")
    }

    @Test
    func blocksPDFPastAttachmentLimit() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let workspace = try await workspaceStore.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let original = try FixtureFactory.makePDF(valid: true, in: stores.rootURL)
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: 1_024
        )
        let byteCount = Int64(
            try source.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        )
        let result = await PDFEligibilityService(
            workspaceStore: workspaceStore,
            limits: makeSafetyLimits(
                maximumAttachmentBytes: max(0, byteCount - 1)
            )
        ).prepare(
            itemID: workspace.itemID,
            source: source,
            displayName: original.lastPathComponent
        )

        #expect(result.preparedBook == nil)
        #expect(result.failure?.code == "pdf.size")
    }
}
