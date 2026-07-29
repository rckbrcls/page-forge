import CryptoKit
import Foundation
import UniformTypeIdentifiers

actor BookIntakeService {
    private let workspaceStore: WorkspaceStore
    private let limits: SafetyLimits

    init(workspaceStore: WorkspaceStore, limits: SafetyLimits = .standard) {
        self.workspaceStore = workspaceStore
        self.limits = limits
    }

    func intake(_ urls: [URL], batchID: UUID, existing: Set<SourceIdentity>) async -> [BatchItem] {
        var known = existing
        var results: [BatchItem] = []
        for url in urls {
            if Task.isCancelled { break }
            do {
                let item = try await intake(url, batchID: batchID)
                guard known.insert(item.sourceIdentity).inserted else { continue }
                results.append(item)
            } catch {
                continue
            }
        }
        return results
    }

    private func intake(_ url: URL, batchID: UUID) async throws -> BatchItem {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isReadableKey, .fileSizeKey,
            .contentModificationDateKey, .fileResourceIdentifierKey
        ])
        guard values.isRegularFile == true, values.isReadable == true else {
            throw failure("intake.unreadable")
        }
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0, byteCount <= limits.maximumBookBytes else {
            throw failure("intake.size")
        }
        let format: BookFormat
        switch url.pathExtension.lowercased() {
        case "epub": format = .epub
        case "pdf": format = .pdf
        default: throw failure("intake.unsupported")
        }
        let identity = SourceIdentity(
            resourceIdentifier: String(describing: values.fileResourceIdentifier ?? url.standardizedFileURL.path),
            byteCount: byteCount,
            modificationDate: values.contentModificationDate ?? .distantPast,
            fingerprint: "\(byteCount):\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        )
        let id = UUID()
        let workspace = try await workspaceStore.createWorkspace(batchID: batchID, itemID: id)
        let staged = try await workspaceStore.stageReadOnlySource(url, in: workspace)
        return BatchItem(
            id: id,
            displayName: sanitizedDisplayName(url.lastPathComponent),
            sourceIdentity: identity,
            format: format,
            stagedSource: staged,
            health: format == .pdf ? .healthy : nil,
            preparation: format == .pdf ? .ready : .checking,
            delivery: .notScheduled,
            findings: [],
            appliedActions: [],
            preparedBook: format == .pdf
                ? PreparedBook(
                    id: UUID(),
                    batchItemID: id,
                    file: staged,
                    originalDisplayName: sanitizedDisplayName(url.lastPathComponent),
                    format: .pdf,
                    byteCount: byteCount,
                    contentDigest: "",
                    comparison: nil
                )
                : nil
        )
    }

    private func sanitizedDisplayName(_ value: String) -> String {
        let filtered = value.filter { !$0.isNewline && !$0.isControl }
        return String(filtered.prefix(240))
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .intake,
            code: code,
            message: "This file could not be added.",
            recoveryAction: .chooseAnotherFile
        )
    }
}
