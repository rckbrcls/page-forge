import XCTest
@testable import PageForge

final class DocumentIntakeServiceTests: XCTestCase {
    private let service = DocumentIntakeService()

    func testAcceptsEPUBMOBIAndPDFCaseInsensitively() throws {
        let factory = try TemporaryDocumentFactory()
        let epub = try factory.makeEPUB(named: "One.EPUB")
        let mobi = try factory.makeMOBI(named: "Two.MoBi")
        let pdf = try factory.makePDF(named: "Three.PDF")

        let summary = service.intake(urls: [epub, mobi, pdf])

        XCTAssertEqual(summary.acceptedCount, 3)
        XCTAssertEqual(summary.rejectedCount, 0)
        XCTAssertEqual(summary.outcomes.compactMap(\.acceptedItem?.format), [.epub, .mobi, .pdf])
        XCTAssertTrue(summary.outcomes.allSatisfy { $0.acceptedItem?.securityAccess != nil })
        XCTAssertTrue(summary.outcomes.allSatisfy {
            $0.acceptedItem?.securityAccess?.isAccessActive == false
        })
    }

    func testRejectsUnsupportedRemoteMissingDirectoryAndUnreadableInputs() throws {
        let factory = try TemporaryDocumentFactory()
        let unsupported = try factory.makeUnsupportedFile()
        let remote = URL(string: "https://example.com/book.epub")!
        let missing = factory.directoryURL.appendingPathComponent("missing.epub")
        let directory = factory.directoryURL.appendingPathComponent("folder.epub", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unreadable = try factory.makeUnreadableFile()

        let summary = service.intake(urls: [unsupported, remote, missing, directory, unreadable])

        XCTAssertEqual(summary.acceptedCount, 0)
        XCTAssertEqual(summary.outcomes.map(\.rejection?.reason), [
            .unsupportedType,
            .notLocalFile,
            .missing,
            .notRegularFile,
            .unreadable
        ])
        for outcome in summary.outcomes {
            XCTAssertTrue(outcome.rejection?.message.contains(
                outcome.originalURL.lastPathComponent.isEmpty
                    ? outcome.originalURL.absoluteString
                    : outcome.originalURL.lastPathComponent
            ) == true)
        }
    }

    func testRejectsDuplicatePathsWithinOneIntake() throws {
        let factory = try TemporaryDocumentFactory()
        let original = try factory.makeEPUB()
        let duplicate = factory.duplicatePath(of: original)

        let summary = service.intake(urls: [original, duplicate])

        XCTAssertEqual(summary.acceptedCount, 1)
        XCTAssertEqual(summary.outcomes[1].rejection?.reason, .duplicate)
    }

    func testRejectsCanonicalAliasAndExistingQueueIdentity() throws {
        let factory = try TemporaryDocumentFactory()
        let original = try factory.makeEPUB()
        let alias = factory.directoryURL.appendingPathComponent("alias.epub")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: original)

        let aliasSummary = service.intake(urls: [original, alias])
        let identity = try XCTUnwrap(aliasSummary.outcomes.first?.acceptedItem?.canonicalIdentity)

        XCTAssertEqual(aliasSummary.outcomes[1].rejection?.reason, .duplicate)

        let existingSummary = service.intake(urls: [original], existingIdentities: [identity])
        XCTAssertEqual(existingSummary.acceptedCount, 0)
        XCTAssertEqual(existingSummary.outcomes.first?.rejection?.reason, .duplicate)
    }

    func testPartialAcceptancePreservesEveryInputOutcomeInStableOrder() throws {
        let factory = try TemporaryDocumentFactory()
        let epub = try factory.makeEPUB(named: "first.epub")
        let unsupported = try factory.makeUnsupportedFile(named: "second.txt")
        let pdf = try factory.makePDF(named: "third.pdf")
        let duplicate = factory.duplicatePath(of: epub)
        let inputs = [epub, unsupported, pdf, duplicate]

        let summary = service.intake(urls: inputs)

        XCTAssertEqual(summary.outcomes.map(\.originalURL), inputs)
        XCTAssertEqual(summary.outcomes.map(\.inputIndex), [0, 1, 2, 3])
        XCTAssertEqual(summary.acceptedCount, 2)
        XCTAssertEqual(summary.rejectedCount, 2)
        XCTAssertEqual(summary.outcomes[1].rejection?.reason, .unsupportedType)
        XCTAssertEqual(summary.outcomes[3].rejection?.reason, .duplicate)
    }

    func testFiftyItemMixedIntakeHasOneOutcomePerInputWithoutExternalWork() throws {
        let factory = try TemporaryDocumentFactory()
        var inputs: [URL] = []

        for index in 0..<40 {
            switch index % 3 {
            case 0:
                inputs.append(try factory.makeEPUB(named: "book-\(index).epub"))
            case 1:
                inputs.append(try factory.makeMOBI(named: "book-\(index).mobi"))
            default:
                inputs.append(try factory.makePDF(named: "book-\(index).pdf"))
            }
        }
        for index in 40..<45 {
            inputs.append(try factory.makeUnsupportedFile(named: "book-\(index).txt"))
        }
        inputs.append(contentsOf: inputs.prefix(5).map { factory.duplicatePath(of: $0) })

        measure {
            let summary = service.intake(urls: inputs)
            XCTAssertEqual(summary.outcomes.count, 50)
            XCTAssertEqual(summary.acceptedCount, 40)
            XCTAssertEqual(summary.rejectedCount, 10)
            XCTAssertEqual(summary.outcomes.map(\.originalURL), inputs)
        }
    }
}
