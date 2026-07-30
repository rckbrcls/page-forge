import Foundation

actor BookDeliveryService {
    private let credentials: any CredentialStoring
    private let transport: any SMTPDelivering

    init(
        credentials: any CredentialStoring,
        transport: any SMTPDelivering
    ) {
        self.credentials = credentials
        self.transport = transport
    }

    func deliver(
        _ item: ConfirmedBatchItem,
        in snapshot: ConfirmedBatchSnapshot,
        progress: @escaping @Sendable (DeliveryProgress) async -> Void
    ) async -> TerminalOutcome {
        do {
            try Task.checkCancellation()
            guard await credentials.exists(
                snapshot.setup.credentialReference
            ) else {
                return .failed(
                    failure(
                        .credentialMissing,
                        message: "Delivery setup no longer has a usable credential.",
                        recoveryAction: .editSetup
                    )
                )
            }

            let credential = try await credentials.read(
                snapshot.setup.credentialReference
            )
            // The scoped value is released after this attempt and is never
            // copied into presentation, events, attempts, or persistence.
            let book = PreparedBook(
                id: UUID(),
                batchItemID: item.id,
                file: item.preparedFile,
                originalDisplayName: item.displayName,
                format: item.format,
                byteCount: item.byteCount,
                contentDigest: item.contentDigest,
                comparison: nil
            )
            return await transport.send(
                book: book,
                setup: snapshot.setup,
                credential: credential,
                progress: progress
            )
        } catch is CancellationError {
            return .cancelled
        } catch let sanitized as SanitizedFailure {
            return .failed(sanitized)
        } catch {
            return .failed(failure(.deliveryFailed))
        }
    }

    func cancelActiveAttempt() async {
        await transport.cancelActiveAttempt()
    }

    private func failure(
        _ code: DiagnosticCode,
        message: String = "This book could not be delivered.",
        recoveryAction: RecoveryAction = .retryFailed
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: code,
            message: message,
            recoveryAction: recoveryAction
        )
    }
}
