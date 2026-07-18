import SwiftUI

struct ReadinessDependencyBanner: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calibre tools")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Color.Theme.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.Theme.warning.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.Theme.warning.opacity(0.3), lineWidth: 1)
            }
        }
    }
}
