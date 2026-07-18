import XCTest
@testable import PageForge

@MainActor
final class OperationJobCoordinatorTests: XCTestCase {
    func testEnqueueCreatesQueuedJobUntilExplicitlyStarted() {
        let coordinator = OperationJobCoordinator(logService: LogService())
        let source = URL(fileURLWithPath: "/tmp/book.epub")

        let id = coordinator.enqueue(
            kind: .readinessPrepare,
            sources: [source],
            message: "Waiting to prepare"
        )

        let queuedJob = coordinator.jobs.first(where: { $0.id == id })
        XCTAssertEqual(queuedJob?.state, .queued)
        XCTAssertEqual(queuedJob?.sourcePaths, [source])
        XCTAssertNil(queuedJob?.finishedAt)

        coordinator.start(id: id, message: "Preparing")

        let runningJob = coordinator.jobs.first(where: { $0.id == id })
        XCTAssertEqual(runningJob?.state, .running)
        XCTAssertEqual(runningJob?.progressMessage, "Preparing")
    }

    func testCancelPendingCancelsOnlyQueuedJobsInRequestedSet() {
        let coordinator = OperationJobCoordinator(logService: LogService())
        let firstID = coordinator.enqueue(
            kind: .readinessPrepare,
            sources: [URL(fileURLWithPath: "/tmp/first.epub")],
            message: "Queued"
        )
        let secondID = coordinator.enqueue(
            kind: .readinessPrepare,
            sources: [URL(fileURLWithPath: "/tmp/second.epub")],
            message: "Queued"
        )
        let untouchedID = coordinator.enqueue(
            kind: .readinessPrepare,
            sources: [URL(fileURLWithPath: "/tmp/untouched.epub")],
            message: "Queued"
        )
        coordinator.start(id: firstID, message: "Preparing")

        let cancelled = coordinator.cancelPending(ids: [firstID, secondID])

        XCTAssertEqual(cancelled, [secondID])
        XCTAssertEqual(coordinator.jobs.first(where: { $0.id == firstID })?.state, .running)
        XCTAssertEqual(coordinator.jobs.first(where: { $0.id == secondID })?.state, .cancelled)
        XCTAssertNotNil(coordinator.jobs.first(where: { $0.id == secondID })?.finishedAt)
        XCTAssertEqual(coordinator.jobs.first(where: { $0.id == untouchedID })?.state, .queued)
    }

    func testRunningJobReconcilesToActualTerminalResultAfterPendingCancellation() {
        let coordinator = OperationJobCoordinator(logService: LogService())
        let activeID = coordinator.enqueue(
            kind: .convert,
            sources: [URL(fileURLWithPath: "/tmp/active.pdf")],
            message: "Queued"
        )
        let pendingID = coordinator.enqueue(
            kind: .convert,
            sources: [URL(fileURLWithPath: "/tmp/pending.pdf")],
            message: "Queued"
        )
        coordinator.start(id: activeID, message: "Converting")

        coordinator.cancelPending()
        coordinator.reconcile(
            id: activeID,
            state: .succeeded,
            resultRef: "/tmp/active-kindle-ready.epub",
            message: "Prepared"
        )

        let activeJob = coordinator.jobs.first(where: { $0.id == activeID })
        XCTAssertEqual(activeJob?.state, .succeeded)
        XCTAssertEqual(activeJob?.resultRef, "/tmp/active-kindle-ready.epub")
        XCTAssertNotNil(activeJob?.finishedAt)
        XCTAssertEqual(coordinator.jobs.first(where: { $0.id == pendingID })?.state, .cancelled)
    }

    func testTerminalJobCannotBeReconciledAgain() {
        let coordinator = OperationJobCoordinator(logService: LogService())
        let id = coordinator.start(
            kind: .send,
            sources: [URL(fileURLWithPath: "/tmp/book.epub")],
            message: "Sending"
        )

        coordinator.succeed(id: id, resultRef: "sent", message: "Sent")
        coordinator.fail(id: id, message: "Late failure")

        let job = coordinator.jobs.first(where: { $0.id == id })
        XCTAssertEqual(job?.state, .succeeded)
        XCTAssertEqual(job?.resultRef, "sent")
        XCTAssertNil(job?.errorMessage)
    }
}
