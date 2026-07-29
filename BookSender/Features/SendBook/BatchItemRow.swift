import SwiftUI

struct BatchItemRow: View {
    let item: BatchItem
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.format == .epub ? "book.closed" : "doc.richtext")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(item.format.rawValue.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            status
                .font(.callout)
                .foregroundStyle(statusColor)
            Button(action: remove) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(item.displayName)")
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sendBook.item.\(item.id.uuidString)")
    }

    @ViewBuilder
    private var status: some View {
        switch item.delivery {
        case .submitted: Label("Submitted", systemImage: "checkmark.circle.fill")
        case .failed: Label("Failed", systemImage: "exclamationmark.circle")
        case .cancelled: Label("Cancelled", systemImage: "xmark.circle")
        case .deliveryUnknown: Label("Delivery Unknown", systemImage: "questionmark.circle")
        case .sending: ProgressView().controlSize(.small).accessibilityLabel("Sending")
        case .notScheduled:
            switch item.preparation {
            case .waiting, .checking: Label("Checking", systemImage: "magnifyingglass")
            case .preparing: ProgressView().controlSize(.small).accessibilityLabel("Preparing")
            case .ready: Label("Ready", systemImage: "checkmark.circle")
            case .needsAttention, .excluded: Label("Needs Attention", systemImage: "exclamationmark.triangle")
            case .cancelled: Label("Cancelled", systemImage: "xmark.circle")
            }
        }
    }

    private var statusColor: Color {
        switch item.delivery {
        case .submitted: .green
        case .failed, .deliveryUnknown: .orange
        default:
            switch item.preparation {
            case .needsAttention, .excluded: .orange
            default: .secondary
            }
        }
    }
}
