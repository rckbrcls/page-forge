import Foundation
import Testing
@testable import BookSender

struct PrivacyAuditTests {
    @Test
    func productionSourceContainsNoLoggingAnalyticsOrPreviewEgress() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = root.appending(component: "BookSender")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        )
        var source = ""
        for case let url as URL in enumerator
            where url.pathExtension == "swift" {
            source.append(try String(contentsOf: url, encoding: .utf8))
        }

        for forbidden in [
            ["Preview", "Book"].joined(),
            ["Preview", " Send Book"].joined(),
            ["SMTP delivery", " is not available"].joined(),
            "os_log(",
            "Logger(",
            "Analytics",
            "Telemetry",
        ] {
            #expect(source.contains(forbidden) == false)
        }
        #expect(source.contains("URLSession.shared") == false)
        #expect(source.contains("Process(") == false)
    }

    @Test
    func presentationAndPreferencesExcludeCredentialAndFilesystemPayloads() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        let setup = try await graph.dependencies.setupService.save(
            DeliverySetupDraft(
                senderAddress: "sender@example.com",
                smtpHost: "smtp.example.com",
                smtpPort: "465",
                securityMode: .implicitTLS,
                username: "sender",
                appPassword: "unique-provider-secret",
                kindleAddress: "reader@kindle.com"
            ),
            replacing: nil
        )
        let data = try JSONEncoder().encode(setup)
        let encoded = String(decoding: data, as: UTF8.self)

        #expect(encoded.contains("unique-provider-secret") == false)
        #expect(encoded.contains("source.snapshot") == false)
        #expect(encoded.contains("prepared.epub") == false)
        #expect(
            String(describing: BatchPresentation.empty)
                .contains(FileManager.default.temporaryDirectory.path) == false
        )
    }
}
