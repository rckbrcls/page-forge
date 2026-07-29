import Foundation
import ZIPFoundation

struct EPUBArchiveWriter: EPUBArchiveWriting {
    func write(
        source: StagedFileReference,
        plan: PreparationPlan,
        workspace: WorkspaceReference,
        limits: SafetyLimits
    ) async throws -> StagedFileReference {
        try Task.checkCancellation()
        guard plan.decision == .writeEPUBWorkingCopy else {
            throw failure("repair.invalid-plan")
        }
        let supported = plan.actions.allSatisfy {
            switch $0 {
            case .rebuildMimetype, .restoreContainer: true
            case .correctMediaType, .normalizePath, .repairReference, .normalizeXML:
                false
            }
        }
        guard supported else {
            throw failure("repair.unsupported-action")
        }

        let reader = ZIPFoundationEPUBArchive(source: source)
        let descriptors = try await reader.preflight(source, limits: limits)
        try validatePreconditions(plan, descriptors: descriptors)

        let fileManager = FileManager.default
        let partialURL = workspace.rootURL
            .appending(component: "prepared.partial.epub")
        guard !fileManager.fileExists(atPath: partialURL.path) else {
            throw failure("repair.output-create")
        }

        let deadline = ContinuousClock.now.advanced(by: limits.operationTimeout)
        do {
            let input = try Archive(url: source.url, accessMode: .read)
            let output = try Archive(url: partialURL, accessMode: .create)
            try add(
                Data("application/epub+zip".utf8),
                at: "mimetype",
                compression: .none,
                to: output
            )

            if let packagePath = restoredPackagePath(in: plan) {
                try add(
                    containerXML(packagePath: packagePath),
                    at: "META-INF/container.xml",
                    compression: .deflate,
                    to: output
                )
            }

            for (index, descriptor) in descriptors.enumerated() {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else {
                    throw failure("repair.timeout")
                }
                guard !descriptor.isDirectory,
                      descriptor.path != "mimetype",
                      descriptor.path != "META-INF/container.xml"
                        || restoredPackagePath(in: plan) == nil
                else {
                    continue
                }
                guard let entry = input[descriptor.path],
                      descriptor.uncompressedSize <= limits.maximumEntryBytes
                else {
                    throw failure("repair.entry-missing")
                }

                let temporary = workspace.rootURL
                    .appending(component: "entry-\(index).partial")
                guard fileManager.createFile(
                    atPath: temporary.path,
                    contents: nil
                ) else {
                    throw failure("repair.entry-create")
                }
                defer { try? fileManager.removeItem(at: temporary) }

                let writer = try FileHandle(forWritingTo: temporary)
                do {
                    _ = try input.extract(entry, bufferSize: 64 * 1_024) { chunk in
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        guard ContinuousClock.now < deadline else {
                            throw self.failure("repair.timeout")
                        }
                        try writer.write(contentsOf: chunk)
                    }
                    try writer.synchronize()
                    try writer.close()
                } catch {
                    try? writer.close()
                    throw error
                }

                let itemReader = try FileHandle(forReadingFrom: temporary)
                defer { try? itemReader.close() }
                let compression: CompressionMethod = descriptor.compressionMethod == 0
                    ? .none
                    : .deflate
                try output.addEntry(
                    with: descriptor.path,
                    type: .file,
                    uncompressedSize: descriptor.uncompressedSize,
                    compressionMethod: compression,
                    provider: { position, size in
                        try Task.checkCancellation()
                        try itemReader.seek(toOffset: UInt64(position))
                        return try itemReader.read(upToCount: size) ?? Data()
                    }
                )
            }
            return StagedFileReference(identifier: UUID(), url: partialURL)
        } catch is CancellationError {
            try? fileManager.removeItem(at: partialURL)
            throw CancellationError()
        } catch let sanitized as SanitizedFailure {
            try? fileManager.removeItem(at: partialURL)
            throw sanitized
        } catch {
            try? fileManager.removeItem(at: partialURL)
            throw failure("repair.write")
        }
    }

    private func validatePreconditions(
        _ plan: PreparationPlan,
        descriptors: [ArchiveEntryDescriptor]
    ) throws {
        let paths = Set(descriptors.map(\.path))
        if let packagePath = restoredPackagePath(in: plan) {
            guard !paths.contains("META-INF/container.xml"),
                  paths.contains(packagePath),
                  paths.filter({ $0.lowercased().hasSuffix(".opf") }).count == 1
            else {
                throw failure("repair.precondition")
            }
        }
    }

    private func restoredPackagePath(in plan: PreparationPlan) -> String? {
        plan.actions.compactMap {
            if case .restoreContainer(let packagePath) = $0 {
                return packagePath
            }
            return nil
        }.first
    }

    private func containerXML(packagePath: String) -> Data {
        Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="\(escapedXMLAttribute(packagePath))" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """.utf8
        )
    }

    private func escapedXMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func add(
        _ data: Data,
        at path: String,
        compression: CompressionMethod,
        to archive: Archive
    ) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: compression,
            provider: { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        )
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .repair,
            code: code,
            message: "A safe working copy could not be created.",
            recoveryAction: .reviewBook
        )
    }
}
