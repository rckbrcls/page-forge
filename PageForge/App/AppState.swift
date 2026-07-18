import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let logService: LogService
    let jobCoordinator: OperationJobCoordinator
    let dependencyService: DependencyService
    let readinessService: ReadinessService
    let conversionService: ConversionService
    let repairService: RepairService
    let metadataService: MetadataService
    let configService: ConfigService
    let secretService: SecretService
    let deliveryService: DeliveryService
    let calibreManagementService: CalibreManagementService

    @Published private(set) var calibreStatus = DependencyStatus()
    @Published private(set) var calibreAction: CalibreManagementAction?
    @Published private(set) var isCheckingCalibre = false
    @Published private(set) var isManagingCalibre = false
    @Published private(set) var calibreMessage: String?

    init() {
        let logs = LogService()
        let dependencies = DependencyService()
        let conversion = ConversionService(dependencyService: dependencies)
        let repair = RepairService(dependencyService: dependencies)
        let config = ConfigService()
        let secrets = SecretService()
        let calibreManagement = CalibreManagementService()

        self.logService = logs
        self.jobCoordinator = OperationJobCoordinator(logService: logs)
        self.dependencyService = dependencies
        self.conversionService = conversion
        self.repairService = repair
        self.readinessService = ReadinessService(
            conversionService: conversion,
            repairService: repair
        )
        self.metadataService = MetadataService()
        self.configService = config
        self.secretService = secrets
        self.deliveryService = DeliveryService(
            configService: config,
            secretService: secrets
        )
        self.calibreManagementService = calibreManagement
        self.calibreStatus = (try? dependencies.calibreStatus()) ?? DependencyStatus()
    }

    func refreshCalibre(clearMessage: Bool = true) {
        guard !isCheckingCalibre, !isManagingCalibre else { return }
        isCheckingCalibre = true
        if clearMessage {
            calibreMessage = nil
        }

        let status = (try? dependencyService.calibreStatus()) ?? DependencyStatus()
        calibreStatus = status
        let service = calibreManagementService

        Task.detached { [weak self] in
            let action = service.recommendedAction(for: status)
            await self?.finishCalibreCheck(status: status, action: action)
        }
    }

    func performCalibreAction(_ action: CalibreManagementAction) {
        guard !isManagingCalibre else { return }
        guard action.command != nil else { return }

        isManagingCalibre = true
        calibreMessage = action.purpose == .install
            ? "Installing Calibre…"
            : "Updating Calibre…"

        let service = calibreManagementService
        Task.detached { [weak self] in
            do {
                let details = try service.perform(action)
                await self?.finishCalibreManagement(action: action, details: details, error: nil)
            } catch {
                await self?.finishCalibreManagement(
                    action: action,
                    details: nil,
                    error: error.localizedDescription
                )
            }
        }
    }

    private func finishCalibreCheck(
        status: DependencyStatus,
        action: CalibreManagementAction
    ) {
        calibreStatus = status
        calibreAction = action
        isCheckingCalibre = false
    }

    private func finishCalibreManagement(
        action: CalibreManagementAction,
        details: String?,
        error: String?
    ) {
        isManagingCalibre = false

        if let error {
            calibreMessage = action.purpose == .install
                ? "Couldn’t install Calibre."
                : "Couldn’t update Calibre."
            logService.append(level: .error, message: error)
            return
        }

        if details != nil {
            let message = action.purpose == .install
                ? "Calibre installation finished."
                : "Calibre update finished."
            logService.append(level: .info, message: message)
        }
        calibreMessage = nil
        refreshCalibre(clearMessage: false)
    }
}
