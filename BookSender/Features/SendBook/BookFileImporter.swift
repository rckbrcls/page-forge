import SwiftUI
import UniformTypeIdentifiers

struct BookFileImporter: ViewModifier {
    @Binding var isPresented: Bool
    let add: ([URL]) -> Void
    let failed: () -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "epub") ?? .data,
                .pdf
            ],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                add(urls)
            } else {
                failed()
            }
        }
    }
}
