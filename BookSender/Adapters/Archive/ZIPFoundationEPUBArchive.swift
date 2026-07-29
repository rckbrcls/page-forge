import Foundation
import ZIPFoundation

actor ZIPFoundationEPUBArchive: EPUBArchiveReading {
    private let source: StagedFileReference
    private var entriesByPath: [String: Entry] = [:]

    init(source: StagedFileReference) {
        self.source = source
    }

    func preflight(_ file: StagedFileReference, limits: SafetyLimits) async throws -> [ArchiveEntryDescriptor] {
        try Task.checkCancellation()
        guard file.identifier == source.identifier else {
            throw failure("archive.open")
        }
        let archive: Archive
        do {
            archive = try Archive(url: source.url, accessMode: .read)
        } catch {
            throw failure("archive.open")
        }

        var descriptors: [ArchiveEntryDescriptor] = []
        var normalizedPaths = Set<String>()
        var compressedTotal: Int64 = 0
        var expandedTotal: Int64 = 0

        for entry in archive {
            try Task.checkCancellation()
            guard descriptors.count < limits.maximumArchiveEntries else {
                throw failure("archive.entry-limit")
            }
            let normalized = try validatedPath(entry.path)
            let collisionKey = normalized.precomposedStringWithCanonicalMapping.lowercased()
            guard normalizedPaths.insert(collisionKey).inserted else {
                throw failure("archive.duplicate-path")
            }
            guard entry.type == .file || entry.type == .directory else {
                throw failure("archive.unsupported-entry")
            }
            compressedTotal += Int64(entry.compressedSize)
            expandedTotal += Int64(entry.uncompressedSize)
            guard compressedTotal <= limits.maximumCompressedBytes,
                  expandedTotal <= limits.maximumExpandedBytes,
                  Int64(entry.uncompressedSize) <= limits.maximumEntryBytes
            else { throw failure("archive.size-limit") }
            if entry.compressedSize > 0 {
                let ratio = Double(entry.uncompressedSize) / Double(entry.compressedSize)
                guard ratio <= limits.maximumExpansionRatio else {
                    throw failure("archive.expansion-ratio")
                }
            }
            entriesByPath[normalized] = entry
            descriptors.append(
                ArchiveEntryDescriptor(
                    path: normalized,
                    compressedSize: Int64(entry.compressedSize),
                    uncompressedSize: Int64(entry.uncompressedSize),
                    compressionMethod: entry.isCompressed
                        ? CompressionMethod.deflate.rawValue
                        : CompressionMethod.none.rawValue,
                    isDirectory: entry.type == .directory
                )
            )
        }
        return descriptors
    }

    func data(for path: String, maximumBytes: Int) async throws -> Data {
        try Task.checkCancellation()
        guard let entry = entriesByPath[path],
              entry.uncompressedSize <= UInt64(maximumBytes)
        else {
            throw failure("archive.entry-unavailable")
        }
        let archive: Archive
        do {
            archive = try Archive(url: source.url, accessMode: .read)
        } catch {
            throw failure("archive.open")
        }

        var result = Data()
        _ = try archive.extract(entry, bufferSize: 64 * 1_024) { chunk in
            if Task.isCancelled { throw CancellationError() }
            guard result.count + chunk.count <= maximumBytes else {
                throw self.failure("archive.entry-limit")
            }
            result.append(chunk)
        }
        return result
    }

    private func validatedPath(_ rawPath: String) throws -> String {
        let path = rawPath.replacingOccurrences(of: "\\", with: "/")
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              path.range(of: #"^[A-Za-z]:"# , options: .regularExpression) == nil,
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw failure("archive.unsafe-path") }
        var components: [Substring] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: false) {
            guard !component.isEmpty, component != ".", component != ".." else {
                throw failure("archive.unsafe-path")
            }
            components.append(component)
        }
        return components.joined(separator: "/")
    }

    private nonisolated func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .archive,
            code: code,
            message: "This EPUB archive is not safe to process.",
            recoveryAction: .reviewBook
        )
    }
}
