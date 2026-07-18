import XCTest
@testable import PageForge

@MainActor
final class DocumentWorkflowOutputTests: XCTestCase {
    func testSaveAndSendUseOnlySelectedReadyItemsAndKeepIndependentResults() async throws {
        let factory = try TemporaryDocumentFactory()
        let ready = try makeReadyItem(factory: factory, name: "ready", selected: true)
        let unselected = try makeReadyItem(factory: factory, name: "unselected", selected: false)
        let queuedURL = try factory.makeEPUB(named: "queued.epub")
        let queued = DocumentItem(
            sourceURL: queuedURL,
            canonicalIdentity: queuedURL.path,
            format: .epub
        )
        let exporter = MockPreparedOutputExporter()
        let delivery = MockDocumentDelivery()
        let viewModel = DocumentWorkflowViewModel(
            exporter: exporter,
            delivery: delivery,
            initialQueue: DocumentQueue(items: [ready, unselected, queued])
        )
        viewModel.selectedProfileName = "reader"

        viewModel.saveSelected(to: factory.directoryURL)
        await waitUntil { !viewModel.isSaving }

        XCTAssertEqual(
            exporter.requests.first?.outputs.map(\.outputURL),
            [ready.preparedOutput?.outputURL].compactMap { $0 }
        )
        XCTAssertEqual(viewModel.queue.items[0].saveState, .succeeded)
        XCTAssertEqual(viewModel.queue.items[0].deliveryState, .idle)
        XCTAssertNil(viewModel.queue.items[1].saveResult)

        viewModel.sendSelected()
        await waitUntil { !viewModel.isSending }

        XCTAssertEqual(delivery.sentSources, [ready.preparedOutput?.outputURL].compactMap { $0 })
        XCTAssertEqual(viewModel.queue.items[0].saveState, .succeeded)
        XCTAssertEqual(viewModel.queue.items[0].deliveryState, .succeeded)
        XCTAssertNil(viewModel.queue.items[1].deliveryResult)
    }

    func testSaveConflictCanRetryWithExplicitReplacementWithoutChangingReadiness() async throws {
        let factory = try TemporaryDocumentFactory()
        let item = try makeReadyItem(factory: factory, name: "conflict", selected: true)
        let exporter = MockPreparedOutputExporter(conflictUntilReplacement: true)
        let viewModel = DocumentWorkflowViewModel(
            exporter: exporter,
            initialQueue: DocumentQueue(items: [item])
        )

        viewModel.saveSelected(to: factory.directoryURL)
        await waitUntil { !viewModel.isSaving }
        XCTAssertEqual(viewModel.queue.items[0].saveState, .failed)
        XCTAssertEqual(viewModel.queue.items[0].preparationState, .ready)

        viewModel.saveSelected(to: factory.directoryURL, replacingExisting: true)
        await waitUntil { !viewModel.isSaving }

        XCTAssertEqual(exporter.requests.map(\.conflictPolicy), [.failIfExists, .replaceConfirmed])
        XCTAssertEqual(viewModel.queue.items[0].saveState, .succeeded)
        XCTAssertEqual(viewModel.queue.items[0].preparationState, .ready)
    }

    func testDeliveryPreflightFailureSendsNothingAndPreservesSaveResult() throws {
        let factory = try TemporaryDocumentFactory()
        var item = try makeReadyItem(factory: factory, name: "book", selected: true)
        let outputURL = try XCTUnwrap(item.preparedOutput?.outputURL)
        item.saveResult = ExportResult(
            sourceOutputURL: outputURL,
            destinationURL: outputURL,
            state: .succeeded,
            message: "Saved"
        )
        let delivery = MockDocumentDelivery(preflightError: DomainError.configuration(
            "Profile is incomplete. Open Settings."
        ))
        let viewModel = DocumentWorkflowViewModel(
            delivery: delivery,
            initialQueue: DocumentQueue(items: [item])
        )

        viewModel.sendSelected()

        XCTAssertEqual(delivery.sentSources, [])
        XCTAssertEqual(viewModel.statusMessage, "Profile is incomplete. Open Settings.")
        XCTAssertEqual(viewModel.queue.items[0].saveState, .succeeded)
        XCTAssertEqual(viewModel.queue.items[0].deliveryState, .idle)
    }

    func testRemoveSelectedNeverDeletesSourceOrPreparedOutput() throws {
        let factory = try TemporaryDocumentFactory()
        let item = try makeReadyItem(factory: factory, name: "preserved", selected: true)
        let sourceURL = item.sourceURL
        let outputURL = try XCTUnwrap(item.preparedOutput?.outputURL)
        let viewModel = DocumentWorkflowViewModel(initialQueue: DocumentQueue(items: [item]))

        viewModel.removeSelected()

        XCTAssertTrue(viewModel.queue.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    private func makeReadyItem(
        factory: TemporaryDocumentFactory,
        name: String,
        selected: Bool
    ) throws -> DocumentItem {
        let source = try factory.makeEPUB(named: "\(name).epub")
        let output = try factory.makeEPUB(named: "\(name)-kindle-ready.epub")
        return DocumentItem(
            sourceURL: source,
            canonicalIdentity: source.path,
            format: .epub,
            isSelected: selected,
            preparationState: .ready,
            preparedOutput: PreparedOutput(
                sourceURL: source,
                outputURL: output,
                sizeBytes: 12,
                readinessStatus: .ready
            )
        )
    }

    private func waitUntil(
        attempts: Int = 400,
        condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<attempts {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Timed out waiting for output operation")
    }
}

private final class MockPreparedOutputExporter: PreparedOutputExporting, @unchecked Sendable {
    struct Request {
        let outputs: [PreparedOutput]
        let destinationDirectory: URL
        let conflictPolicy: OutputConflictPolicy
    }

    private let lock = NSLock()
    private let conflictUntilReplacement: Bool
    private var storedRequests: [Request] = []

    init(conflictUntilReplacement: Bool = false) {
        self.conflictUntilReplacement = conflictUntilReplacement
    }

    var requests: [Request] {
        lock.withLock { storedRequests }
    }

    func export(
        outputs: [PreparedOutput],
        destinationDirectory: URL,
        conflictPolicy: OutputConflictPolicy
    ) -> [ExportResult] {
        lock.withLock {
            storedRequests.append(Request(
                outputs: outputs,
                destinationDirectory: destinationDirectory,
                conflictPolicy: conflictPolicy
            ))
        }
        return outputs.map { output in
            let isConflict = conflictUntilReplacement && conflictPolicy == .failIfExists
            return ExportResult(
                sourceOutputURL: output.outputURL,
                destinationURL: destinationDirectory.appendingPathComponent(
                    output.outputURL.lastPathComponent
                ),
                state: isConflict ? .failed : .succeeded,
                message: isConflict ? "Confirm replacement." : "Saved"
            )
        }
    }
}

private final class MockDocumentDelivery: DocumentDelivering {
    private let lock = NSLock()
    private let preflightError: Error?
    private var sources: [URL] = []

    init(preflightError: Error? = nil) {
        self.preflightError = preflightError
    }

    var sentSources: [URL] {
        lock.withLock { sources }
    }

    func validateForSend(source: URL, profileName: String?) throws -> DeliveryProfile {
        if let preflightError { throw preflightError }
        return DeliveryProfile(
            name: profileName ?? "reader",
            senderEmail: "sender@example.com",
            kindleEmail: "reader@kindle.com"
        )
    }

    func send(source: URL, profileName: String?) throws -> SendResult {
        lock.withLock { sources.append(source) }
        return SendResult(
            inputPath: source,
            senderEmail: "sender@example.com",
            kindleEmail: "reader@kindle.com",
            profileName: profileName ?? "reader"
        )
    }
}
