import Foundation

@MainActor
final class MetadataViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var titleText = ""
    @Published var authorText = ""
    @Published var raw = ""
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
    }

    func setSource(_ url: URL) {
        sourceURL = url
        errorMessage = nil
        statusMessage = "Selected \(url.lastPathComponent)"
    }

    func inspect() {
        guard let appState, let sourceURL else {
            errorMessage = "Choose a book first."
            return
        }
        isRunning = true
        errorMessage = nil
        let jobID = appState.jobCoordinator.start(kind: .metadataInspect, sources: [sourceURL], message: "Inspecting metadata")
        let metadataService = appState.metadataService
        Task.detached {
            do {
                let metadata = try MetadataJobRunner(service: metadataService).inspect(source: sourceURL)
                await MainActor.run {
                    self.titleText = metadata.title
                    self.authorText = metadata.author
                    self.raw = metadata.raw
                    self.isRunning = false
                    self.statusMessage = "Metadata loaded"
                    appState.jobCoordinator.succeed(id: jobID, message: "Metadata loaded")
                }
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.errorMessage = error.localizedDescription
                    appState.jobCoordinator.fail(id: jobID, message: error.localizedDescription)
                }
            }
        }
    }

    func update() {
        guard let appState, let sourceURL else {
            errorMessage = "Choose a book first."
            return
        }
        isRunning = true
        errorMessage = nil
        let jobID = appState.jobCoordinator.start(kind: .metadataUpdate, sources: [sourceURL], message: "Updating metadata")
        let title = titleText
        let author = authorText
        let metadataService = appState.metadataService
        Task.detached {
            do {
                let metadata = try MetadataJobRunner(service: metadataService).update(
                    source: sourceURL,
                    title: title,
                    author: author
                )
                await MainActor.run {
                    self.titleText = metadata.title
                    self.authorText = metadata.author
                    self.raw = metadata.raw
                    self.isRunning = false
                    self.statusMessage = "Metadata updated"
                    appState.jobCoordinator.succeed(id: jobID, message: "Metadata updated")
                }
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.errorMessage = error.localizedDescription
                    appState.jobCoordinator.fail(id: jobID, message: error.localizedDescription)
                }
            }
        }
    }
}
