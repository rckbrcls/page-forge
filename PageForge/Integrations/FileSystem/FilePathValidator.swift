import Foundation

enum FilePathValidator {
    static func requireExistingFile(_ url: URL) throws -> URL {
        let path = url.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir) else {
            throw DomainError.filesystem("Input file does not exist: \(path.path)")
        }
        guard !isDir.boolValue else {
            throw DomainError.filesystem("Input path is not a file: \(path.path)")
        }
        return path
    }

    static func requireExistingDirectory(_ url: URL) throws -> URL {
        let path = url.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir) else {
            throw DomainError.filesystem("Input directory does not exist: \(path.path)")
        }
        guard isDir.boolValue else {
            throw DomainError.filesystem("Input path is not a directory: \(path.path)")
        }
        return path
    }

    static func requireSuffix(_ url: URL, _ expected: String) throws {
        guard url.pathExtension.lowercased() == expected.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) else {
            throw DomainError.validation("Expected a \(expected.uppercased()) file, got: \(url.lastPathComponent)")
        }
    }

    static func requireSuffixes(_ url: URL, _ expected: [String]) throws {
        let ext = url.pathExtension.lowercased()
        let normalized = expected.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        guard normalized.contains(ext) else {
            let label = normalized.map { $0.uppercased() }.joined(separator: " or ")
            throw DomainError.validation("Expected a \(label) file, got: \(url.lastPathComponent)")
        }
    }

    static func prepareOutput(_ url: URL, overwrite: Bool) throws -> URL {
        let path = url.standardizedFileURL
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir) {
            if isDir.boolValue {
                throw DomainError.filesystem("Output path is a directory: \(path.path)")
            }
            if !overwrite {
                throw DomainError.filesystem(
                    "Output file already exists: \(path.path). Enable overwrite to replace it."
                )
            }
            try FileManager.default.removeItem(at: path)
        }
        return path
    }
}
