import SwiftUI

struct BatchItemRow: View {
    let item: BatchItemPresentation
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.format == .epub ? "book.closed" : "doc.richtext")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(item.format?.rawValue.uppercased() ?? "FILE")
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
            .buttonStyle(.borderless)
            .disabled(!canRemove)
            .accessibilityLabel("Remove \(item.displayName)")
            .accessibilityIdentifier(
                "sendBook.item.remove.\(item.id.uuidString)"
            )
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayName), \(statusTitle)")
        .accessibilityIdentifier("sendBook.item.\(item.id.uuidString)")
    }

    @ViewBuilder
    private var status: some View {
        switch rowState {
        case .checking:
            Label("Checking", systemImage: "magnifyingglass")
        case .preparing:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Preparing")
        case .ready:
            Label("Ready", systemImage: "checkmark.circle")
        case .needsAttention:
            Label("Needs Attention", systemImage: "exclamationmark.triangle")
        case .sending:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Sending")
        case .submitted:
            Label("Submitted", systemImage: "checkmark.circle.fill")
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle")
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle")
        case .deliveryUnknown:
            Label("Delivery Unknown", systemImage: "questionmark.circle")
        }
    }

    private var rowState: RowState {
        switch item.delivery {
        case .submitted:
            return .submitted
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        case .deliveryUnknown:
            return .deliveryUnknown
        case .sending:
            return .sending
        case .notScheduled:
            switch item.preparation {
            case .waiting, .checking:
                return .checking
            case .preparing:
                return .preparing
            case .ready:
                return .ready
            case .needsAttention, .excluded:
                return .needsAttention
            case .cancelled:
                return .cancelled
            }
        }
    }

    private var statusTitle: String {
        switch rowState {
        case .checking: "Checking"
        case .preparing: "Preparing"
        case .ready: "Ready"
        case .needsAttention: "Needs Attention"
        case .sending: "Sending"
        case .submitted: "Submitted"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .deliveryUnknown: "Delivery Unknown"
        }
    }

    private var statusColor: Color {
        switch rowState {
        case .submitted: .green
        case .needsAttention, .failed, .deliveryUnknown: .orange
        default: .secondary
        }
    }

    private enum RowState {
        case checking
        case preparing
        case ready
        case needsAttention
        case sending
        case submitted
        case failed
        case cancelled
        case deliveryUnknown
    }
}
