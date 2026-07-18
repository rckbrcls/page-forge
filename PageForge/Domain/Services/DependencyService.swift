import Foundation

struct DependencyService {
    private let locator: CalibreToolLocator

    init(locator: CalibreToolLocator = CalibreToolLocator()) {
        self.locator = locator
    }

    func calibreStatus() throws -> DependencyStatus {
        try locator.status()
    }

    func requireConvert() throws -> URL {
        let status = try calibreStatus()
        guard let path = status.ebookConvertPath else {
            throw DomainError.dependency(
                "Calibre command not found. Install Calibre or configure ebook-convert."
            )
        }
        return path
    }

    func requireMeta() throws -> URL {
        let status = try calibreStatus()
        guard let path = status.ebookMetaPath else {
            throw DomainError.dependency(
                "Calibre metadata command not found. Install Calibre or configure ebook-meta."
            )
        }
        return path
    }

    func requirePolish() throws -> URL {
        let status = try calibreStatus()
        guard let path = status.ebookPolishPath else {
            throw DomainError.dependency(
                "Calibre polish command not found. Install Calibre or configure ebook-polish."
            )
        }
        return path
    }
}
