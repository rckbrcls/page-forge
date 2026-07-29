import Foundation

struct PDFEligibilityService: PDFEligibilityChecking {
    private let workspaceStore: any WorkspaceStoring
    private let limits: SafetyLimits

    init(
        workspaceStore: any WorkspaceStoring,
        limits: SafetyLimits = .standard
    ) {
        self.workspaceStore = workspaceStore
        self.limits = limits
    }

    func prepare(
        itemID: UUID,
        source: StagedFileReference,
        displayName: String
    ) async -> PreparationResult {
        let plan = PreparationPlan(
            id: UUID(),
            originalAuditIdentifier: UUID(),
            actions: [],
            decision: .deliverImmutablePDFSnapshot
        )
        do {
            try Task.checkCancellation()
            let values = try source.url.resourceValues(forKeys: [
                .isRegularFileKey,
                .fileSizeKey,
            ])
            let byteCount = Int64(values.fileSize ?? 0)
            guard values.isRegularFile == true,
                  byteCount > 0,
                  limits.permitsAttachmentBytes(byteCount)
            else {
                throw failure(
                    "pdf.size",
                    message: "This PDF is outside the delivery size limit."
                )
            }

            let handle = try FileHandle(forReadingFrom: source.url)
            defer { try? handle.close() }
            let signature = try handle.read(upToCount: 8) ?? Data()
            let signatureText = String(decoding: signature, as: UTF8.self)
            guard signatureText.hasPrefix("%PDF-"),
                  signatureText.dropFirst(5).prefix(3)
                    .allSatisfy({ $0.isNumber || $0 == "." })
            else {
                throw failure(
                    "pdf.signature",
                    message: "This file does not contain a valid PDF signature."
                )
            }
            let tailLength = min(byteCount, 1_024)
            try handle.seek(toOffset: UInt64(byteCount - tailLength))
            let tail = try handle.read(upToCount: Int(tailLength)) ?? Data()
            guard String(decoding: tail, as: UTF8.self).contains("%%EOF") else {
                throw failure(
                    "pdf.structure",
                    message: "This PDF does not contain a complete file ending."
                )
            }

            let digest = try await workspaceStore.digest(of: source)
            let prepared = PreparedBook(
                id: UUID(),
                batchItemID: itemID,
                file: source,
                originalDisplayName: displayName,
                format: .pdf,
                byteCount: byteCount,
                contentDigest: digest,
                comparison: nil
            )
            return PreparationResult(
                originalReport: nil,
                plan: plan,
                appliedActions: [],
                preparedReport: nil,
                comparison: nil,
                preparedBook: prepared,
                failure: nil
            )
        } catch is CancellationError {
            return blocked(
                plan: plan,
                failure: SanitizedFailure(
                    family: .intake,
                    code: "pdf.cancelled",
                    message: "PDF preparation was cancelled.",
                    recoveryAction: nil
                )
            )
        } catch let sanitized as SanitizedFailure {
            return blocked(plan: plan, failure: sanitized)
        } catch {
            return blocked(plan: plan, failure: failure("pdf.read"))
        }
    }

    private func blocked(
        plan: PreparationPlan,
        failure: SanitizedFailure
    ) -> PreparationResult {
        PreparationResult(
            originalReport: nil,
            plan: plan,
            appliedActions: [],
            preparedReport: nil,
            comparison: nil,
            preparedBook: nil,
            failure: failure
        )
    }

    private func failure(
        _ code: String,
        message: String = "This PDF could not be prepared safely."
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: .intake,
            code: code,
            message: message,
            recoveryAction: .chooseAnotherFile
        )
    }
}
