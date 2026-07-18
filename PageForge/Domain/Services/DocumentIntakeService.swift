import Foundation

struct DocumentIntakeService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func intake(
        urls: [URL],
        existingIdentities: Set<String> = []
    ) -> IntakeSummary {
        var seenIdentities = existingIdentities
        var outcomes: [IntakeOutcome] = []
        outcomes.reserveCapacity(urls.count)

        for (inputIndex, originalURL) in urls.enumerated() {
            switch validate(originalURL) {
            case let .success(validated):
                guard !seenIdentities.contains(validated.canonicalIdentity) else {
                    outcomes.append(rejection(
                        for: originalURL,
                        inputIndex: inputIndex,
                        reason: .duplicate,
                        detail: "This document is already in the queue."
                    ))
                    continue
                }

                seenIdentities.insert(validated.canonicalIdentity)
                let item = DocumentItem(
                    sourceURL: originalURL,
                    canonicalIdentity: validated.canonicalIdentity,
                    displayName: originalURL.lastPathComponent,
                    format: validated.format,
                    securityAccess: SecurityScopedAccess(
                        bookmarkData: try? originalURL.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                    )
                )
                outcomes.append(IntakeOutcome(
                    originalURL: originalURL,
                    acceptedItem: item,
                    inputIndex: inputIndex
                ))
            case let .failure(failure):
                outcomes.append(rejection(
                    for: originalURL,
                    inputIndex: inputIndex,
                    reason: failure.reason,
                    detail: failure.message
                ))
            }
        }

        return IntakeSummary(outcomes: outcomes)
    }

    private func validate(_ originalURL: URL) -> Result<ValidatedDocument, IntakeFailure> {
        guard originalURL.isFileURL else {
            return .failure(IntakeFailure(
                reason: .notLocalFile,
                message: "Only local files can be added."
            ))
        }

        let resolvedURL = originalURL.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory) else {
            return .failure(IntakeFailure(
                reason: .missing,
                message: "The file no longer exists."
            ))
        }

        guard !isDirectory.boolValue else {
            return .failure(IntakeFailure(
                reason: .notRegularFile,
                message: "Folders cannot be added."
            ))
        }

        let resourceValues: URLResourceValues
        do {
            resourceValues = try resolvedURL.resourceValues(forKeys: [
                .fileResourceIdentifierKey,
                .isRegularFileKey,
                .volumeSupportsCaseSensitiveNamesKey
            ])
        } catch {
            return .failure(resourceFailure(from: error))
        }

        guard resourceValues.isRegularFile == true else {
            return .failure(IntakeFailure(
                reason: .notRegularFile,
                message: "Only regular files can be added."
            ))
        }

        guard fileManager.isReadableFile(atPath: resolvedURL.path) else {
            return .failure(IntakeFailure(
                reason: .unreadable,
                message: "The file cannot be read."
            ))
        }

        guard let format = DocumentFormat(fileExtension: resolvedURL.pathExtension) else {
            return .failure(IntakeFailure(
                reason: .unsupportedType,
                message: "Only EPUB, MOBI, and PDF documents are supported."
            ))
        }

        let identity: String
        if let resourceIdentifier = resourceValues.fileResourceIdentifier {
            identity = "resource:\(String(describing: resourceIdentifier))"
        } else {
            var canonicalPath = resolvedURL.path
            if resourceValues.volumeSupportsCaseSensitiveNames == false {
                canonicalPath = canonicalPath.lowercased()
            }
            identity = "path:\(canonicalPath)"
        }

        return .success(ValidatedDocument(
            canonicalIdentity: identity,
            format: format
        ))
    }

    private func rejection(
        for url: URL,
        inputIndex: Int,
        reason: IntakeRejectionReason,
        detail: String
    ) -> IntakeOutcome {
        let name = url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent
        return IntakeOutcome(
            originalURL: url,
            rejection: IntakeRejection(reason: reason, message: "\(name): \(detail)"),
            inputIndex: inputIndex
        )
    }

    private func resourceFailure(from error: Error) -> IntakeFailure {
        let cocoaError = error as? CocoaError
        if cocoaError?.code == .fileReadNoPermission {
            return IntakeFailure(
                reason: .accessDenied,
                message: "Access to the file was denied."
            )
        }

        return IntakeFailure(
            reason: .resolutionFailed,
            message: "The local file could not be resolved."
        )
    }
}

private extension DocumentFormat {
    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "epub": self = .epub
        case "mobi": self = .mobi
        case "pdf": self = .pdf
        default: return nil
        }
    }
}

private struct ValidatedDocument {
    let canonicalIdentity: String
    let format: DocumentFormat
}

private struct IntakeFailure: Error {
    let reason: IntakeRejectionReason
    let message: String
}
