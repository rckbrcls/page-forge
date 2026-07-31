import Foundation
import Testing
@testable import BookSender

@MainActor
struct FloatingNotificationReconciliationTests {
    @Test
    func equivalentNewLifecycleUpdatesOneCardAndOccurrenceCount() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let first = NotificationTestFixtures.feedback(
            id: UUID(),
            state: .cancelled,
            title: "Operation cancelled."
        )
        let repeated = NotificationTestFixtures.feedback(
            id: UUID(),
            state: .cancelled,
            title: "Operation cancelled."
        )

        center.publish(first, destination: .main)
        center.publish(repeated, destination: .main)

        let entry = center.snapshot(for: .main).visible.first
        #expect(center.snapshot(for: .main).visible.count == 1)
        #expect(entry?.id == first.id)
        #expect(entry?.feedback.occurrenceCount == 2)
    }

    @Test
    func sameLifecycleStateTransitionRetainsStackPosition() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let service = ActionFeedbackService()
        let start = service.acknowledged(
            scope: .batch,
            action: .sendBatch,
            title: "Sending books…"
        )
        let progress = service.inProgress(
            from: start,
            title: "Sending books…"
        )
        let other = NotificationTestFixtures.feedback(
            id: UUID(),
            scope: .update,
            action: .checkForUpdates,
            state: .cancelled,
            title: "Update cancelled."
        )
        center.publish(progress, destination: .main)
        center.publish(other, destination: .main)
        let originalIndex = center.snapshot(for: .main).visible.firstIndex {
            $0.id == progress.id
        }

        let success = service.terminal(
            from: progress,
            state: .succeeded,
            title: "Books submitted."
        )
        center.publish(success, destination: .main)

        let snapshot = center.snapshot(for: .main)
        #expect(snapshot.visible.firstIndex { $0.id == success.id } == originalIndex)
        #expect(snapshot.visible.first { $0.id == success.id }?.feedback.state == .succeeded)
    }

    @Test
    func queuedReplacementRemovesStaleContentBeforePromotion() {
        let center = FloatingNotificationCenter()
        center.attach(.main)
        let persistent = [
            FeedbackScope.deliverySetup,
            .history,
            .batch,
        ].map {
            NotificationTestFixtures.feedback(
                id: UUID(),
                scope: $0,
                state: .cancelled,
                title: "Persistent result"
            )
        }
        persistent.forEach { center.publish($0, destination: .main) }
        let stale = NotificationTestFixtures.feedback(
            id: UUID(),
            scope: .update,
            title: "Stale update"
        )
        let replacement = NotificationTestFixtures.feedback(
            id: UUID(),
            scope: .update,
            title: "Current update"
        )
        center.publish(stale, destination: .main)
        center.publish(replacement, destination: .main)

        center.close(
            feedbackID: persistent[0].id,
            destination: .main
        )

        let promoted = center.snapshot(for: .main).visible
        #expect(promoted.contains { $0.feedback.title == "Current update" })
        #expect(!promoted.contains { $0.feedback.title == "Stale update" })
    }
}
