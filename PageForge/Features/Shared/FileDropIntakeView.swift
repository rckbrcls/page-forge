import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileDropIntakeView: View {
    let title: String
    let subtitle: String
    let allowFolders: Bool
    let onPick: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.accentColor)
                .padding(14)
                .glassEffect(
                    .regular.tint(Color.accentColor.opacity(0.14)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.Theme.textPrimary)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(Color.Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Choose…") {
                presentPanel()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    isTargeted
                        ? Color.accentColor.opacity(0.12)
                        : Color.Theme.tertiaryBackground
                )
                .shadow(color: .black.opacity(0.06), radius: 24, x: 3, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isTargeted ? Color.accentColor : Color.Theme.border,
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func presentPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowFolders
        panel.allowsMultipleSelection = true
        if !allowFolders {
            panel.allowedContentTypes = [
                .pdf,
                UTType(filenameExtension: "epub") ?? .data,
                UTType(filenameExtension: "mobi") ?? .data,
            ]
        }
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            onPick(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        FileURLDropResolver.resolve(providers, completion: onPick)
    }
}

enum FileURLDropResolver {
    static func resolve(
        _ providers: [NSItemProvider],
        completion: @escaping ([URL]) -> Void
    ) -> Bool {
        guard !providers.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var resolved = Array<URL?>(repeating: nil, count: providers.count)

        for (index, provider) in providers.enumerated() {
            group.enter()
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                } else {
                    url = nil
                }
                lock.lock()
                resolved[index] = url
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(resolved.compactMap { $0 })
        }
        return true
    }
}
