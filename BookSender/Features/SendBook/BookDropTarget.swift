import SwiftUI
import UniformTypeIdentifiers

struct BookDropTarget: View {
    let isBusy: Bool
    let disabledReason: String?
    let choose: () -> Void
    let add: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .font(.title)
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                Text(isTargeted ? "Drop to Add" : "Drop EPUB or PDF Books")
                    .font(.headline)
                Text("You can add one book or a batch.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 180)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted
                        ? Color.accentColor
                        : Color(nsColor: .secondaryLabelColor).opacity(0.75),
                    style: StrokeStyle(
                        lineWidth: isTargeted ? 3 : 2,
                        lineCap: .round,
                        dash: [8, 5]
                    )
                )
                .allowsHitTesting(false)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    guard let data = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                          let bytes = data as? Data,
                          let url = URL(dataRepresentation: bytes, relativeTo: nil)
                    else { continue }
                    urls.append(url)
                }
                await MainActor.run { add(urls) }
            }
            return true
        }
        .disabled(isBusy)
        .accessibilityLabel("Choose or drop EPUB or PDF books")
        .accessibilityHint(
            disabledReason ?? "Opens Finder. You can also drop supported books here."
        )
        .accessibilityValue(isBusy ? "Unavailable" : "Available")
        .accessibilityIdentifier("sendBook.dropTarget")
    }
}
