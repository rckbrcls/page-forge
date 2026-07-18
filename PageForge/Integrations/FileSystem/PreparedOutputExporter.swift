import Foundation

protocol PreparedOutputExporting: Sendable {
    func export(
        outputs: [PreparedOutput],
        destinationDirectory: URL,
        conflictPolicy: OutputConflictPolicy
    ) -> [ExportResult]
}

struct PreparedOutputExporter: PreparedOutputExporting {
    func export(
        outputs: [PreparedOutput],
        destinationDirectory: URL,
        conflictPolicy: OutputConflictPolicy = .failIfExists
    ) -> [ExportResult] {
        let fileManager = FileManager()
        let destination = destinationDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              fileManager.isWritableFile(atPath: destination.path)
        else {
            return outputs.map {
                failure(
                    output: $0,
                    destination: destination.appendingPathComponent($0.outputURL.lastPathComponent),
                    message: "Choose a writable local destination folder."
                )
            }
        }

        return outputs.map { output in
            let source = output.outputURL.standardizedFileURL
            let target = destination.appendingPathComponent(source.lastPathComponent)

            guard fileManager.isReadableFile(atPath: source.path) else {
                return failure(output: output, destination: target, message: "Prepared output is missing or unreadable.")
            }

            do {
                if fileManager.fileExists(atPath: target.path) {
                    guard conflictPolicy == .replaceConfirmed else {
                        return failure(
                            output: output,
                            destination: target,
                            message: "A file with this name already exists. Choose another folder or confirm replacement."
                        )
                    }
                    let staged = destination.appendingPathComponent(
                        ".pageforge-\(UUID().uuidString)-\(source.lastPathComponent)"
                    )
                    defer { try? fileManager.removeItem(at: staged) }
                    try fileManager.copyItem(at: source, to: staged)
                    _ = try fileManager.replaceItemAt(target, withItemAt: staged)
                } else {
                    try fileManager.copyItem(at: source, to: target)
                }
                return ExportResult(
                    sourceOutputURL: source,
                    destinationURL: target,
                    state: .succeeded,
                    message: "Saved to \(target.path)"
                )
            } catch {
                return failure(output: output, destination: target, message: error.localizedDescription)
            }
        }
    }

    private func failure(
        output: PreparedOutput,
        destination: URL,
        message: String
    ) -> ExportResult {
        ExportResult(
            sourceOutputURL: output.outputURL,
            destinationURL: destination,
            state: .failed,
            message: message
        )
    }
}
