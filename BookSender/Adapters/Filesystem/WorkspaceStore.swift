import CryptoKit
import Foundation

actor WorkspaceStore: WorkspaceStoring {
    private let fileManager: FileManager
    private let rootURL: URL
    private let operationTimeout: Duration
    private let markerName = ".booksender-workspace"
    private let partialNames = ["source.partial", "prepared.partial.epub"]

    init(
        fileManager: FileManager = .default,
        rootURL: URL? = nil,
        operationTimeout: Duration = SafetyLimits.standard.operationTimeout
    ) {
        self.fileManager = fileManager
        self.operationTimeout = operationTimeout
        self.rootURL = (
            rootURL
                ?? fileManager.temporaryDirectory
                    .appending(component: "BookSender", directoryHint: .isDirectory)
        ).standardizedFileURL
    }

    func createWorkspace(batchID: UUID, itemID: UUID) throws -> WorkspaceReference {
        let workspaceRoot = rootURL
            .appending(component: batchID.uuidString, directoryHint: .isDirectory)
            .appending(component: itemID.uuidString, directoryHint: .isDirectory)
            .standardizedFileURL
        guard isDirectChild(workspaceRoot, ofBatch: batchID, itemID: itemID) else {
            throw failure("workspace.invalid-path")
        }
        try fileManager.createDirectory(
            at: workspaceRoot,
            withIntermediateDirectories: true
        )
        let marker = workspaceRoot.appending(component: markerName)
        if !fileManager.fileExists(atPath: marker.path) {
            guard fileManager.createFile(atPath: marker.path, contents: Data()) else {
                throw failure("workspace.marker")
            }
        }
        return WorkspaceReference(
            batchID: batchID,
            itemID: itemID,
            rootURL: workspaceRoot
        )
    }

    func stageReadOnlySource(
        _ source: URL,
        in workspace: WorkspaceReference,
        maximumBytes: Int64
    ) async throws -> StagedFileReference {
        try Task.checkCancellation()
        try validate(workspace)

        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let destination = try containedURL("source.partial", in: workspace)
        let finalURL = try containedURL("source.snapshot", in: workspace)
        guard !fileManager.fileExists(atPath: finalURL.path) else {
            throw failure("workspace.collision")
        }

        do {
            try await copyStreaming(
                from: source,
                to: destination,
                maximumBytes: maximumBytes
            )
            try Task.checkCancellation()
            try fileManager.moveItem(at: destination, to: finalURL)
            try fileManager.setAttributes(
                [.posixPermissions: 0o400],
                ofItemAtPath: finalURL.path
            )
            return StagedFileReference(identifier: UUID(), url: finalURL)
        } catch {
            try? fileManager.removeItem(at: destination)
            try? fileManager.removeItem(at: finalURL)
            if error is CancellationError {
                throw error
            }
            if let failure = error as? SanitizedFailure {
                throw failure
            }
            throw failure("workspace.copy")
        }
    }

    func promotePartial(
        _ relativePath: String,
        to finalPath: String,
        in workspace: WorkspaceReference
    ) throws -> StagedFileReference {
        try validate(workspace)
        let source = try containedURL(relativePath, in: workspace)
        let destination = try containedURL(finalPath, in: workspace)
        guard fileManager.fileExists(atPath: source.path),
              !fileManager.fileExists(atPath: destination.path)
        else {
            throw failure("workspace.collision")
        }
        do {
            try fileManager.moveItem(at: source, to: destination)
            try fileManager.setAttributes(
                [.posixPermissions: 0o400],
                ofItemAtPath: destination.path
            )
        } catch {
            try? fileManager.removeItem(at: destination)
            if let sanitized = error as? SanitizedFailure {
                throw sanitized
            }
            throw failure("workspace.promote")
        }
        return StagedFileReference(identifier: UUID(), url: destination)
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

    func cleanupPartialFiles(in workspace: WorkspaceReference) {
        guard (try? validate(workspace)) != nil else { return }
        for name in partialNames {
            guard let url = try? containedURL(name, in: workspace) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    func cleanup(_ workspace: WorkspaceReference) {
        guard (try? validate(workspace)) != nil else { return }
        try? fileManager.removeItem(at: workspace.rootURL)
        let batchRoot = workspace.rootURL.deletingLastPathComponent()
        if (try? fileManager.contentsOfDirectory(atPath: batchRoot.path).isEmpty) == true {
            try? fileManager.removeItem(at: batchRoot)
        }
    }

    func clearBatch(_ batchID: UUID) {
        let batchRoot = rootURL
            .appending(component: batchID.uuidString, directoryHint: .isDirectory)
            .standardizedFileURL
        guard batchRoot.deletingLastPathComponent().standardizedFileURL.path
                == rootURL.path,
              let children = try? fileManager.contentsOfDirectory(
                at: batchRoot,
                includingPropertiesForKeys: nil,
                options: []
              ),
              children.allSatisfy(isMarkedWorkspace)
        else {
            return
        }
        try? fileManager.removeItem(at: batchRoot)
    }

    func sweepOrphans(olderThan cutoff: Date) {
        guard let batches = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for batch in batches {
            guard UUID(uuidString: batch.lastPathComponent) != nil,
                  batch.deletingLastPathComponent().standardizedFileURL.path
                    == rootURL.path,
                  let items = try? fileManager.contentsOfDirectory(
                      at: batch,
                      includingPropertiesForKeys: [.contentModificationDateKey],
                      options: [.skipsHiddenFiles]
                  )
            else {
                continue
            }

            for item in items {
                guard UUID(uuidString: item.lastPathComponent) != nil,
                      isMarkedWorkspace(item)
                else {
                    continue
                }
                let values = try? item.resourceValues(
                    forKeys: [.contentModificationDateKey]
                )
                if let date = values?.contentModificationDate, date < cutoff {
                    try? fileManager.removeItem(at: item)
                }
            }
            if (try? fileManager.contentsOfDirectory(atPath: batch.path).isEmpty) == true {
                try? fileManager.removeItem(at: batch)
            }
        }
    }

    private func copyStreaming(
        from source: URL,
        to destination: URL,
        maximumBytes: Int64
    ) async throws {
        guard !fileManager.fileExists(atPath: destination.path),
              fileManager.createFile(atPath: destination.path, contents: nil)
        else {
            throw failure("workspace.partial-create")
        }

        let reader = try FileHandle(forReadingFrom: source)
        let writer = try FileHandle(forWritingTo: destination)
        defer {
            try? reader.close()
            try? writer.close()
        }

        var copied: Int64 = 0
        let deadline = ContinuousClock.now.advanced(by: operationTimeout)
        while true {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else {
                throw failure("workspace.timeout")
            }
            let chunk = try reader.read(upToCount: 64 * 1_024) ?? Data()
            guard !chunk.isEmpty else { break }
            copied += Int64(chunk.count)
            guard copied <= maximumBytes else {
                throw failure("workspace.size-limit")
            }
            try writer.write(contentsOf: chunk)
        }
        try writer.synchronize()
    }

    private func containedURL(
        _ relativePath: String,
        in workspace: WorkspaceReference
    ) throws -> URL {
        try validate(workspace)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/", omittingEmptySubsequences: false)
                  .contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
        else {
            throw failure("workspace.invalid-path")
        }
        let url = workspace.rootURL.appending(path: relativePath).standardizedFileURL
        let root = workspace.rootURL.standardizedFileURL.path + "/"
        guard url.path.hasPrefix(root) else {
            throw failure("workspace.invalid-path")
        }
        return url
    }

    private func validate(_ workspace: WorkspaceReference) throws {
        guard isDirectChild(
            workspace.rootURL.standardizedFileURL,
            ofBatch: workspace.batchID,
            itemID: workspace.itemID
        ),
        isMarkedWorkspace(workspace.rootURL)
        else {
            throw failure("workspace.invalid-marker")
        }
    }

    private func isDirectChild(
        _ workspaceURL: URL,
        ofBatch batchID: UUID,
        itemID: UUID
    ) -> Bool {
        let expected = rootURL
            .appending(component: batchID.uuidString, directoryHint: .isDirectory)
            .appending(component: itemID.uuidString, directoryHint: .isDirectory)
            .standardizedFileURL
        return workspaceURL == expected
    }

    private func isMarkedWorkspace(_ url: URL) -> Bool {
        fileManager.fileExists(
            atPath: url.appending(component: markerName).path
        )
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
