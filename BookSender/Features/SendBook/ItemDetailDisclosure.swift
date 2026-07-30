import SwiftUI

struct ItemDetailDisclosure: View {
    let item: BatchItemPresentation
    @State private var isExpanded: Bool

    init(item: BatchItemPresentation) {
        self.item = item
        _isExpanded = State(initialValue: Self.startsExpanded(item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                    Text("Details")
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier(
                "sendBook.itemDetails.\(item.id.uuidString)"
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.findings) { finding in
                        Text(message(for: finding))
                    }
                    ForEach(item.appliedActions) { action in
                        Label(
                            actionTitle(action.action),
                            systemImage: action.verified
                                ? "checkmark"
                                : "exclamationmark"
                        )
                    }
                    if let failure = preparationFailure {
                        Text(failure.message)
                    }
                    if case .failed(let failure) = item.delivery {
                        Text(failure.message)
                    }
                    if case .deliveryUnknown = item.delivery {
                        Text(
                            "The server may have accepted this book. Check Kindle before retrying."
                        )
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.leading, 18)
            }
        }
    }

    private static func startsExpanded(_ item: BatchItemPresentation) -> Bool {
        switch item.preparation {
        case .needsAttention, .excluded:
            return true
        case .waiting, .checking, .preparing, .ready, .cancelled:
            break
        }
        switch item.delivery {
        case .failed, .deliveryUnknown:
            return true
        case .notScheduled, .sending, .submitted, .cancelled:
            return false
        }
    }

    private var preparationFailure: SanitizedFailure? {
        switch item.preparation {
        case .needsAttention(let failure), .excluded(let failure):
            failure
        case .waiting, .checking, .preparing, .ready, .cancelled:
            nil
        }
    }

    private func message(for finding: HealthFinding) -> String {
        switch finding.code {
        case .archiveUnsafePath, .archiveDuplicatePath,
             .archiveUnsupportedEntry, .archiveEncrypted,
             .archiveLimitExceeded:
            "The EPUB archive is not safe to process."
        case .mimetypeMissing, .mimetypeInvalid,
             .mimetypeNotFirst, .mimetypeCompressed:
            "The EPUB package marker needed safe reconstruction."
        case .containerMissing, .containerInvalid:
            "The EPUB container description is incomplete."
        case .packageMissing, .packageAmbiguous, .packageInvalid:
            "The EPUB package cannot be selected safely."
        case .manifestMediaTypeMismatch:
            "A resource type does not match its manifest declaration."
        case .referenceMissing, .referenceAmbiguous:
            "An internal resource reference is missing or ambiguous."
        case .encryptedContent:
            "Encrypted book content is not supported."
        case .activeContent:
            "Active book content is not safe to send automatically."
        case .remoteReference:
            "The book contains a remote resource reference."
        case .xmlUnsafe:
            "The book contains XML that cannot be processed safely."
        }
    }

    private func actionTitle(_ action: RepairAction) -> String {
        switch action {
        case .rebuildMimetype: "Rebuilt EPUB package marker"
        case .restoreContainer: "Restored EPUB container"
        case .correctMediaType: "Corrected resource type"
        case .normalizePath: "Normalized resource path"
        case .repairReference: "Repaired internal reference"
        case .normalizeXML: "Normalized EPUB XML"
        }
    }
}
