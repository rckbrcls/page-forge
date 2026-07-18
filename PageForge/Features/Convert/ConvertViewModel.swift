import Foundation

@MainActor
final class ConvertViewModel: ObservableObject {
    enum Operation: String, CaseIterable, Identifiable {
        case mobiToEpub = "MOBI → EPUB"
        case pdfToEpub = "PDF → EPUB"
        case epubToMobi = "EPUB → MOBI"
        case safeRepair = "Safe repair"
        case aggressiveRepair = "Aggressive repair"

        var id: String { rawValue }
    }

    @Published var sourceURL: URL?
    @Published var operation: Operation = .mobiToEpub
    @Published var overwrite = false
    @Published var confirmAggressive = false
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var outputPath: URL?

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
    }

    func setSource(_ url: URL) {
        sourceURL = url
        outputPath = nil
        errorMessage = nil
        statusMessage = "Selected \(url.lastPathComponent)"
    }

    func run() {
        guard let appState, let sourceURL else {
            errorMessage = "Drop or choose a file first."
            return
        }
        if operation == .aggressiveRepair && !confirmAggressive {
            errorMessage = "Confirm aggressive repair before running."
            return
        }

        isRunning = true
        errorMessage = nil
        let kind: OperationKind = (operation == .safeRepair || operation == .aggressiveRepair) ? .repair : .convert
        let jobID = appState.jobCoordinator.start(kind: kind, sources: [sourceURL], message: operation.rawValue)

        let op = operation
        let overwrite = overwrite
        let conversionService = appState.conversionService
        let repairService = appState.repairService
        Task.detached {
            do {
                let output: URL
                switch op {
                case .mobiToEpub, .pdfToEpub:
                    let result = try ConversionJobRunner(service: conversionService).run(
                        source: sourceURL,
                        target: .epub,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    output = result.outputPath
                case .epubToMobi:
                    let result = try ConversionJobRunner(service: conversionService).run(
                        source: sourceURL,
                        target: .mobi,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    output = result.outputPath
                case .safeRepair, .aggressiveRepair:
                    let result = try RepairJobRunner(service: repairService).run(
                        source: sourceURL,
                        mode: op == .safeRepair ? .safe : .aggressive,
                        overwrite: overwrite
                    ) { message in
                        Task { @MainActor in
                            self.statusMessage = message
                            appState.jobCoordinator.update(id: jobID, message: message)
                        }
                    }
                    output = result.outputPath
                }
                await MainActor.run {
                    self.outputPath = output
                    self.isRunning = false
                    self.statusMessage = "Wrote \(output.lastPathComponent)"
                    appState.jobCoordinator.succeed(id: jobID, resultRef: output.path, message: self.statusMessage ?? "Done")
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
