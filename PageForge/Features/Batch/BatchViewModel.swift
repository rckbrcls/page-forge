import Foundation

@MainActor
final class BatchViewModel: ObservableObject {
    enum Operation: String, CaseIterable, Identifiable {
        case readinessAudit = "Readiness audit"
        case readinessPrepare = "Readiness prepare"
        case convertToEpub = "Convert to EPUB"
        case repairSafe = "Safe repair"

        var id: String { rawValue }
    }

    @Published var folderURL: URL?
    @Published var outputDirectory: URL?
    @Published var operation: Operation = .readinessAudit
    @Published var overwrite = false
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var summary: String?

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
    }

    func setFolder(_ url: URL) {
        folderURL = url
        summary = nil
        errorMessage = nil
        statusMessage = "Selected folder \(url.lastPathComponent)"
    }

    func setOutputDirectory(_ url: URL) {
        outputDirectory = url
    }

    func run() {
        guard let appState, let folderURL else {
            errorMessage = "Choose a folder first."
            return
        }
        if operation == .readinessPrepare && outputDirectory == nil {
            errorMessage = "Choose an output directory for prepare/convert/repair batch writes."
            return
        }

        isRunning = true
        errorMessage = nil
        summary = nil
        let jobID = appState.jobCoordinator.start(kind: .batchReadiness, sources: [folderURL], message: operation.rawValue)
        let op = operation
        let outputDirectory = outputDirectory
        let overwrite = overwrite

        Task.detached {
            do {
                let summary: String
                switch op {
                case .readinessAudit:
                    let result = try BatchJobRunner().readinessBatch(
                        folder: folderURL,
                        prepare: false,
                        outputDirectory: nil,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    summary = "Ready \(result.readyCount), needs_fixes \(result.needsFixesCount), blocked \(result.blockedCount), skipped \(result.skipped.count), failures \(result.failures.count)"
                case .readinessPrepare:
                    let result = try BatchJobRunner().readinessBatch(
                        folder: folderURL,
                        prepare: true,
                        outputDirectory: outputDirectory,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    summary = "Prepared \(result.reports.count). Ready \(result.readyCount), needs_fixes \(result.needsFixesCount), blocked \(result.blockedCount), failures \(result.failures.count)"
                case .convertToEpub:
                    let result = try BatchJobRunner().convertBatch(
                        folder: folderURL,
                        target: .epub,
                        outputDirectory: outputDirectory,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    summary = "Converted \(result.results.count), skipped \(result.skipped.count), failures \(result.failures.count)"
                case .repairSafe:
                    let result = try BatchJobRunner().repairBatch(
                        folder: folderURL,
                        mode: .safe,
                        outputDirectory: outputDirectory,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    summary = "Repaired \(result.results.count), skipped \(result.skipped.count), failures \(result.failures.count)"
                }
                await MainActor.run {
                    self.isRunning = false
                    self.summary = summary
                    self.statusMessage = "Batch complete"
                    appState.jobCoordinator.succeed(id: jobID, message: summary)
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
