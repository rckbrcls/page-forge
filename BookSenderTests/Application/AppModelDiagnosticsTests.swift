import Foundation
import Testing
@testable import BookSender

@MainActor
struct AppModelDiagnosticsTests {
    @Test
    func recordsSetupFailureOnceAndCopiesTheSameSanitizedEvent() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        await graph.credentials.setSaveFailure(
            SanitizedFailure(
                family: .credential,
                code: .credentialSave,
                message: "The app password was not stored.",
                recoveryAction: .editSetup
            )
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()

        model.saveSetup()
        try await eventually { model.currentDiagnosticEvent != nil }
        let event = try #require(model.currentDiagnosticEvent)

        #expect(event.failure.code == .credentialSave)
        #expect(
            event.failure.evidence.context.appVersion
                == DiagnosticTestFixtures.safeAppVersion
        )
        #expect(event.failure.evidence.context.operationID != nil)
        #expect(await graph.diagnosticRecorder.events.count == 1)
        #expect(
            model.notificationFeedback(
                for: .deliverySetup,
                destination: .main
            ) == nil
        )

        model.copyCurrentErrorDetails()
        #expect(graph.diagnosticClipboard.copies.count == 1)
        #expect(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .main
            )?.title == "Error details copied."
        )
        #expect(model.currentDiagnosticEvent == event)
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .diagnosticCopy
            }.count == 1
        )
        for forbidden in DiagnosticTestFixtures.forbiddenValues {
            #expect(
                graph.diagnosticClipboard.copies[0].text.contains(forbidden)
                    == false
            )
            #expect(
                String(
                    describing: model.notificationFeedback(
                        for: .diagnosticCopy,
                        destination: .main
                    )
                ).contains(forbidden) == false
            )
        }
    }

    @Test
    func clipboardFailureKeepsOriginalEventAndRecordsCopyFailure() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        await graph.credentials.setSaveFailure(
            SanitizedFailure(
                family: .credential,
                code: .credentialSave,
                message: "The app password was not stored.",
                recoveryAction: .editSetup
            )
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.main)
        model.setupDraft = validDraft()
        model.saveSetup()
        try await eventually { model.currentDiagnosticEvent != nil }
        let original = try #require(model.currentDiagnosticEvent)
        graph.diagnosticClipboard.error = .writeFailed

        model.copyCurrentErrorDetails()
        try await eventually {
            await graph.diagnosticRecorder.events.count == 2
        }

        #expect(model.currentDiagnosticEvent == original)
        #expect(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .main
            )?.state == .failed
        )
        #expect(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .main
            )?.failure?.code == .clipboardWrite
        )
        #expect(
            model.notificationCenter.snapshot(for: .main).visible.filter {
                $0.feedback.scope == .diagnosticCopy
            }.count == 1
        )
    }

    @Test
    func repeatedDiagnosticCopyReplacesThePriorCardInItsDestination() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        await graph.credentials.setSaveFailure(
            sanitizedFailure(.credentialSave, family: .credential)
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.notificationCenter.attach(.settings)
        model.setupDraft = validDraft()
        model.saveSetup(destination: .settings)
        try await eventually { model.currentDiagnosticEvent != nil }

        model.copyCurrentErrorDetails(destination: .settings)
        let firstID = try #require(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .settings
            )?.id
        )
        model.copyCurrentErrorDetails(destination: .settings)
        let replacement = try #require(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .settings
            )
        )

        #expect(replacement.id != firstID)
        #expect(graph.diagnosticClipboard.copies.count == 2)
        #expect(
            model.notificationCenter.snapshot(for: .settings).visible.filter {
                $0.feedback.scope == .diagnosticCopy
            }.count == 1
        )
        #expect(
            model.notificationFeedback(
                for: .diagnosticCopy,
                destination: .main
            ) == nil
        )
    }

    @Test
    func repeatedAcceptedFailureConsolidatesVisibleOccurrenceCount() async throws {
        let stores = try TestStores.make()
        defer { stores.cleanup() }
        let graph = TestDependencyGraph.make(stores: stores)
        await graph.credentials.setSaveFailure(
            SanitizedFailure(
                family: .credential,
                code: .credentialSave,
                message: "The app password was not stored.",
                recoveryAction: .editSetup
            )
        )
        let model = AppModel(dependencies: graph.dependencies)
        model.setupDraft = validDraft()

        model.saveSetup()
        try await eventually {
            await graph.diagnosticRecorder.events.count == 1
                && !model.isSavingSetup
        }
        model.saveSetup()
        try await eventually {
            await graph.diagnosticRecorder.events.count == 2
                && !model.isSavingSetup
        }

        #expect(
            model.feedback(for: .deliverySetup)?.occurrenceCount == 2
        )
        #expect(model.currentDiagnosticEvent?.occurrenceCount == 2)
        #expect(
            model.feedback(for: .deliverySetup)?.failure?.code
                == .credentialSave
        )
    }

    private func eventually(
        _ condition: @escaping @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<2_000 {
            if await condition() { return }
            await Task.yield()
        }
        throw AppModelDiagnosticTestError.timeout
    }

    private func validDraft() -> DeliverySetupDraft {
        DeliverySetupDraft(
            senderAddress: "sender@example.com",
            smtpHost: "smtp.example.com",
            smtpPort: "465",
            securityMode: .implicitTLS,
            username: "sender",
            appPassword: DiagnosticTestFixtures.password,
            kindleAddress: "reader@kindle.com"
        )
    }
}

private enum AppModelDiagnosticTestError: Error {
    case timeout
}
