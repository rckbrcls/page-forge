import Foundation
import Testing
@testable import BookSender

struct WorkspaceStoreTests {
    @Test
    func stagesWithoutChangingOriginalAndPromotesOnlyPartial() async throws {
        let root = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        let source = root.appending(component: "original.epub")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = Data("immutable-original".utf8)
        try original.write(to: source)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = WorkspaceStore(rootURL: root.appending(component: "work"))
        let workspace = try await store.createWorkspace(batchID: UUID(), itemID: UUID())
        let staged = try await store.stageReadOnlySource(source, in: workspace)
        #expect(try Data(contentsOf: source) == original)
        #expect(staged.url.lastPathComponent == "source.snapshot")

        let partial = workspace.rootURL.appending(component: "prepared.partial.epub")
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
}
