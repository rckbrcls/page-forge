import XCTest
@testable import PageForge

final class DocumentWorkflowModelsTests: XCTestCase {
    func testDocumentItemStartsSelectedAndQueued() {
        let item = makeItem()

        XCTAssertTrue(item.isSelected)
        XCTAssertEqual(item.preparationState, .queued)
        XCTAssertEqual(item.saveState, .idle)
        XCTAssertEqual(item.deliveryState, .idle)
        XCTAssertTrue(item.isPreparationEligible)
    }

    func testProgressFractionIsClampedToValidRange() {
        var item = makeItem(progressFraction: -0.5)
        XCTAssertEqual(item.progressFraction, 0)
        item.progressFraction = 1.5
        XCTAssertEqual(item.progressFraction, 1)
    }

    func testPreparationStateTransitionsSupportFailureRetryAndPendingCancellation() {
        var item = makeItem()

        item.beginPreparation(message: "Validating document")
        XCTAssertEqual(item.preparationState, .preparing)
        XCTAssertEqual(item.progressMessage, "Validating document")
        XCTAssertFalse(item.cancelIfQueued())

        item.failPreparation(with: OperationIssue(
            category: .conversion,
            message: "Conversion failed.",
            recoveryAction: .retry
        ))
        XCTAssertEqual(item.preparationState, .failed)
        XCTAssertTrue(item.resetForRetry())
        XCTAssertEqual(item.preparationState, .queued)
        XCTAssertNil(item.issue)
        XCTAssertTrue(item.cancelIfQueued())
        XCTAssertEqual(item.preparationState, .cancelled)
    }

    func testSaveAndDeliveryResultsAreIndependent() {
        let outputURL = URL(fileURLWithPath: "/tmp/book-kindle-ready.epub")
        var item = makeItem(preparationState: .ready)
        item.saveResult = ExportResult(
            sourceOutputURL: outputURL,
            destinationURL: URL(fileURLWithPath: "/tmp/export/book-kindle-ready.epub"),
            state: .succeeded,
            message: "Saved"
        )
        item.deliveryResult = DocumentDeliveryResult(
            outputURL: outputURL,
            profileName: "Kindle",
            kindleEmail: nil,
            state: .failed,
            message: "Delivery failed"
        )

        XCTAssertEqual(item.preparationState, .ready)
        XCTAssertEqual(item.saveState, .succeeded)
        XCTAssertEqual(item.deliveryState, .failed)
    }

    func testIntakeSummaryPreservesInputOrderAndCountsOutcomes() {
        let acceptedURL = URL(fileURLWithPath: "/tmp/accepted.epub")
        let rejectedURL = URL(fileURLWithPath: "/tmp/rejected.txt")
        let summary = IntakeSummary(outcomes: [
            IntakeOutcome(
                originalURL: rejectedURL,
                rejection: IntakeRejection(reason: .unsupportedType, message: "Unsupported"),
                inputIndex: 1
            ),
            IntakeOutcome(originalURL: acceptedURL, acceptedItem: makeItem(), inputIndex: 0)
        ])

        XCTAssertEqual(summary.outcomes.map(\.originalURL), [acceptedURL, rejectedURL])
        XCTAssertEqual(summary.acceptedCount, 1)
        XCTAssertEqual(summary.rejectedCount, 1)
    }

    func testQueueDerivesEmptyReadyProcessingAndCompletionStates() {
        XCTAssertEqual(DocumentQueue().state, .empty)
        XCTAssertEqual(DocumentQueue(items: [makeItem()]).state, .readyToPrepare)
        XCTAssertEqual(
            DocumentQueue(items: [makeItem(preparationState: .preparing)]).state,
            .processing
        )
        XCTAssertEqual(
            DocumentQueue(items: [makeItem(preparationState: .ready)]).state,
            .completed
        )
        XCTAssertEqual(
            DocumentQueue(items: [
                makeItem(preparationState: .ready),
                makeItem(preparationState: .failed)
            ]).state,
            .partiallyCompleted
        )
    }

    func testQueueSelectionControlsPreparationEligibility() {
        let selectedQueued = makeItem(isSelected: true, preparationState: .queued)
        let unselectedQueued = makeItem(isSelected: false, preparationState: .queued)
        let selectedReady = makeItem(isSelected: true, preparationState: .ready)
        let queue = DocumentQueue(items: [selectedQueued, unselectedQueued, selectedReady])

        XCTAssertEqual(queue.selectedItems.map(\.id), [selectedQueued.id, selectedReady.id])
        XCTAssertEqual(queue.selectedQueuedItems.map(\.id), [selectedQueued.id])
        XCTAssertEqual(queue.selectedPreparationEligibleItems.map(\.id), [selectedQueued.id])
        XCTAssertTrue(queue.canPrepare)
        XCTAssertTrue(queue.canRemove)
    }

    func testRetryEligibilityIncludesRecoverableTerminalStates() {
        for state in [
            PreparationState.needsAttention,
            .blocked,
            .failed,
            .cancelled
        ] {
            let queue = DocumentQueue(items: [makeItem(preparationState: state)])
            XCTAssertTrue(queue.canRetry, "Expected \(state) to be retryable")
            XCTAssertTrue(queue.canPrepare, "Expected \(state) to be preparation eligible")
        }
    }

    func testReadyOutputEligibilityRequiresSelectionAndReadableOutput() throws {
        let factory = try TemporaryDocumentFactory()
        let sourceURL = try factory.makeEPUB()
        let outputURL = try factory.makeEPUB(named: "book-kindle-ready.epub")
        let output = PreparedOutput(
            sourceURL: sourceURL,
            outputURL: outputURL,
            sizeBytes: 12,
            readinessStatus: .ready
        )
        var item = makeItem(preparationState: .ready, preparedOutput: output)

        XCTAssertTrue(item.isOutputEligible)
        XCTAssertEqual(DocumentQueue(items: [item]).selectedReadyItems.map(\.id), [item.id])

        item.isSelected = false
        XCTAssertFalse(item.isOutputEligible)
    }

    func testReadinessReportMapsToPreparationState() throws {
        let factory = try TemporaryDocumentFactory()
        let sourceURL = try factory.makeEPUB()
        let outputURL = try factory.makeEPUB(named: "book-kindle-ready.epub")
        let output = PreparedOutput(
            sourceURL: sourceURL,
            outputURL: outputURL,
            sizeBytes: 12,
            readinessStatus: .ready
        )
        var item = makeItem(preparationState: .preparing)

        item.reconcilePreparation(
            report: ReadinessReport(inputPath: sourceURL, status: .ready, outputPath: outputURL),
            output: output
        )

        XCTAssertEqual(item.preparationState, .ready)
        XCTAssertEqual(item.preparedOutput, output)
        XCTAssertEqual(item.progressFraction, 1)
    }

    func testProcessingDisablesPrepareAndRemove() {
        let queue = DocumentQueue(items: [makeItem()], isProcessing: true)

        XCTAssertEqual(queue.state, .processing)
        XCTAssertFalse(queue.canPrepare)
        XCTAssertFalse(queue.canRemove)
    }

    private func makeItem(
        isSelected: Bool = true,
        preparationState: PreparationState = .queued,
        progressFraction: Double? = nil,
        preparedOutput: PreparedOutput? = nil
    ) -> DocumentItem {
        let sourceURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).epub")
        return DocumentItem(
            sourceURL: sourceURL,
            canonicalIdentity: sourceURL.path,
            format: .epub,
            isSelected: isSelected,
            preparationState: preparationState,
            progressFraction: progressFraction,
            preparedOutput: preparedOutput
        )
    }
}
