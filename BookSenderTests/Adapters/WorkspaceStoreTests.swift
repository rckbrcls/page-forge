import Foundation
import Testing
@testable import BookSender

struct WorkspaceStoreTests {
    @Test
    func stagesWithoutChangingOriginalAndPromotesOnlyPartial() async throws {
        let root = try FixtureFactory.makeDirectory()
        let source = root.appending(component: "original.epub")
        let original = Data("immutable-original".utf8)
        try original.write(to: source)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = WorkspaceStore(rootURL: root.appending(component: "work"))
        let workspace = try await store.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let staged = try await store.stageReadOnlySource(
            source,
            in: workspace,
            maximumBytes: 1_024
        )
        #expect(try Data(contentsOf: source) == original)
        #expect(staged.url.lastPathComponent == "source.snapshot")
        #expect(try await store.digest(of: staged).count == 64)

        let partial = workspace.rootURL
            .appending(component: "prepared.partial.epub")
        try Data("prepared".utf8).write(to: partial)
        let promoted = try await store.promotePartial(
            "prepared.partial.epub",
            to: "prepared.epub",
            in: workspace
        )
        #expect(promoted.url.lastPathComponent == "prepared.epub")
        #expect(FileManager.default.fileExists(atPath: partial.path) == false)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test
    func rejectsEscapingOrUnmarkedWorkspacePaths() async throws {
        let root = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = WorkspaceStore(rootURL: root.appending(component: "work"))
        let workspace = try await store.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )

        do {
            _ = try await store.promotePartial(
                "../outside",
                to: "prepared.epub",
                in: workspace
            )
            Issue.record("Expected unsafe workspace path")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .workspaceInvalidPath)
            #expect(failure.evidence.phase == .workspaceStaging)
            #expect(
                String(describing: failure).contains(root.path) == false
            )
        } catch {
            Issue.record("Expected sanitized workspace failure")
        }

        let fake = WorkspaceReference(
            batchID: UUID(),
            itemID: UUID(),
            rootURL: root
        )
        await store.cleanup(fake)
        #expect(FileManager.default.fileExists(atPath: root.path))
    }

    @Test
    func translatesUnexpectedWorkspaceAndDigestFailuresWithoutPaths() async throws {
        let root = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let blockedRoot = root.appending(component: "blocked")
        try Data("not-a-directory".utf8).write(to: blockedRoot)
        let blockedStore = WorkspaceStore(rootURL: blockedRoot)
        do {
            _ = try await blockedStore.createWorkspace(
                batchID: UUID(),
                itemID: UUID()
            )
            Issue.record("Expected a sanitized workspace creation failure")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .unexpectedFilesystem)
            #expect(failure.evidence.phase == .workspaceStaging)
            #expect(String(describing: failure).contains(root.path) == false)
        } catch {
            Issue.record("Expected a sanitized workspace failure")
        }

        let missing = StagedFileReference(
            identifier: UUID(),
            url: root.appending(component: "missing.epub")
        )
        do {
            _ = try await blockedStore.digest(of: missing)
            Issue.record("Expected a sanitized digest failure")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .unexpectedFilesystem)
            #expect(failure.evidence.phase == .workingCopyWrite)
            #expect(String(describing: failure).contains(root.path) == false)
        } catch {
            Issue.record("Expected a sanitized workspace failure")
        }
    }

    @Test
    func cleansPartialsAndOnlyMarkerValidBatchRoots() async throws {
        let root = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appending(component: "work")
        let store = WorkspaceStore(rootURL: storeRoot)
        let batchID = UUID()
        let workspace = try await store.createWorkspace(
            batchID: batchID,
            itemID: UUID()
        )
        let partial = workspace.rootURL
            .appending(component: "prepared.partial.epub")
        try Data("partial".utf8).write(to: partial)

        await store.cleanupPartialFiles(in: workspace)
        #expect(FileManager.default.fileExists(atPath: partial.path) == false)

        #expect(await store.clearBatch(batchID))
        #expect(
            FileManager.default.fileExists(
                atPath: storeRoot
                    .appending(component: batchID.uuidString)
                    .path
            ) == false
        )
    }

    @Test
    func sweepsOnlyOldMarkerValidUUIDWorkspaces() async throws {
        let root = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let storeRoot = root.appending(component: "work")
        let store = WorkspaceStore(rootURL: storeRoot)
        let workspace = try await store.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let oldDate = Date(timeIntervalSinceNow: -172_800)
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: workspace.rootURL.path
        )

        let unmarked = storeRoot
            .appending(component: UUID().uuidString)
            .appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: unmarked,
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: unmarked.path
        )

        await store.sweepOrphans(olderThan: Date(timeIntervalSinceNow: -86_400))
        #expect(
            FileManager.default.fileExists(atPath: workspace.rootURL.path)
                == false
        )
        #expect(FileManager.default.fileExists(atPath: unmarked.path))
    }
}
