import Foundation

actor BookIntakeService {
    private let workspaceStore: any WorkspaceStoring
    private let limits: SafetyLimits

    init(
        workspaceStore: any WorkspaceStoring,
        limits: SafetyLimits = .standard
    ) {
        self.workspaceStore = workspaceStore
        self.limits = limits
    }

    func intake(
        _ urls: [URL],
        batchID: UUID,
        existing: [BatchItem]
    ) async -> [IntakeOutcome] {
        var knownIdentities = Set(existing.compactMap(\.sourceIdentity))
        var acceptedCount = existing.filter {
            if case .excluded = $0.preparation { return false }
            if case .cancelled = $0.preparation { return false }
            return true
        }.count
        var outcomes: [IntakeOutcome] = []

        for url in urls {
            if Task.isCancelled {
                outcomes.append(.cancelled(cancelledItem(for: url)))
                continue
            }
            guard acceptedCount < limits.maximumBatchItems else {
                outcomes.append(
                    .excluded(
                        excludedItem(
                            for: url,
                            format: format(for: url),
                            failure: failure(
                                "intake.capacity",
                                message: "The batch has reached its item limit."
                            )
                        )
                    )
                )
                continue
            }

            do {
                let item = try await intake(url, batchID: batchID)
                guard let identity = item.sourceIdentity,
                      knownIdentities.insert(identity).inserted
                else {
                    if let stagedSource = item.stagedSource {
                        let workspace = WorkspaceReference(
                            batchID: batchID,
                            itemID: item.id,
                            rootURL: stagedSource.url.deletingLastPathComponent()
                        )
                        await workspaceStore.cleanup(workspace)
                    }
                    outcomes.append(
                        .excluded(
                            excludedItem(
                                for: url,
                                format: item.format,
                                failure: failure(
                                    "intake.duplicate",
                                    message: "This book is already in the batch."
                                )
                            )
                        )
                    )
                    continue
                }
                acceptedCount += 1
                outcomes.append(.accepted(item))
            } catch is CancellationError {
                outcomes.append(.cancelled(cancelledItem(for: url)))
            } catch let sanitized as SanitizedFailure {
                outcomes.append(
                    .excluded(
                        excludedItem(
                            for: url,
                            format: format(for: url),
                            failure: sanitized
                        )
                    )
                )
            } catch {
                outcomes.append(
                    .excluded(
                        excludedItem(
                            for: url,
                            format: format(for: url),
                            failure: failure("intake.failed")
                        )
                    )
                )
            }
        }
        return outcomes
    }

    private func intake(_ url: URL, batchID: UUID) async throws -> BatchItem {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let before = try sourceValues(for: url)
        guard before.isRegularFile == true, before.isReadable == true else {
            throw failure("intake.unreadable")
        }
        let byteCount = Int64(before.fileSize ?? 0)
        guard limits.permitsBookBytes(byteCount) else {
            throw failure(
                "intake.size",
                message: "This file is outside the supported size limit."
            )
        }
        guard let format = format(for: url) else {
            throw failure(
                "intake.unsupported",
                message: "Choose an EPUB or PDF file."
            )
        }

        let id = UUID()
        let workspace = try await workspaceStore.createWorkspace(
            batchID: batchID,
            itemID: id
        )
        do {
            let staged = try await workspaceStore.stageReadOnlySource(
                url,
                in: workspace,
                maximumBytes: limits.maximumBookBytes
            )
            let after = try sourceValues(for: url)
            guard before.fileSize == after.fileSize,
                  before.contentModificationDate == after.contentModificationDate
            else {
                throw failure(
                    "intake.changed",
                    message: "The file changed while it was being added."
                )
            }
            let digest = try await workspaceStore.digest(of: staged)
            let resourceIdentifier = before.fileResourceIdentifier
                .map { String(describing: $0) }
                ?? "unavailable"
            let identity = SourceIdentity(
                resourceIdentifier: resourceIdentifier,
                byteCount: byteCount,
                modificationDate: before.contentModificationDate ?? .distantPast,
                stagedContentDigest: digest
            )
            return BatchItem(
                id: id,
                displayName: sanitizedDisplayName(url.lastPathComponent),
                sourceIdentity: identity,
                format: format,
                stagedSource: staged,
                health: nil,
                preparation: .checking,
                delivery: .notScheduled,
                findings: [],
                appliedActions: [],
                preparedBook: nil
            )
        } catch {
            await workspaceStore.cleanup(workspace)
            throw error
        }
    }

    private func sourceValues(for url: URL) throws -> URLResourceValues {
        let uncachedURL = URL(fileURLWithPath: url.path)
        return try uncachedURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .isReadableKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .fileResourceIdentifierKey,
        ])
    }

    private func format(for url: URL) -> BookFormat? {
        switch url.pathExtension.lowercased() {
        case "epub": .epub
        case "pdf": .pdf
        default: nil
        }
    }

    private func excludedItem(
        for url: URL,
        format: BookFormat?,
        failure: SanitizedFailure
    ) -> BatchItem {
        BatchItem(
            id: UUID(),
            displayName: sanitizedDisplayName(url.lastPathComponent),
            sourceIdentity: nil,
            format: format,
            stagedSource: nil,
            health: format == nil ? .unsupported : nil,
            preparation: .excluded(failure),
            delivery: .notScheduled,
            findings: [],
            appliedActions: [],
            preparedBook: nil
        )
    }

    private func cancelledItem(for url: URL) -> BatchItem {
        BatchItem(
            id: UUID(),
            displayName: sanitizedDisplayName(url.lastPathComponent),
            sourceIdentity: nil,
            format: format(for: url),
            stagedSource: nil,
            health: nil,
            preparation: .cancelled,
            delivery: .notScheduled,
            findings: [],
            appliedActions: [],
            preparedBook: nil
        )
    }

    private func sanitizedDisplayName(_ value: String) -> String {
        let filtered = value.filter { !$0.isNewline && !$0.isControl }
        let trimmed = filtered.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Untitled book" : trimmed).prefix(240))
    }

    private func failure(
        _ code: String,
        message: String = "This file could not be added."
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: .intake,
            code: code,
            message: message,
            recoveryAction: .chooseAnotherFile
        )
    }
}
