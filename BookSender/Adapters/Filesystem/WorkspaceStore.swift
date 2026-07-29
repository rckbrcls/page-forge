import CryptoKit
import Foundation

actor WorkspaceStore: WorkspaceStoring {
    private let fileManager: FileManager
    private let rootURL: URL
    private let markerName = ".booksender-workspace"

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? fileManager.temporaryDirectory
            .appending(component: "BookSender", directoryHint: .isDirectory)
    }

    func createWorkspace(batchID: UUID, itemID: UUID) throws -> WorkspaceReference {
        let workspaceRoot = rootURL
            .appending(component: batchID.uuidString, directoryHint: .isDirectory)
            .appending(component: itemID.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: workspaceRoot, withIntermediateDirectories: true)
        let marker = workspaceRoot.appending(component: markerName)
        guard fileManager.createFile(atPath: marker.path, contents: Data()) else {
            throw failure("workspace.marker")
        }
        return WorkspaceReference(batchID: batchID, itemID: itemID, rootURL: workspaceRoot)
    }

    func stageReadOnlySource(_ source: URL, in workspace: WorkspaceReference) async throws -> StagedFileReference {
        try Task.checkCancellation()
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess { source.stopAccessingSecurityScopedResource() }
        }

        let destination = workspace.rootURL.appending(component: "source.partial")
        let finalURL = workspace.rootURL.appending(component: "source.snapshot")
        try await copyStreaming(from: source, to: destination)
        try Task.checkCancellation()
        try fileManager.moveItem(at: destination, to: finalURL)
        return StagedFileReference(identifier: UUID(), url: finalURL)
    }

    func promotePartial(
        _ relativePath: String,
        to finalPath: String,
        in workspace: WorkspaceReference
    ) throws -> StagedFileReference {
        let source = try containedURL(relativePath, in: workspace)
        let destination = try containedURL(finalPath, in: workspace)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw failure("workspace.collision")
        }
        try fileManager.moveItem(at: source, to: destination)
        return StagedFileReference(identifier: UUID(), url: destination)
    }

    func cleanup(_ workspace: WorkspaceReference) {
        guard isMarkedWorkspace(workspace.rootURL) else { return }
        try? fileManager.removeItem(at: workspace.rootURL)
        let batchRoot = workspace.rootURL.deletingLastPathComponent()
        if (try? fileManager.contentsOfDirectory(atPath: batchRoot.path).isEmpty) == true {
            try? fileManager.removeItem(at: batchRoot)
        }
    }

    func sweepOrphans(olderThan cutoff: Date) {
        guard let batches = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for batch in batches {
            guard let items = try? fileManager.contentsOfDirectory(
                at: batch,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for item in items where isMarkedWorkspace(item) {
                let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                if let date = values?.contentModificationDate, date < cutoff {
                    try? fileManager.removeItem(at: item)
                }
            }
        }
    }

    func digest(of file: StagedFileReference) async throws -> String {
        let handle = try FileHandle(forReadingFrom: file.url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 64 * 1_024) ?? Data()
            guard !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func copyStreaming(from source: URL, to destination: URL) async throws {
        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            throw failure("workspace.partial-create")
        }
        do {
            let reader = try FileHandle(forReadingFrom: source)
            let writer = try FileHandle(forWritingTo: destination)
            defer {
                try? reader.close()
                try? writer.close()
            }
            while true {
                try Task.checkCancellation()
                let chunk = try reader.read(upToCount: 64 * 1_024) ?? Data()
                guard !chunk.isEmpty else { break }
                try writer.write(contentsOf: chunk)
            }
            try writer.synchronize()
        } catch {
            try? fileManager.removeItem(at: destination)
            throw failure(error is CancellationError ? "workspace.cancelled" : "workspace.copy")
        }
    }

    private func containedURL(_ relativePath: String, in workspace: WorkspaceReference) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw failure("workspace.invalid-path")
        }
        let url = workspace.rootURL.appending(path: relativePath).standardizedFileURL
        let root = workspace.rootURL.standardizedFileURL.path + "/"
        guard url.path.hasPrefix(root), !relativePath.split(separator: "/").contains("..") else {
            throw failure("workspace.invalid-path")
        }
        return url
    }

    private func isMarkedWorkspace(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.appending(component: markerName).path)
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .filesystem,
            code: code,
            message: "The temporary book workspace could not be updated.",
            recoveryAction: .chooseAnotherFile
        )
    }
}
