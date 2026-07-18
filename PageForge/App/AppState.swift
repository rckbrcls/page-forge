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
    let setupGuidance: SetupGuidanceService

    init() {
        let logs = LogService()
        let dependencies = DependencyService()
        let conversion = ConversionService(dependencyService: dependencies)
        let repair = RepairService(dependencyService: dependencies)
        let config = ConfigService()
        let secrets = SecretService()

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
        self.setupGuidance = SetupGuidanceService()
    }

}
