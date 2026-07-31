import Foundation
import Testing
@testable import BookSender

struct FloatingNotificationModelsTests {
    @Test
    func notificationKeyIncludesDestinationAndScope() {
        let main = NotificationKey(destination: .main, scope: .deliverySetup)
        let settings = NotificationKey(
            destination: .settings,
            scope: .deliverySetup
        )

        #expect(main != settings)
        #expect(Set([main, settings]).count == 2)
    }

    @Test
    func invalidSystemIconFallsBackToAutomatic() {
        #expect(NotificationIcon.system("  ").normalized() == .automatic)
        #expect(
            NotificationIcon.system(" checkmark.circle ").normalized()
                == .system("checkmark.circle")
        )
    }

    @Test(arguments: [
        (nil, 4.0),
        (-1.0, 1.0),
        (0.0, 1.0),
        (1.0, 1.0),
        (3.5, 3.5),
        (5.0, 5.0),
        (8.0, 5.0),
        (Double.infinity, 4.0),
        (Double.nan, 4.0),
    ])
    func temporaryDurationIsNormalized(
        requested: Double?,
        expected: Double
    ) {
        #expect(
            NotificationLifetime
                .normalizedTemporary(requested)
                .temporaryDuration == expected
        )
    }

    @Test
    func successfulFeedbackCannotBecomePersistent() {
        let feedback = NotificationTestFixtures.feedback()
        let requested = FloatingNotificationConfiguration(
            lifetime: .persistentUntilReplaced,
            closePolicy: .hidden
        )
        let normalized = requested.normalized(for: feedback)

        #expect(normalized.lifetime == .temporary(seconds: 4))
        #expect(normalized.closePolicy == .hidden)
    }

    @Test
    func failedFeedbackCannotExpireAutomatically() {
        let feedback = NotificationTestFixtures.feedback(state: .failed)
        let requested = FloatingNotificationConfiguration(
            lifetime: .temporary(seconds: 2),
            closePolicy: .shown
        )

        #expect(
            requested.normalized(for: feedback).lifetime
                == .persistentUntilReplaced
        )
    }

    @Test
    func hiddenPersistentCardReceivesASafeClosePath() {
        let feedback = NotificationTestFixtures.feedback(state: .failed)
        let requested = FloatingNotificationConfiguration(
            lifetime: .persistentUntilReplaced,
            closePolicy: .hidden
        )

        #expect(
            requested.normalized(for: feedback).closePolicy == .shown
        )
    }

    @Test
    func hiddenPersistentCardMayUseATypedAction() {
        let feedback = NotificationTestFixtures.feedback(state: .failed)
        let action = NotificationTestFixtures.action()
        let requested = FloatingNotificationConfiguration(
            lifetime: .persistentUntilReplaced,
            closePolicy: .hidden,
            action: action
        )
        let normalized = requested.normalized(for: feedback)

        #expect(normalized.closePolicy == .hidden)
        #expect(normalized.action == action)
    }

    @Test
    func messageLineLimitAndBlankIconNameNormalizeSafely() {
        let configuration = FloatingNotificationConfiguration(
            icon: .system(""),
            lifetime: .temporary(seconds: 4),
            closePolicy: .shown,
            messageLineLimit: 0
        )

        #expect(configuration.icon == .automatic)
        #expect(configuration.messageLineLimit == 1)
    }

    @Test
    func destinationSnapshotIsAnImmutableProjection() {
        let entry = NotificationTestFixtures.entry()
        let snapshot = NotificationTestFixtures.snapshot(visible: [entry])

        #expect(snapshot.destination == .main)
        #expect(snapshot.visible == [entry])
        #expect(snapshot.queuedCount == 0)
        #expect(snapshot.isHostAttached)
    }

    @Test
    func batchRowPositionOmitsOnlyTheFinalDivider() {
        let first = BatchRowPosition(
            itemID: NotificationTestFixtures.itemID,
            index: 0,
            count: 2
        )
        let last = BatchRowPosition(
            itemID: UUID(),
            index: 1,
            count: 2
        )

        #expect(first.showsDivider)
        #expect(!last.showsDivider)
    }

    @Test
    func batchRowPositionsCoverEmptySingleAndMultipleSnapshots() {
        #expect(BatchRowPosition.positions(for: []).isEmpty)

        let singleID = UUID()
        let single = BatchRowPosition.positions(for: [singleID])
        #expect(single.count == 1)
        #expect(single[0].itemID == singleID)
        #expect(!single[0].showsDivider)

        let ids = (0..<4).map { _ in UUID() }
        let multiple = BatchRowPosition.positions(for: ids)
        #expect(multiple.map(\.itemID) == ids)
        #expect(multiple.map(\.index) == [0, 1, 2, 3])
        #expect(multiple.map(\.showsDivider) == [true, true, true, false])
    }

    @Test
    func batchRowPositionsRecomputeAfterReorderAndRemoval() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let originalIDs = [first, second, third]
        let stableSnapshot = BatchRowPosition.positions(for: originalIDs)

        let reordered = BatchRowPosition.positions(
            for: [third, first, second]
        )
        let removed = BatchRowPosition.positions(for: [first, third])

        #expect(stableSnapshot.map(\.itemID) == originalIDs)
        #expect(stableSnapshot.map(\.showsDivider) == [true, true, false])
        #expect(reordered.map(\.itemID) == [third, first, second])
        #expect(reordered.map(\.showsDivider) == [true, true, false])
        #expect(removed.map(\.itemID) == [first, third])
        #expect(removed.map(\.showsDivider) == [true, false])
    }
}
