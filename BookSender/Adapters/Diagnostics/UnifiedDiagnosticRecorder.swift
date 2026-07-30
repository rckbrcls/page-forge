import Foundation
import OSLog

enum DiagnosticLogLevel: Equatable, Sendable {
    case error
    case fault
}

enum DiagnosticLogCategory: String, Equatable, Sendable {
    case application
    case setup
    case intake
    case preparation
    case delivery
    case shortcut
}

struct UnifiedDiagnosticFields: Equatable, Sendable {
    let eventID: UUID
    let occurredAtMilliseconds: Int64
    let action: FeedbackAction
    let outcome: DiagnosticOutcome
    let code: DiagnosticCode
    let family: FailureFamily
    let phase: DiagnosticPhase
    let severity: DiagnosticSeverity
    let retryDisposition: RetryDisposition
    let providerStatus: ProviderStatus?
    let appVersion: String
    let operationID: UUID?
    let setupRevision: Int?
    let batchTotal: Int?
    let batchCompleted: Int?
    let transmissionStarted: Bool?
    let safetyLimit: SafetyLimitIdentifier?
    let occurrenceCount: Int
}

struct UnifiedDiagnosticRecorder: DiagnosticRecording {
    typealias Sink = @Sendable (
        DiagnosticLogLevel,
        DiagnosticLogCategory,
        UnifiedDiagnosticFields
    ) async -> Void

    private let sink: Sink

    init(
        subsystem: String = "com.rckbrcls.BookSender"
    ) {
        let application = Logger(
            subsystem: subsystem,
            category: DiagnosticLogCategory.application.rawValue
        )
        let setup = Logger(
            subsystem: subsystem,
            category: DiagnosticLogCategory.setup.rawValue
        )
        let intake = Logger(
            subsystem: subsystem,
            category: DiagnosticLogCategory.intake.rawValue
        )
        let preparation = Logger(
            subsystem: subsystem,
            category: DiagnosticLogCategory.preparation.rawValue
        )
        let delivery = Logger(
            subsystem: subsystem,
            category: DiagnosticLogCategory.delivery.rawValue
        )
        let shortcut = Logger(
            subsystem: subsystem,
            category: DiagnosticLogCategory.shortcut.rawValue
        )
        sink = { level, category, fields in
            let logger = switch category {
            case .application: application
            case .setup: setup
            case .intake: intake
            case .preparation: preparation
            case .delivery: delivery
            case .shortcut: shortcut
            }
            Self.write(fields, level: level, logger: logger)
        }
    }

    init(sink: @escaping Sink) {
        self.sink = sink
    }

    func record(_ event: DiagnosticEvent) async {
        let fields = fields(for: event)
        await sink(
            level(for: fields),
            category(for: fields),
            fields
        )
    }

    private func fields(for event: DiagnosticEvent) -> UnifiedDiagnosticFields {
        let evidence = event.failure.evidence
        let context = evidence.context
        return UnifiedDiagnosticFields(
            eventID: event.id,
            occurredAtMilliseconds: Int64(
                event.occurredAt.timeIntervalSince1970 * 1_000
            ),
            action: event.action,
            outcome: event.outcome,
            code: event.failure.code,
            family: event.failure.family,
            phase: evidence.phase,
            severity: evidence.severity,
            retryDisposition: evidence.retryDisposition,
            providerStatus: evidence.providerStatus,
            appVersion: validatedVersion(context.appVersion),
            operationID: context.operationID,
            setupRevision: context.setupRevision,
            batchTotal: context.batchTotal,
            batchCompleted: context.batchCompleted,
            transmissionStarted: context.transmissionStarted,
            safetyLimit: context.safetyLimit,
            occurrenceCount: event.occurrenceCount
        )
    }

    private func validatedVersion(_ value: String?) -> String {
        guard let value,
              !value.isEmpty,
              value.count <= 64,
              value.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics
                      .union(CharacterSet(charactersIn: ".+-"))
                      .contains($0)
              })
        else {
            return "unknown"
        }
        return value
    }

    private func level(
        for fields: UnifiedDiagnosticFields
    ) -> DiagnosticLogLevel {
        fields.severity == .critical
            && fields.phase == .bootstrap
            ? .fault
            : .error
    }

    private func category(
        for fields: UnifiedDiagnosticFields
    ) -> DiagnosticLogCategory {
        if fields.phase == .bootstrap || fields.phase == .updateCheck {
            return .application
        }
        switch fields.family {
        case .credential:
            return .setup
        case .intake:
            return .intake
        case .archive, .xml, .audit, .repair, .filesystem:
            return .preparation
        case .delivery:
            return .delivery
        case .shortcut:
            return .shortcut
        }
    }

    private static func write(
        _ fields: UnifiedDiagnosticFields,
        level: DiagnosticLogLevel,
        logger: Logger
    ) {
        let eventID = fields.eventID.uuidString
        let operationID = fields.operationID?.uuidString ?? "-"
        let providerCode = fields.providerStatus?.replyCode ?? 0
        let enhancedStatus =
            fields.providerStatus?.enhancedStatus?.description ?? "-"
        let setupRevision = fields.setupRevision ?? 0
        let batchTotal = fields.batchTotal ?? 0
        let batchCompleted = fields.batchCompleted ?? 0
        let transmissionStarted = fields.transmissionStarted ?? false
        let safetyLimit = fields.safetyLimit?.rawValue ?? "-"
        switch level {
        case .error:
            logger.error(
                """
                terminal event=\(eventID, privacy: .public) operation=\(operationID, privacy: .public) time_ms=\(fields.occurredAtMilliseconds, privacy: .public) app_version=\(fields.appVersion, privacy: .public) action=\(fields.action.rawValue, privacy: .public) outcome=\(fields.outcome.rawValue, privacy: .public) code=\(fields.code.rawValue, privacy: .public) family=\(fields.family.rawValue, privacy: .public) phase=\(fields.phase.rawValue, privacy: .public) severity=\(fields.severity.rawValue, privacy: .public) retry=\(fields.retryDisposition.rawValue, privacy: .public) provider_code=\(providerCode, privacy: .public) enhanced_status=\(enhancedStatus, privacy: .public) setup_revision=\(setupRevision, privacy: .public) batch_completed=\(batchCompleted, privacy: .public) batch_total=\(batchTotal, privacy: .public) transmission_started=\(transmissionStarted, privacy: .public) safety_limit=\(safetyLimit, privacy: .public) occurrence_count=\(fields.occurrenceCount, privacy: .public)
                """
            )
        case .fault:
            logger.fault(
                """
                terminal event=\(eventID, privacy: .public) operation=\(operationID, privacy: .public) time_ms=\(fields.occurredAtMilliseconds, privacy: .public) app_version=\(fields.appVersion, privacy: .public) action=\(fields.action.rawValue, privacy: .public) outcome=\(fields.outcome.rawValue, privacy: .public) code=\(fields.code.rawValue, privacy: .public) family=\(fields.family.rawValue, privacy: .public) phase=\(fields.phase.rawValue, privacy: .public) severity=\(fields.severity.rawValue, privacy: .public) retry=\(fields.retryDisposition.rawValue, privacy: .public) provider_code=\(providerCode, privacy: .public) enhanced_status=\(enhancedStatus, privacy: .public) setup_revision=\(setupRevision, privacy: .public) batch_completed=\(batchCompleted, privacy: .public) batch_total=\(batchTotal, privacy: .public) transmission_started=\(transmissionStarted, privacy: .public) safety_limit=\(safetyLimit, privacy: .public) occurrence_count=\(fields.occurrenceCount, privacy: .public)
                """
            )
        }
    }
}
