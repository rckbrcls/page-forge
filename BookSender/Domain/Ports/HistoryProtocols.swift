import Foundation

protocol SendHistoryStoring: Sendable {
    func load() async throws -> [SubmissionRecord]
    func replace(with records: [SubmissionRecord]) async throws
    func clear() async throws
}
