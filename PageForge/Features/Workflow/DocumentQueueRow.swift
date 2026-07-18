import SwiftUI

struct DocumentQueueRow: View {
    let item: DocumentItem
    let onSelectionChanged: (Bool) -> Void
    let onRemove: () -> Void
    let onRetry: () -> Void
    let onReveal: () -> Void
    let onInspectMetadata: () -> Void
    let onAggressiveRepair: () -> Void

    @State private var confirmsAggressiveRepair = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Toggle("Select \(item.displayName)", isOn: Binding(
                get: { item.isSelected },
                set: onSelectionChanged
            ))
            .labelsHidden()

            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(item.format.rawValue.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.Theme.textSecondary)
                    Spacer()
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                if item.preparationState == .preparing {
                    if let fraction = item.progressFraction {
                        ProgressView(value: fraction) {
                            Text(item.progressMessage ?? "Preparing")
                        }
                    } else {
                        ProgressView {
                            Text(item.progressMessage ?? "Preparing")
                        }
                    }
                } else if let issue = item.issue {
                    Text(issue.message)
                        .font(.callout)
                        .foregroundStyle(Color.Theme.destructive)
                } else if let message = item.progressMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(Color.Theme.textSecondary)
                }

                if let output = item.preparedOutput {
                    Button(output.outputURL.lastPathComponent, action: onReveal)
                        .buttonStyle(.link)
                        .help("Reveal prepared output in Finder")
                }
                if let save = item.saveResult {
                    Text(save.message)
                        .font(.caption)
                        .foregroundStyle(save.state == .succeeded ? Color.Theme.success : Color.Theme.warning)
                }
                if let delivery = item.deliveryResult {
                    Text(delivery.message)
                        .font(.caption)
                        .foregroundStyle(delivery.state == .succeeded ? Color.Theme.success : Color.Theme.warning)
                }
            }

            if [.failed, .needsAttention, .blocked, .cancelled].contains(item.preparationState) {
                Button("Retry", action: onRetry)
            }

            Menu {
                Button("Inspect Metadata", action: onInspectMetadata)
                if item.format == .epub {
                    Button("Aggressive Repair…", role: .destructive) {
                        confirmsAggressiveRepair = true
                    }
                }
                if item.preparedOutput != nil {
                    Button("Reveal in Finder", action: onReveal)
                }
                Divider()
                Button("Remove from Queue", role: .destructive, action: onRemove)
            } label: {
                Label("More actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(14)
        .background(Color.Theme.elementBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.Theme.elementBorder, lineWidth: 1)
        }
        .confirmationDialog(
            "Aggressive repair may change document structure. Continue?",
            isPresented: $confirmsAggressiveRepair,
            titleVisibility: .visible
        ) {
            Button("Run Aggressive Repair", role: .destructive, action: onAggressiveRepair)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var iconName: String {
        switch item.format {
        case .epub: return "book.closed"
        case .mobi: return "book.pages"
        case .pdf: return "doc.richtext"
        }
    }

    private var statusLabel: String {
        switch item.preparationState {
        case .queued: return "Queued"
        case .preparing: return "Preparing"
        case .ready: return "Ready"
        case .needsAttention: return "Needs Attention"
        case .blocked: return "Blocked"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var statusColor: Color {
        switch item.preparationState {
        case .ready: return Color.Theme.success
        case .failed, .blocked: return Color.Theme.destructive
        case .needsAttention, .cancelled: return Color.Theme.warning
        case .queued, .preparing: return Color.Theme.textSecondary
        }
    }
}
