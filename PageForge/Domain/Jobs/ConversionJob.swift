import Foundation

struct ConversionJobRunner {
    private let service: ConversionService

    init(service: ConversionService = ConversionService()) {
        self.service = service
    }

    func run(
        source: URL,
        target: ConversionTarget,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ConversionResult {
        switch target {
        case .epub:
            return try service.convertToEPUB(source: source, overwrite: overwrite, onProgress: onProgress)
        case .mobi:
            return try service.convertToMOBI(source: source, overwrite: overwrite, onProgress: onProgress)
        }
    }
}
