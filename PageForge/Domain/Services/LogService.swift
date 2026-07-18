import Foundation

@MainActor
final class LogService: ObservableObject {
    @Published private(set) var entries: [OperationLogEntry] = []

    func append(level: LogLevel, message: String, operationId: UUID? = nil) {
        let entry = OperationLogEntry(level: level, operationId: operationId, message: message)
        entries.insert(entry, at: 0)
        if entries.count > 500 {
            entries = Array(entries.prefix(500))
        }
    }

    func recent(limit: Int = 100) -> [OperationLogEntry] {
        Array(entries.prefix(limit))
    }
}
