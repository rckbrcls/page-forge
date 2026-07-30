import Foundation

actor FileSendHistoryStore: SendHistoryStoring {
    static let maximumFileBytes = 1_048_576

    private let fileManager: FileManager
    private let rootURL: URL
    nonisolated let fileURL: URL

    init(
        rootURL: URL,
        fileManager: FileManager = .default
    ) {
        let standardizedRoot = rootURL.standardizedFileURL
        self.rootURL = standardizedRoot
        fileURL = standardizedRoot.appending(component: "history-v1.json")
        self.fileManager = fileManager
    }

    func load() throws -> [SubmissionRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let attributes = try fileManager.attributesOfItem(
                atPath: fileURL.path
            )
            guard let size = attributes[.size] as? NSNumber,
                  size.intValue <= Self.maximumFileBytes
            else {
                throw HistoryFailure(operation: .load, code: .limit)
            }
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            guard data.count <= Self.maximumFileBytes else {
                throw HistoryFailure(operation: .load, code: .limit)
            }
            let envelope = try JSONDecoder().decode(
                SendHistoryEnvelope.self,
                from: data
            )
            guard envelope.schemaVersion
                    == SendHistoryEnvelope.currentSchemaVersion
            else {
                throw HistoryFailure(
                    operation: .load,
                    code: .unsupportedSchema
                )
            }
            guard envelope.records.count <= SendHistoryService.maximumRecords
            else {
                throw HistoryFailure(operation: .load, code: .limit)
            }
            guard Set(envelope.records.map(\.id)).count
                    == envelope.records.count
            else {
                throw HistoryFailure(operation: .load, code: .decode)
            }
            return envelope.records
        } catch let failure as HistoryFailure {
            throw failure
        } catch is DecodingError {
            throw HistoryFailure(operation: .load, code: .decode)
        } catch {
            throw HistoryFailure(operation: .load, code: .read)
        }
    }

    func replace(with records: [SubmissionRecord]) throws {
        guard records.count <= SendHistoryService.maximumRecords else {
            throw HistoryFailure(operation: .record, code: .limit)
        }
        do {
            try ensureRootDirectory()
            let data = try JSONEncoder().encode(
                SendHistoryEnvelope(records: records)
            )
            guard data.count <= Self.maximumFileBytes else {
                throw HistoryFailure(operation: .record, code: .limit)
            }
            let temporaryURL = rootURL.appending(
                component: ".history-\(UUID().uuidString).tmp"
            )
            defer {
                try? fileManager.removeItem(at: temporaryURL)
            }
            try data.write(to: temporaryURL, options: [.withoutOverwriting])
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: temporaryURL.path
            )
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(
                    fileURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } else {
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
            }
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch let failure as HistoryFailure {
            throw failure
        } catch {
            throw HistoryFailure(operation: .record, code: .write)
        }
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw HistoryFailure(operation: .clear, code: .clear)
        }
    }

    private func ensureRootDirectory() throws {
        try fileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: rootURL.path
        )
    }
}
