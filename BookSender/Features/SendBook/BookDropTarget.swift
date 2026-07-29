import SwiftUI
import UniformTypeIdentifiers

struct BookDropTarget: View {
    let isBusy: Bool
    let add: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text(isTargeted ? "Drop to Add" : "Drop EPUB or PDF Books")
                .font(.headline)
            Text("You can add one book or a batch.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [7])
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drop EPUB or PDF books")
        .accessibilityIdentifier("sendBook.dropTarget")
    }
}
