import Foundation
import Testing
@testable import BookSender

@MainActor
struct FloatingNotificationQueueTests {
    @Test
    func fourthEntryWaitsWithoutEvictingPersistentCards() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let persistent = persistentFeedback()
        for feedback in persistent {
            center.publish(feedback, destination: .main)
        }
        let queued = NotificationTestFixtures.feedback(
            id: UUID(),
            scope: .update,
            action: .checkForUpdates,
            title: "Update check opened."
        )
        center.publish(queued, destination: .main)

        let full = center.snapshot(for: .main)
        #expect(full.visible.count == 3)
        #expect(full.queuedCount == 1)
        #expect(!full.visible.map(\.id).contains(queued.id))

        center.close(
            feedbackID: persistent[0].id,
            destination: .main
        )

        let promoted = center.snapshot(for: .main)
        #expect(promoted.visible.count == 3)
        #expect(promoted.queuedCount == 0)
        #expect(promoted.visible.first?.id == queued.id)
    }

    @Test
    func twentyRapidEventsNeverExceedThreeVisibleEntries() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let scopes: [FeedbackScope] = [.batch, .history, .update]
        let actions: [FeedbackAction] = [
            .addBooks, .loadHistory, .checkForUpdates,
        ]

        for index in 0..<20 {
            center.publish(
                NotificationTestFixtures.feedback(
                    id: UUID(),
                    scope: scopes[index % scopes.count],
                    action: actions[index % actions.count],
                    title: "Result \(index)"
                ),
                destination: .main
            )
            #expect(center.snapshot(for: .main).visible.count <= 3)
        }
    }

    @Test
    func destinationsPromoteTheirOwnQueuesIndependently() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        center.attach(.settings)
        for feedback in persistentFeedback() {
            center.publish(feedback, destination: .main)
        }
        let settings = NotificationTestFixtures.feedback(
            id: UUID(),
            scope: .shortcut,
            action: .saveShortcut,
            title: "Shortcut saved."
        )
        center.publish(settings, destination: .settings)

        #expect(center.snapshot(for: .main).visible.count == 3)
        #expect(center.snapshot(for: .settings).visible.map(\.id) == [
            settings.id,
        ])
    }

    private func persistentFeedback() -> [ActionFeedback] {
        [
            (.deliverySetup, .saveDeliverySetup, "Setup cancelled"),
            (.history, .loadHistory, "History cancelled"),
            (.batch, .sendBatch, "Batch cancelled"),
        ].map { scope, action, title in
            NotificationTestFixtures.feedback(
                id: UUID(),
                scope: scope,
                action: action,
                state: .cancelled,
                title: title
            )
        }
    }
}
