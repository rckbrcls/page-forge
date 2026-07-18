import Foundation

@MainActor
final class SendViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var profiles: [DeliveryProfile] = []
    @Published var selectedProfileName: String = "default"
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var lastResult: SendResult?

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
        reloadProfiles()
        if let pending = appState.pendingSendURL {
            sourceURL = pending
            appState.pendingSendURL = nil
        }
    }

    func setSource(_ url: URL) {
        sourceURL = url
        errorMessage = nil
        statusMessage = "Selected \(url.lastPathComponent)"
    }

    func reloadProfiles() {
        guard let appState else { return }
        do {
            let config = try appState.configService.load()
            profiles = config.profiles.values.sorted { $0.name < $1.name }
            selectedProfileName = config.defaultProfile
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() {
        guard let appState, let sourceURL else {
            errorMessage = "Choose a file to send."
            return
        }
        isRunning = true
        errorMessage = nil
        let jobID = appState.jobCoordinator.start(kind: .send, sources: [sourceURL], message: "Sending to Kindle")
        let profileName = selectedProfileName
        let deliveryService = appState.deliveryService
        Task.detached {
            do {
                let result = try deliveryService.send(source: sourceURL, profileName: profileName)
                await MainActor.run {
                    self.lastResult = result
                    self.isRunning = false
                    self.statusMessage = "Sent to \(result.kindleEmail) via \(result.profileName)"
                    appState.jobCoordinator.succeed(id: jobID, message: self.statusMessage ?? "Sent")
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

    func openHandoff() {
        appState?.deliveryService.openHandoff()
        statusMessage = "Opened Send to Kindle handoff."
    }

    func profileReadyLabel(for profile: DeliveryProfile) -> String {
        guard let appState else { return "unknown" }
        let ready = profile.isStructurallySendReady(
            hasSecret: appState.secretService.hasPassword(profileName: profile.name)
        )
        return ready ? "ready" : "incomplete"
    }
}
