import Foundation
import Testing
@testable import BookSender

struct EPUBArchiveWriterTests {
    @Test
    func writesFirstUncompressedMimetypeAndOnlyPlannedRestoration() async throws {
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
        let original = try FixtureFactory.makeEPUB(
            .missingContainer,
            in: stores.rootURL
        )
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: SafetyLimits.standard.maximumBookBytes
        )
        let plan = PreparationPlan(
            id: UUID(),
            originalAuditIdentifier: UUID(),
            actions: [
                .rebuildMimetype,
                .restoreContainer(packagePath: "OEBPS/content.opf"),
            ],
            decision: .writeEPUBWorkingCopy
        )

        let partial = try await EPUBArchiveWriter().write(
            source: source,
            plan: plan,
            workspace: workspace,
            limits: .standard
        )
        let archive = ZIPFoundationEPUBArchive(source: partial)
        let entries = try await archive.preflight(partial, limits: .standard)

        #expect(entries.first?.path == "mimetype")
        #expect(entries.first?.compressionMethod == 0)
        #expect(entries.contains(where: { $0.path == "META-INF/container.xml" }))
        #expect(entries.contains(where: { $0.path == "OEBPS/chapter.xhtml" }))
    }

    @Test
    func rejectsUnsupportedActionAndRemovesPartialOutput() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let workspace = try await workspaceStore.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let original = try FixtureFactory.makeEPUB(.validEPUB3, in: stores.rootURL)
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: SafetyLimits.standard.maximumBookBytes
        )
        let plan = PreparationPlan(
            id: UUID(),
            originalAuditIdentifier: UUID(),
            actions: [
                .correctMediaType(
                    path: "OEBPS/chapter.xhtml",
                    mediaType: "application/xhtml+xml"
                ),
            ],
            decision: .writeEPUBWorkingCopy
        )

        do {
            _ = try await EPUBArchiveWriter().write(
                source: source,
                plan: plan,
                workspace: workspace,
                limits: .standard
            )
            Issue.record("Expected unsupported repair action")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .repairUnsupportedAction)
            #expect(failure.evidence.phase == .workingCopyWrite)
            #expect(String(describing: failure).contains(source.url.path) == false)
        }
        #expect(
            FileManager.default.fileExists(
                atPath: workspace.rootURL
                    .appending(component: "prepared.partial.epub").path
            ) == false
        )
    }

    @Test
    func cancellationBeforeWriteLeavesNoPartialOutput() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work")
        )
        let workspace = try await workspaceStore.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let original = try FixtureFactory.makeEPUB(.validEPUB3, in: stores.rootURL)
        let source = try await workspaceStore.stageReadOnlySource(
            original,
            in: workspace,
            maximumBytes: SafetyLimits.standard.maximumBookBytes
        )
        let plan = PreparationPlan(
            id: UUID(),
            originalAuditIdentifier: UUID(),
            actions: [],
            decision: .writeEPUBWorkingCopy
        )
        let task = Task {
            try await EPUBArchiveWriter().write(
                source: source,
                plan: plan,
                workspace: workspace,
                limits: .standard
            )
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(
            FileManager.default.fileExists(
                atPath: workspace.rootURL
                    .appending(component: "prepared.partial.epub").path
            ) == false
        )
    }
}
