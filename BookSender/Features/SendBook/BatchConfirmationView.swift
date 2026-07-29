import SwiftUI

struct BatchConfirmationView: View {
    let destination: String
    let eligibleCount: Int
    let excludedCount: Int
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Send Books?")
                .font(.title2)
            Text("Book Sender will send \(eligibleCount) \(eligibleCount == 1 ? "book" : "books") to \(destination).")
            if excludedCount > 0 {
                Text("\(excludedCount) \(excludedCount == 1 ? "item is" : "items are") not ready and will not be sent.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Send", action: confirm)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("sendBook.confirm")
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
