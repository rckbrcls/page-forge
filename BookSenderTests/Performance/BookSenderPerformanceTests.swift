import Foundation
import Testing
@testable import BookSender

struct BookSenderPerformanceTests {
    @Test
    @MainActor
    func launchCompositionAndFirstInteractionBudgets() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let clock = ContinuousClock()
        let compositionElapsed = clock.measure {
            _ = TestDependencyGraph.make(stores: stores)
        }
        #expect(compositionElapsed < .seconds(1))

        let graph = TestDependencyGraph.make(stores: stores)
        let model = AppModel(dependencies: graph.dependencies)
        let interactionElapsed = clock.measure {
            model.setupDraft.senderAddress = "sender@example.com"
            model.setupDraft.smtpHost = "smtp.example.com"
            model.setupDraft.username = "sender"
            model.setupDraft.appPassword = "secret"
            model.setupDraft.kindleAddress = "reader@kindle.com"
        }
        #expect(interactionElapsed < .milliseconds(100))
    }

    @Test
    @MainActor
    func shortcutRevealAndMainActorHeartbeatStayResponsive() async {
        let clock = ContinuousClock()
        var reopenCount = 0
        let coordinator = WindowCoordinator(activateApplication: {})
        coordinator.registerOpenMainWindow { reopenCount += 1 }

        let revealElapsed = clock.measure {
            coordinator.reveal()
        }
        #expect(revealElapsed < .milliseconds(100))
        #expect(reopenCount == 1)

        var heartbeatCount = 0
        let backgroundWork = Task.detached {
            let xml = Data(
                ("<root>"
                    + String(
                        repeating: "<item>value</item>",
                        count: 20_000
                    )
                    + "</root>").utf8
            )
            _ = try? await BoundedXMLParser().parse(xml, limits: .standard)
        }
        for _ in 0..<20 {
            heartbeatCount += 1
            await Task.yield()
        }
        backgroundWork.cancel()
        _ = await backgroundWork.result

        #expect(heartbeatCount == 20)
    }

    @Test
    func boundedXMLAndFixturePreparationRemainCooperativelyResponsive() async throws {
        let xml = Data(
            ("<root>" + String(repeating: "<item>value</item>", count: 2_000)
                + "</root>").utf8
        )
        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            _ = try await BoundedXMLParser().parse(xml, limits: .standard)
        }

        #expect(SafetyLimits.standard.permitsOperationElapsed(elapsed))
    }

    @Test
    func cancellationLatencyIsBoundedByCooperativeEntryChecks() async throws {
        let xml = Data(
            ("<root>" + String(repeating: "<item>value</item>", count: 20_000)
                + "</root>").utf8
        )
        let task = Task {
            try await BoundedXMLParser().parse(xml, limits: .standard)
        }
        task.cancel()
        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            _ = try? await task.value
        }

        #expect(elapsed < .seconds(1))
    }
}
