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
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
