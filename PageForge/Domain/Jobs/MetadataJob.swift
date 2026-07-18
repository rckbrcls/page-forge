import Foundation

struct MetadataJobRunner {
    private let service: MetadataService

    init(service: MetadataService = MetadataService()) {
        self.service = service
    }

    func inspect(source: URL) throws -> BookMetadata {
        try service.inspect(source: source)
    }

    func update(source: URL, title: String?, author: String?) throws -> BookMetadata {
        try service.update(source: source, title: title, author: author)
    }
}
