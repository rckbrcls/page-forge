import Foundation
import Testing
@testable import BookSender

struct BoundedXMLParserTests {
    private let parser = BoundedXMLParser()

    @Test
    func parsesNamespacesWithoutResolvingExternalResources() async throws {
        let xml = Data(#"<root xmlns="urn:test"><child id="1">value</child></root>"#.utf8)
        let projection = try await parser.parse(xml, limits: .standard)
        #expect(projection.rootName.contains("root"))
        #expect(projection.elements.contains(where: { $0.name.contains("child") }))
    }

    @Test
    func rejectsExternalEntityDeclaration() async {
        let xml =
            #"<!DOCTYPE root [<!ENTITY x SYSTEM "file:///etc/passwd">]><root>&x;</root>"#
        await #expect(throws: SanitizedFailure.self) {
            _ = try await parser.parse(Data(xml.utf8), limits: .standard)
        }
    }

    @Test
    func externalEntityFailureCarriesOnlyTypedXMLEvidence() async {
        let canary = DiagnosticTestFixtures.sourcePath
        let xml = #"<!DOCTYPE root [<!ENTITY x SYSTEM "\#(canary)">]><root>&x;</root>"#
        do {
            _ = try await parser.parse(Data(xml.utf8), limits: .standard)
            Issue.record("Expected external entity rejection")
        } catch let failure as SanitizedFailure {
            #expect(failure.code == .xmlExternalEntity)
            #expect(failure.evidence.phase == .xmlParsing)
            #expect(String(describing: failure).contains(canary) == false)
        } catch {
            Issue.record("Expected sanitized XML failure")
        }
    }

    @Test
    func preservesRemoteReferenceWithoutFetchingIt() async throws {
        let projection = try await parser.parse(
            Data(#"<root href="https://example.invalid/book"/>"#.utf8),
            limits: .standard
        )
        #expect(
            projection.elements.first?.attributes["href"]
                == "https://example.invalid/book"
        )
    }

    @Test
    func rejectsDepthPastLimit() async {
        let limits = SafetyLimits.standard
        let xml = String(repeating: "<a>", count: limits.maximumXMLDepth + 1)
            + String(repeating: "</a>", count: limits.maximumXMLDepth + 1)
        await #expect(throws: SanitizedFailure.self) {
            _ = try await parser.parse(Data(xml.utf8), limits: limits)
        }
    }

    @Test
    func preservesNestedElementPathsAndText() async throws {
        let projection = try await parser.parse(
            Data("<root><parent><child id=\"1\">value</child></parent></root>".utf8),
            limits: .standard
        )
        let child = try #require(
            projection.elements.first(where: { $0.name.hasSuffix("child") })
        )
        #expect(child.path.map { $0.split(separator: ":").last.map(String.init) ?? $0 }
            == ["root", "parent", "child"])
        #expect(child.text == "value")
    }

    @Test
    func enforcesElementAttributeAndTextLimits() async {
        let elements = Data("<root><a/><b/></root>".utf8)
        await #expect(throws: SanitizedFailure.self) {
            _ = try await parser.parse(
                elements,
                limits: makeSafetyLimits(maximumXMLElements: 2)
            )
        }
        let attributes = Data("<root a=\"1\" b=\"2\"/>".utf8)
        await #expect(throws: SanitizedFailure.self) {
            _ = try await parser.parse(
                attributes,
                limits: makeSafetyLimits(maximumXMLAttributesPerElement: 1)
            )
        }
        let text = Data("<root>12345</root>".utf8)
        await #expect(throws: SanitizedFailure.self) {
            _ = try await parser.parse(
                text,
                limits: makeSafetyLimits(maximumXMLTextBytes: 4)
            )
        }
    }

    @Test
    func honorsCancellation() async {
        let task = Task {
            try await parser.parse(
                Data("<root><child/></root>".utf8),
                limits: .standard
            )
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
