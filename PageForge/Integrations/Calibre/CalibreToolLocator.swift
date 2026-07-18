import Foundation

struct CalibreToolLocator {
    private let fileManager: FileManager
    private let environment: [String: String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.environment = environment
    }

    func locate(tool name: String, envVar: String?) throws -> URL? {
        if let envVar, let configured = environment[envVar], !configured.isEmpty {
            let url = URL(fileURLWithPath: (configured as NSString).expandingTildeInPath)
            guard isExecutable(url) else {
                throw DomainError.dependency("\(envVar) points to a missing file: \(url.path)")
            }
            return url
        }

        if let pathURL = findInPATH(name) {
            return pathURL
        }

        for directory in candidateDirectories {
            let candidate = directory.appendingPathComponent(name)
            if isExecutable(candidate) {
                return candidate
            }
        }
        return nil
    }

    func status() throws -> DependencyStatus {
        DependencyStatus(
            ebookConvertPath: try locate(tool: "ebook-convert", envVar: "EBOOK_CONVERT_PATH"),
            ebookMetaPath: try locate(tool: "ebook-meta", envVar: "EBOOK_META_PATH"),
            ebookPolishPath: try locate(tool: "ebook-polish", envVar: "EBOOK_POLISH_PATH")
        )
    }

    private var candidateDirectories: [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications/calibre.app/Contents/MacOS"),
            home.appendingPathComponent("Applications/calibre.app/Contents/MacOS"),
            URL(fileURLWithPath: "/opt/homebrew/bin"),
            URL(fileURLWithPath: "/usr/local/bin"),
        ]
    }

    private func isExecutable(_ url: URL) -> Bool {
        fileManager.isExecutableFile(atPath: url.path)
    }

    private func findInPATH(_ name: String) -> URL? {
        let path = environment["PATH"] ?? ""
        for item in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(item)).appendingPathComponent(name)
            if isExecutable(candidate) {
                return candidate
            }
        }
        return nil
    }
}
