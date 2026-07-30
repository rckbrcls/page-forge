import Foundation
import ZIPFoundation

actor ZIPFoundationEPUBArchive: EPUBArchiveReading {
    private let source: StagedFileReference
    private var indexedPaths = Set<String>()

    init(source: StagedFileReference) {
        self.source = source
    }

    func preflight(
        _ file: StagedFileReference,
        limits: SafetyLimits
    ) async throws -> [ArchiveEntryDescriptor] {
        indexedPaths.removeAll(keepingCapacity: true)
        try Task.checkCancellation()
        guard file == source else {
            throw failure(.archiveOpen)
        }
        let source = self.source

        do {
            return try await withTimeout(limits.operationTimeout) {
                let metadata = try ZIPMetadataScanner.scan(
                    source.url,
                    maximumBytes: limits.maximumCompressedBytes
                )
            guard limits.permitsArchiveEntryCount(metadata.count) else {
                throw self.failure(.archiveEntryLimit)
            }

            var descriptors: [ArchiveEntryDescriptor] = []
            var normalizedPaths = Set<String>()
            var compressedTotal: Int64 = 0
            var expandedTotal: Int64 = 0
            var normalizedMetadata: [(ZIPMetadataScanner.Metadata, String)] = []

            for metadataEntry in metadata {
                try Task.checkCancellation()
                let normalized = try self.validatedPath(
                    metadataEntry.path,
                    isDirectory: metadataEntry.isDirectory
                )
                let collisionKey = normalized
                    .precomposedStringWithCanonicalMapping
                    .lowercased()
                guard normalizedPaths.insert(collisionKey).inserted else {
                    throw self.failure(.archiveDuplicatePath)
                }
                guard !metadataEntry.isLink,
                      metadataEntry.compressionMethod == 0
                        || metadataEntry.compressionMethod == 8
                else {
                    throw self.failure(.archiveUnsupportedEntry)
                }
                guard !metadataEntry.isEncrypted else {
                    throw self.failure(.archiveEncrypted)
                }

                compressedTotal = try self.checkedAdd(
                    compressedTotal,
                    metadataEntry.compressedSize
                )
                expandedTotal = try self.checkedAdd(
                    expandedTotal,
                    metadataEntry.uncompressedSize
                )
                guard limits.permitsCompressedBytes(compressedTotal),
                      limits.permitsExpandedBytes(expandedTotal),
                      limits.permitsEntryBytes(metadataEntry.uncompressedSize)
                else {
                    throw self.failure(.archiveSizeLimit)
                }
                if metadataEntry.compressedSize == 0 {
                    guard metadataEntry.uncompressedSize == 0 else {
                        throw self.failure(.archiveExpansionRatio)
                    }
                } else {
                    let ratio = Double(metadataEntry.uncompressedSize)
                        / Double(metadataEntry.compressedSize)
                    guard limits.permitsExpansionRatio(ratio) else {
                        throw self.failure(.archiveExpansionRatio)
                    }
                }

                normalizedMetadata.append((metadataEntry, normalized))
                descriptors.append(
                    ArchiveEntryDescriptor(
                        path: normalized,
                        compressedSize: metadataEntry.compressedSize,
                        uncompressedSize: metadataEntry.uncompressedSize,
                        compressionMethod: metadataEntry.compressionMethod,
                        isDirectory: metadataEntry.isDirectory,
                        isEncrypted: metadataEntry.isEncrypted
                    )
                )
            }

            let validatedPaths: Set<String> = try {
                let archive: Archive
                do {
                    archive = try Archive(url: source.url, accessMode: .read)
                } catch {
                    throw self.failure(.archiveOpen)
                }
                let archiveEntries = Dictionary(
                    archive.map { ($0.path, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                var paths = Set<String>()
                for (metadataEntry, normalized) in normalizedMetadata
                    where !metadataEntry.isDirectory {
                    guard let entry = archiveEntries[metadataEntry.path],
                          entry.type == .file
                    else {
                        throw self.failure(.archiveEntryUnavailable)
                    }
                    paths.insert(normalized)
                }
                return paths
            }()
                await self.replaceIndex(validatedPaths)
                return descriptors
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let sanitized as SanitizedFailure {
            throw sanitized
        } catch {
            throw failure(.archiveOpen)
        }
    }

    func data(for path: String, maximumBytes: Int) async throws -> Data {
        try Task.checkCancellation()
        guard maximumBytes >= 0,
              indexedPaths.contains(path)
        else {
            throw failure(.archiveEntryUnavailable)
        }

        let archive: Archive
        do {
            archive = try Archive(url: source.url, accessMode: .read)
        } catch {
            throw failure(.archiveOpen)
        }
        guard let entry = archive[path],
              entry.type == .file,
              entry.uncompressedSize <= UInt64(maximumBytes)
        else {
            throw failure(.archiveEntryUnavailable)
        }

        var result = Data()
        do {
            _ = try archive.extract(entry, bufferSize: 64 * 1_024) { chunk in
                if Task.isCancelled {
                    throw CancellationError()
                }
                guard result.count <= maximumBytes - chunk.count else {
                    throw self.failure(.archiveEntryLimit)
                }
                result.append(chunk)
            }
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch let sanitized as SanitizedFailure {
            throw sanitized
        } catch {
            throw failure(.archiveExtract)
        }
    }

    private func replaceIndex(_ paths: Set<String>) {
        indexedPaths = paths
    }

    private nonisolated func validatedPath(
        _ rawPath: String,
        isDirectory: Bool
    ) throws -> String {
        guard !rawPath.isEmpty,
              !rawPath.contains("\\"),
              !rawPath.hasPrefix("/"),
              rawPath.range(
                of: #"^[A-Za-z]:"#,
                options: .regularExpression
              ) == nil,
              !rawPath.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw failure(.archiveUnsafePath)
        }

        let path = isDirectory && rawPath.hasSuffix("/")
            ? String(rawPath.dropLast())
            : rawPath
        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard !components.isEmpty,
              components.allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".."
              })
        else {
            throw failure(.archiveUnsafePath)
        }
        return components.joined(separator: "/")
    }

    private nonisolated func checkedAdd(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else {
            throw failure(.archiveSizeLimit)
        }
        return result
    }

    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(for: duration)
                throw self.failure(.archiveTimeout)
            }
            guard let result = try await group.next() else {
                throw self.failure(.archiveOpen)
            }
            group.cancelAll()
            return result
        }
    }

    private nonisolated func failure(_ code: DiagnosticCode) -> SanitizedFailure {
        SanitizedFailure(
            family: .archive,
            code: code,
            message: "This EPUB archive is not safe to process.",
            recoveryAction: .reviewBook
        )
    }
}

private enum ZIPMetadataScanner {
    struct Metadata {
        let path: String
        let compressedSize: Int64
        let uncompressedSize: Int64
        let compressionMethod: UInt16
        let isDirectory: Bool
        let isLink: Bool
        let isEncrypted: Bool
    }

    static func scan(_ url: URL, maximumBytes: Int64) throws -> [Metadata] {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0, byteCount <= maximumBytes else {
            throw scanFailure(.archiveSizeLimit)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let tailLength = min(Int(byteCount), 65_557)
        try handle.seek(toOffset: UInt64(byteCount - Int64(tailLength)))
        let tail = try handle.read(upToCount: tailLength) ?? Data()
        guard let endOffset = lastSignature(0x0605_4B50, in: tail),
              endOffset + 22 <= tail.count
        else {
            throw scanFailure(.archiveOpen)
        }

        let entryCount = Int(tail.uint16LE(at: endOffset + 10))
        let centralSize = Int64(tail.uint32LE(at: endOffset + 12))
        let centralOffset = Int64(tail.uint32LE(at: endOffset + 16))
        guard centralOffset >= 0,
              centralSize >= 0,
              centralOffset <= byteCount,
              centralSize <= byteCount - centralOffset,
              centralSize <= maximumBytes
        else {
            throw scanFailure(.archiveSizeLimit)
        }

        try handle.seek(toOffset: UInt64(centralOffset))
        let central = try handle.read(upToCount: Int(centralSize)) ?? Data()
        guard central.count == Int(centralSize) else {
            throw scanFailure(.archiveOpen)
        }

        var cursor = 0
        var result: [Metadata] = []
        result.reserveCapacity(entryCount)
        while cursor < central.count {
            try Task.checkCancellation()
            guard cursor + 46 <= central.count,
                  central.uint32LE(at: cursor) == 0x0201_4B50
            else {
                throw scanFailure(.archiveOpen)
            }
            let versionMadeBy = central.uint16LE(at: cursor + 4)
            let flags = central.uint16LE(at: cursor + 8)
            let method = central.uint16LE(at: cursor + 10)
            let compressed = central.uint32LE(at: cursor + 20)
            let uncompressed = central.uint32LE(at: cursor + 24)
            let nameLength = Int(central.uint16LE(at: cursor + 28))
            let extraLength = Int(central.uint16LE(at: cursor + 30))
            let commentLength = Int(central.uint16LE(at: cursor + 32))
            let externalAttributes = central.uint32LE(at: cursor + 38)
            let recordLength = 46 + nameLength + extraLength + commentLength
            guard nameLength > 0,
                  cursor + recordLength <= central.count,
                  compressed != UInt32.max,
                  uncompressed != UInt32.max
            else {
                throw scanFailure(.archiveUnsupportedEntry)
            }
            let nameData = central.subdata(
                in: (cursor + 46)..<(cursor + 46 + nameLength)
            )
            guard let path = String(data: nameData, encoding: .utf8) else {
                throw scanFailure(.archiveUnsafePath)
            }

            let osType = versionMadeBy >> 8
            let fileType = (externalAttributes >> 16) & 0xF000
            let isLink = (osType == 3 || osType == 19) && fileType == 0xA000
            let isDirectory = path.hasSuffix("/")
                || ((osType == 3 || osType == 19) && fileType == 0x4000)
            result.append(
                Metadata(
                    path: path,
                    compressedSize: Int64(compressed),
                    uncompressedSize: Int64(uncompressed),
                    compressionMethod: method,
                    isDirectory: isDirectory,
                    isLink: isLink,
                    isEncrypted: flags & 0x0001 != 0
                )
            )
            cursor += recordLength
        }

        guard result.count == entryCount else {
            throw scanFailure(.archiveOpen)
        }
        return result
    }

    private static func lastSignature(
        _ signature: UInt32,
        in data: Data
    ) -> Int? {
        guard data.count >= 4 else { return nil }
        for offset in stride(from: data.count - 4, through: 0, by: -1) {
            if data.uint32LE(at: offset) == signature {
                return offset
            }
        }
        return nil
    }

    private static func scanFailure(_ code: DiagnosticCode) -> SanitizedFailure {
        SanitizedFailure(
            family: .archive,
            code: code,
            message: "This EPUB archive is not safe to process.",
            recoveryAction: .reviewBook
        )
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
