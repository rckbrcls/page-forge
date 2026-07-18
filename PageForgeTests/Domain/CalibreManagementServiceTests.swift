import XCTest
@testable import PageForge

final class CalibreManagementServiceTests: XCTestCase {
    private let homebrewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    func testMissingCalibreUsesHomebrewInstallWhenAvailable() {
        let service = makeService(homebrewAvailable: true, caskInstalled: false)

        XCTAssertEqual(
            service.recommendedAction(for: DependencyStatus()),
            .install(homebrewURL: homebrewURL)
        )
    }

    func testHomebrewManagedCalibreUsesUpdate() {
        let service = makeService(homebrewAvailable: true, caskInstalled: true)

        XCTAssertEqual(
            service.recommendedAction(for: readyStatus),
            .update(homebrewURL: homebrewURL)
        )
    }

    func testManualCalibreUsesOfficialWebsiteForUpdate() {
        let service = makeService(homebrewAvailable: true, caskInstalled: false)

        XCTAssertEqual(
            service.recommendedAction(for: readyStatus),
            .openOfficialWebsite(purpose: .update, reason: .manualInstallation)
        )
    }

    func testMissingHomebrewUsesOfficialWebsite() {
        let service = makeService(homebrewAvailable: false, caskInstalled: false)

        XCTAssertEqual(
            service.recommendedAction(for: DependencyStatus()),
            .openOfficialWebsite(purpose: .install, reason: .homebrewMissing)
        )
    }

    func testInstallAndUpdateUseExactApprovedArguments() throws {
        let recorder = CalibreCommandRecorder()
        let service = CalibreManagementService(
            homebrewCandidates: [homebrewURL],
            isExecutable: { _ in true },
            isCaskInstalled: { _ in true },
            commandRunner: { executable, arguments in
                recorder.record(executable: executable, arguments: arguments)
                return "Done"
            }
        )

        _ = try service.perform(.install(homebrewURL: homebrewURL))
        _ = try service.perform(.update(homebrewURL: homebrewURL))

        XCTAssertEqual(recorder.commands, [
            .init(executable: homebrewURL, arguments: ["install", "--cask", "calibre"]),
            .init(executable: homebrewURL, arguments: ["upgrade", "--cask", "calibre"]),
        ])
    }

    private var readyStatus: DependencyStatus {
        DependencyStatus(
            ebookConvertPath: URL(fileURLWithPath: "/tools/ebook-convert"),
            ebookMetaPath: URL(fileURLWithPath: "/tools/ebook-meta"),
            ebookPolishPath: URL(fileURLWithPath: "/tools/ebook-polish")
        )
    }

    private func makeService(
        homebrewAvailable: Bool,
        caskInstalled: Bool
    ) -> CalibreManagementService {
        CalibreManagementService(
            homebrewCandidates: [homebrewURL],
            isExecutable: { _ in homebrewAvailable },
            isCaskInstalled: { _ in caskInstalled }
        )
    }
}

private final class CalibreCommandRecorder: @unchecked Sendable {
    struct Command: Equatable {
        let executable: URL
        let arguments: [String]
    }

    private let lock = NSLock()
    private var storage: [Command] = []

    var commands: [Command] {
        lock.withLock { storage }
    }

    func record(executable: URL, arguments: [String]) {
        lock.withLock {
            storage.append(Command(executable: executable, arguments: arguments))
        }
    }
}
