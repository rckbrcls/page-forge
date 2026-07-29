import Foundation
import ZIPFoundation

struct EPUBArchiveWriter: EPUBArchiveWriting {
    func write(
        source: StagedFileReference,
        plan: PreparationPlan,
        workspace: WorkspaceReference
    ) async throws -> StagedFileReference {
        try Task.checkCancellation()
        let partialURL = workspace.rootURL.appending(component: "prepared.partial.epub")
        guard !FileManager.default.fileExists(atPath: partialURL.path) else {
            throw failure("repair.output-create")
        }

        do {
            let input = try Archive(url: source.url, accessMode: .read)
            let output = try Archive(url: partialURL, accessMode: .create)
            let mimetype = Data("application/epub+zip".utf8)
            try output.addEntry(
                with: "mimetype",
                type: .file,
                uncompressedSize: Int64(mimetype.count),
                compressionMethod: .none,
                provider: { position, size in
                    mimetype.subdata(in: Int(position)..<Int(position) + size)
                }
            )

            for entry in input where entry.path != "mimetype" {
                try Task.checkCancellation()
                guard entry.type == .file else { continue }
                var bytes = Data()
                _ = try input.extract(entry, bufferSize: 64 * 1_024) { bytes.append($0) }
                try output.addEntry(
                    with: entry.path,
                    type: .file,
                    uncompressedSize: Int64(bytes.count),
                    compressionMethod: .deflate,
                    provider: { position, size in
                        bytes.subdata(in: Int(position)..<Int(position) + size)
                    }
                )
            }
            return StagedFileReference(identifier: UUID(), url: partialURL)
        } catch {
            try? FileManager.default.removeItem(at: partialURL)
            throw error is CancellationError ? error : failure("repair.write")
        }
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
