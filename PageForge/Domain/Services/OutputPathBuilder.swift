import Foundation

enum OutputPathBuilder {
    static func repairedEPUB(for source: URL) -> URL {
        source.deletingLastPathComponent()
            .appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)-repaired.epub")
    }

    static func kindleReadyEPUB(for source: URL) -> URL {
        source.deletingLastPathComponent()
            .appendingPathComponent("\(source.deletingPathExtension().lastPathComponent)-kindle-ready.epub")
    }

    static func converted(for source: URL, target: ConversionTarget) -> URL {
        source.deletingPathExtension().appendingPathExtension(target.rawValue)
    }

    static func resolve(
        preferred: URL?,
        outputDirectory: URL?,
        defaultURL: URL
    ) -> URL {
        if let preferred {
            return preferred.standardizedFileURL
        }
        if let outputDirectory {
            return outputDirectory.appendingPathComponent(defaultURL.lastPathComponent)
        }
        return defaultURL
    }
}
