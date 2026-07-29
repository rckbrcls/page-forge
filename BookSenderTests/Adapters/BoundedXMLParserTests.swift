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

    @Test(arguments: [
        #"<!DOCTYPE root [<!ENTITY x SYSTEM "file:///etc/passwd">]><root>&x;</root>"#,
        #"<root href="https://example.com/book"/>"#
    ])
    func rejectsExternalOrRemoteContent(xml: String) async {
        await #expect(throws: SanitizedFailure.self) {
            _ = try await parser.parse(Data(xml.utf8), limits: .standard)
        }
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
}
