import Foundation
import Testing
@testable import BookSender

struct FixtureManifestTests {
    @Test
    func manifestUsesNativeSchemaAndVerifiedDefinitionDigests() throws {
        let data = try Data(contentsOf: manifestURL())
        let manifest = try JSONDecoder().decode(FixtureManifest.self, from: data)

        #expect(manifest.schemaVersion == 2)
        #expect(manifest.generator == "BookSenderTests.Support.FixtureFactory")
        #expect(manifest.digestAlgorithm == "sha256")
        #expect(manifest.families.count >= 20)
        #expect(Set(manifest.families.map(\.id)).count == manifest.families.count)

        for family in manifest.families {
            #expect(
                family.definitionDigest
                    == FixtureFactory.definitionDigest(family.id)
            )
            #expect(BookHealth(rawValue: family.expectedHealth) != nil)
            #expect(
                family.findingCodes.allSatisfy {
                    FindingCode(rawValue: $0) != nil
                }
            )
            #expect(
                family.repairActions.allSatisfy {
                    $0.hasPrefix("repair.")
                }
            )
        }
    }

    @Test
    func generatedEPUBAndPDFBytesAreDeterministic() throws {
        let firstRoot = try FixtureFactory.makeDirectory()
        let secondRoot = try FixtureFactory.makeDirectory()
        defer {
            try? FileManager.default.removeItem(at: firstRoot)
            try? FileManager.default.removeItem(at: secondRoot)
        }

        let firstEPUB = try FixtureFactory.makeEPUB(.validEPUB3, in: firstRoot)
        let secondEPUB = try FixtureFactory.makeEPUB(.validEPUB3, in: secondRoot)
        #expect(try FixtureFactory.digest(of: firstEPUB) == FixtureFactory.digest(of: secondEPUB))

        let firstPDF = try FixtureFactory.makePDF(in: firstRoot)
        let secondPDF = try FixtureFactory.makePDF(in: secondRoot)
        #expect(try FixtureFactory.digest(of: firstPDF) == FixtureFactory.digest(of: secondPDF))
    }

    private func manifestURL() throws -> URL {
        let bundle = Bundle(for: BundleLocator.self)
        let candidates = [
            bundle.url(
                forResource: "fixture-manifest",
                withExtension: "json",
                subdirectory: "Fixtures"
            ),
            bundle.url(
                forResource: "fixture-manifest",
                withExtension: "json"
            ),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw ManifestError.missingResource
        }
        return url
    }
}

private final class BundleLocator {}

private struct FixtureManifest: Decodable {
    let schemaVersion: Int
    let generator: String
    let digestAlgorithm: String
    let families: [FixtureFamily]
}

private struct FixtureFamily: Decodable {
    let id: String
    let definitionDigest: String
    let expectedHealth: String
    let findingCodes: [String]
    let repairActions: [String]
    let expectedReady: Bool
}

private enum ManifestError: Error {
    case missingResource
}

