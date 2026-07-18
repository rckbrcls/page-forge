import Foundation

enum CalibreManagementPurpose: String, Equatable, Sendable {
    case install
    case update
}

enum CalibreWebsiteReason: Equatable, Sendable {
    case homebrewMissing
    case manualInstallation
}

enum CalibreManagementAction: Equatable, Sendable, Identifiable {
    case install(homebrewURL: URL)
    case update(homebrewURL: URL)
    case openOfficialWebsite(purpose: CalibreManagementPurpose, reason: CalibreWebsiteReason)

    var id: String {
        switch self {
        case .install: return "install"
        case .update: return "update"
        case .openOfficialWebsite(let purpose, let reason):
            return "website-\(purpose.rawValue)-\(String(describing: reason))"
        }
    }

    var purpose: CalibreManagementPurpose {
        switch self {
        case .install: return .install
        case .update: return .update
        case .openOfficialWebsite(let purpose, _): return purpose
        }
    }

    var command: String? {
        switch self {
        case .install:
            return "brew install --cask calibre"
        case .update:
            return "brew upgrade --cask calibre"
        case .openOfficialWebsite:
            return nil
        }
    }
}

struct CalibreManagementService: Sendable {
    static let officialDownloadURL = URL(string: "https://calibre-ebook.com/download_osx")!

    private let homebrewCandidates: [URL]
    private let isExecutable: @Sendable (URL) -> Bool
    private let isCaskInstalled: @Sendable (URL) -> Bool
    private let commandRunner: @Sendable (URL, [String]) throws -> String

    init(
        homebrewCandidates: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            URL(fileURLWithPath: "/usr/local/bin/brew"),
        ],
        isExecutable: (@Sendable (URL) -> Bool)? = nil,
        isCaskInstalled: (@Sendable (URL) -> Bool)? = nil,
        commandRunner: (@Sendable (URL, [String]) throws -> String)? = nil
    ) {
        self.homebrewCandidates = homebrewCandidates
        self.isExecutable = isExecutable ?? {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
        self.isCaskInstalled = isCaskInstalled ?? { homebrewURL in
            Self.run(homebrewURL, arguments: ["list", "--cask", "calibre"]).status == 0
        }
        self.commandRunner = commandRunner ?? { executable, arguments in
            let result = Self.run(executable, arguments: arguments)
            guard result.status == 0 else {
                throw DomainError.dependency(
                    result.output.isEmpty ? "Homebrew could not manage Calibre." : result.output
                )
            }
            return result.output
        }
    }

    func recommendedAction(for status: DependencyStatus) -> CalibreManagementAction {
        guard let homebrewURL = homebrewCandidates.first(where: isExecutable) else {
            return .openOfficialWebsite(
                purpose: status.isReady ? .update : .install,
                reason: .homebrewMissing
            )
        }

        guard status.isReady else {
            return .install(homebrewURL: homebrewURL)
        }

        guard isCaskInstalled(homebrewURL) else {
            return .openOfficialWebsite(purpose: .update, reason: .manualInstallation)
        }
        return .update(homebrewURL: homebrewURL)
    }

    func perform(_ action: CalibreManagementAction) throws -> String {
        switch action {
        case .install(let homebrewURL):
            return try commandRunner(homebrewURL, ["install", "--cask", "calibre"])
        case .update(let homebrewURL):
            return try commandRunner(homebrewURL, ["upgrade", "--cask", "calibre"])
        case .openOfficialWebsite:
            throw DomainError.dependency("Open the official Calibre download page.")
        }
    }

    private static func run(_ executable: URL, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        process.environment = environment

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (process.terminationStatus, text)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
