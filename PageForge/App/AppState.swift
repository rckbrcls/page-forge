import Foundation
import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case readiness = "Readiness"
    case convert = "Convert"
    case batch = "Batch"
    case send = "Send"
    case metadata = "Metadata"
    case settings = "Settings"
    case logs = "Logs"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .readiness: return "stethoscope"
        case .convert: return "arrow.triangle.2.circlepath"
        case .batch: return "folder.badge.gearshape"
        case .send: return "paperplane"
        case .metadata: return "text.book.closed"
        case .settings: return "gearshape"
        case .logs: return "doc.text.magnifyingglass"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var destination: AppDestination = .readiness
    @Published var pendingSendURL: URL?

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
        self.logService = logs
        self.jobCoordinator = OperationJobCoordinator(logService: logs)
        self.dependencyService = DependencyService()
        self.conversionService = ConversionService()
        self.repairService = RepairService()
        self.readinessService = ReadinessService(
            conversionService: ConversionService(),
            repairService: RepairService()
        )
        self.metadataService = MetadataService()
        self.configService = ConfigService()
        self.secretService = SecretService()
        self.deliveryService = DeliveryService(
            configService: ConfigService(),
            secretService: SecretService()
        )
        self.setupGuidance = SetupGuidanceService()
    }

    func openSend(with url: URL) {
        pendingSendURL = url
        destination = .send
    }
}
