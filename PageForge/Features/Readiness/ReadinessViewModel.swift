import Foundation

@MainActor
final class ReadinessViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var report: ReadinessReport?
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var overwrite = false
    @Published var dependencyMessage: String?

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
        refreshDependencyBanner()
    }

    func setSource(_ url: URL) {
        sourceURL = url
        report = nil
        errorMessage = nil
        statusMessage = "Selected \(url.lastPathComponent)"
    }

    func refreshDependencyBanner() {
        guard let appState else { return }
        do {
            let status = try appState.dependencyService.calibreStatus()
            dependencyMessage = status.isReady
                ? nil
                : appState.setupGuidance.missingToolsMessage(status)
        } catch {
            dependencyMessage = error.localizedDescription
        }
    }

    func audit() {
        guard let appState, let sourceURL else {
            errorMessage = "Drop or choose an ebook first."
            return
        }
        let readinessService = appState.readinessService
        run(appState: appState, kind: .readinessAudit, label: "Auditing readiness") { progress in
            let report = try ReadinessAuditJob(service: readinessService).run(source: sourceURL)
            progress("Audit complete")
            return report
        }
    }

    func prepare() {
        guard let appState, let sourceURL else {
            errorMessage = "Drop or choose an ebook first."
            return
        }
        let readinessService = appState.readinessService
        run(appState: appState, kind: .readinessPrepare, label: "Preparing Kindle-ready EPUB") { [overwrite] progress in
            try ReadinessPrepareJob(service: readinessService).run(
                source: sourceURL,
                overwrite: overwrite,
                onProgress: progress
            )
        }
    }

    func openHandoff() {
        appState?.deliveryService.openHandoff()
        statusMessage = "Opened Send to Kindle handoff."
    }

    func sendPrepared() {
        guard let appState else { return }
        guard let url = report?.outputPath ?? report?.inputPath else {
            errorMessage = "No prepared file available to send."
            return
        }
        appState.openSend(with: url)
    }

    private func run(
        appState: AppState,
        kind: OperationKind,
        label: String,
        work: @escaping (@escaping (String) -> Void) throws -> ReadinessReport
    ) {
        isRunning = true
        errorMessage = nil
        statusMessage = label
        let jobID = appState.jobCoordinator.start(
            kind: kind,
            sources: [sourceURL].compactMap { $0 },
            message: label
        )

        Task.detached {
            do {
                let report = try work { message in
                    Task { @MainActor in
                        self.statusMessage = message
                        appState.jobCoordinator.update(id: jobID, message: message)
                    }
                }
                await MainActor.run {
                    self.report = report
                    self.isRunning = false
                    self.statusMessage = "Status: \(report.status.rawValue)"
                    appState.jobCoordinator.succeed(
                        id: jobID,
                        resultRef: report.outputPath?.path,
                        message: "Readiness \(report.status.rawValue)"
                    )
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
