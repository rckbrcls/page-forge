import SwiftUI

struct OperationStatusView: View {
    let message: String?
    let errorMessage: String?
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRunning {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(message ?? "Working…")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusChip: View {
    let status: ReadinessStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .ready: return .green
        case .needsFixes: return .orange
        case .blocked: return .red
        }
    }
}
