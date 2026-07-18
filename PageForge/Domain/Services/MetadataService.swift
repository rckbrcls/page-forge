import Foundation

struct MetadataService {
    private let dependencyService: DependencyService
    private let runner: CalibreProcessRunner

    init(
        dependencyService: DependencyService = DependencyService(),
        runner: CalibreProcessRunner = CalibreProcessRunner()
    ) {
        self.dependencyService = dependencyService
        self.runner = runner
    }

    func inspect(source: URL) throws -> BookMetadata {
        let input = try FilePathValidator.requireExistingFile(source)
        let meta = try dependencyService.requireMeta()
        let raw = try runner.run(executable: meta, arguments: [input.path])
        return BookMetadata(path: input, raw: raw, fields: parse(raw))
    }

    func update(source: URL, title: String?, author: String?) throws -> BookMetadata {
        let input = try FilePathValidator.requireExistingFile(source)
        guard (title?.isEmpty == false) || (author?.isEmpty == false) else {
            throw DomainError.validation("Provide at least one metadata field to update.")
        }
        let meta = try dependencyService.requireMeta()
        var args = [input.path]
        if let title, !title.isEmpty {
            args += ["--title", title]
        }
        if let author, !author.isEmpty {
            args += ["--authors", author]
        }
        _ = try runner.run(executable: meta, arguments: args)
        return try inspect(source: input)
    }

    private func parse(_ raw: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in raw.split(whereSeparator: \.isNewline) {
            let text = String(line)
            guard let idx = text.firstIndex(of: ":") else { continue }
            let key = text[..<idx].trimmingCharacters(in: .whitespaces)
            let value = text[text.index(after: idx)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                fields[key] = value
            }
        }
        return fields
    }
}
