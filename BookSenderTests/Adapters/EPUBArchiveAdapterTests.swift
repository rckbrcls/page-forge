import Foundation
import Testing
@testable import BookSender

struct EPUBArchiveAdapterTests {
    @Test
    func preflightsValidArchiveAndKeepsMimetypeFirst() async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try FixtureFactory.makeEPUB(.validEPUB3, in: directory)
        let source = StagedFileReference(identifier: UUID(), url: url)
        let archive = ZIPFoundationEPUBArchive(source: source)

        let descriptors = try await archive.preflight(
            source,
            limits: .standard
        )

        #expect(descriptors.first?.path == "mimetype")
        #expect(descriptors.first?.compressionMethod == 0)
        #expect(
            try await archive.data(for: "mimetype", maximumBytes: 64)
                == Data("application/epub+zip".utf8)
        )
    }

    @Test(arguments: [
        FixtureFactory.EPUBVariant.pathTraversal,
        .absolutePath,
        .duplicateNormalizedPath,
        .symbolicLink,
        .unsupportedCompression,
        .encryptedArchive,
        .expansionRatio,
    ])
    func rejectsUnsafePathsLinksCollisionsAndCompression(
        variant: FixtureFactory.EPUBVariant
    ) async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try FixtureFactory.makeEPUB(variant, in: directory)
        let source = StagedFileReference(identifier: UUID(), url: url)
        let archive = ZIPFoundationEPUBArchive(source: source)

        await #expect(throws: SanitizedFailure.self) {
            _ = try await archive.preflight(source, limits: .standard)
        }
    }

    @Test
    func acceptsAndNormalizesDirectoryEntriesWithoutIndexingThemAsFiles() async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try FixtureFactory.makeEPUB(.directoryEntry, in: directory)
        let source = StagedFileReference(identifier: UUID(), url: url)
        let archive = ZIPFoundationEPUBArchive(source: source)

        let descriptors = try await archive.preflight(source, limits: .standard)

        #expect(
            descriptors.contains {
                $0.path == "OEBPS" && $0.isDirectory
            }
        )
        await #expect(throws: SanitizedFailure.self) {
            _ = try await archive.data(for: "OEBPS", maximumBytes: 1)
        }
    }

    @Test
    func resetsOpenStateAndRejectsDifferentSource() async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = try FixtureFactory.makeEPUB(.validEPUB2, in: directory)
        let secondURL = try FixtureFactory.makeEPUB(.validEPUB3, in: directory)
        let source = StagedFileReference(identifier: UUID(), url: firstURL)
        let archive = ZIPFoundationEPUBArchive(source: source)
        _ = try await archive.preflight(source, limits: .standard)

        await #expect(throws: SanitizedFailure.self) {
            _ = try await archive.preflight(
                StagedFileReference(identifier: UUID(), url: secondURL),
                limits: .standard
            )
        }
        await #expect(throws: SanitizedFailure.self) {
            _ = try await archive.data(for: "mimetype", maximumBytes: 64)
        }
    }

    @Test
    func enforcesEntryCountAndExpandedSizeLimits() async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try FixtureFactory.makeEPUB(.archiveSizeBoundary, in: directory)
        let source = StagedFileReference(identifier: UUID(), url: url)
        let archive = ZIPFoundationEPUBArchive(source: source)

        await #expect(throws: SanitizedFailure.self) {
            _ = try await archive.preflight(
                source,
                limits: makeSafetyLimits(maximumArchiveEntries: 1)
            )
        }
        await #expect(throws: SanitizedFailure.self) {
            _ = try await archive.preflight(
                source,
                limits: makeSafetyLimits(maximumExpandedBytes: 128)
            )
        }
    }

    @Test
    func honorsCancellationBeforeOpening() async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try FixtureFactory.makeEPUB(.validEPUB3, in: directory)
        let source = StagedFileReference(identifier: UUID(), url: url)
        let archive = ZIPFoundationEPUBArchive(source: source)
        let task = Task {
            try await archive.preflight(source, limits: .standard)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
