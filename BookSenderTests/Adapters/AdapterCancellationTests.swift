import Foundation
import Testing
@testable import BookSender

struct AdapterCancellationTests {
    @Test
    func workspaceTimeoutRemovesPartialCopy() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let workspaceStore = WorkspaceStore(
            rootURL: stores.rootURL.appending(component: "work"),
            operationTimeout: .zero
        )
        let workspace = try await workspaceStore.createWorkspace(
            batchID: UUID(),
            itemID: UUID()
        )
        let source = stores.rootURL.appending(component: "book.pdf")
        try Data("%PDF-1.7\n%%EOF\n".utf8).write(to: source)

        await #expect(throws: SanitizedFailure.self) {
            _ = try await workspaceStore.stageReadOnlySource(
                source,
                in: workspace,
                maximumBytes: 1_024
            )
        }
        #expect(
            FileManager.default.fileExists(
                atPath: workspace.rootURL
                    .appending(component: "source.partial").path
            ) == false
        )
    }
}
