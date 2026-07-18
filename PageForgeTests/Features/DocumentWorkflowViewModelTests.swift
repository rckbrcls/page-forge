import XCTest
@testable import PageForge

@MainActor
final class DocumentWorkflowViewModelTests: XCTestCase {
    func testAddSelectSelectAllRemoveAndIntakeSummary() throws {
        let factory = try TemporaryDocumentFactory()
        let epub = try factory.makeEPUB()
        let pdf = try factory.makePDF()
        let unsupported = try factory.makeUnsupportedFile()
        let viewModel = DocumentWorkflowViewModel()

        viewModel.addFiles([epub, unsupported, pdf])

        XCTAssertEqual(viewModel.queue.items.map(\.sourceURL), [epub, pdf])
        XCTAssertEqual(viewModel.queue.intakeSummary?.acceptedCount, 2)
        XCTAssertEqual(viewModel.queue.intakeSummary?.rejectedCount, 1)
        XCTAssertEqual(viewModel.statusMessage, "Added 2 file(s); rejected 1.")

        let firstID = try XCTUnwrap(viewModel.queue.items.first?.id)
        viewModel.setSelected(firstID, selected: false)
        XCTAssertFalse(viewModel.queue.items[0].isSelected)
        viewModel.selectAll(false)
        XCTAssertTrue(viewModel.queue.items.allSatisfy { !$0.isSelected })
        viewModel.selectAll(true)
        viewModel.removeSelected()
        XCTAssertTrue(viewModel.queue.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: epub.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdf.path))
    }

    func testAddingToExistingQueuePreservesRowsAndRejectsDuplicates() throws {
        let factory = try TemporaryDocumentFactory()
        let first = try factory.makeEPUB()
        let second = try factory.makeMOBI()
        let viewModel = DocumentWorkflowViewModel()
        viewModel.addFiles([first])
        let firstID = try XCTUnwrap(viewModel.queue.items.first?.id)
        viewModel.setSelected(firstID, selected: false)

        viewModel.addFiles([first, second])

        XCTAssertEqual(viewModel.queue.items.map(\.sourceURL), [first, second])
        XCTAssertFalse(viewModel.queue.items[0].isSelected)
        XCTAssertEqual(viewModel.queue.intakeSummary?.acceptedCount, 1)
        XCTAssertEqual(viewModel.queue.intakeSummary?.outcomes[0].rejection?.reason, .duplicate)
    }

    func testPreparationIsSequentialAndContinuesAfterPerItemFailure() async throws {
        let factory = try TemporaryDocumentFactory()
        let sources = try [
            factory.makeEPUB(named: "one.epub"),
            factory.makeEPUB(named: "two.epub"),
            factory.makeEPUB(named: "three.epub")
        ]
        let outputs = try sources.map {
            try factory.makeEPUB(named: "\($0.deletingPathExtension().lastPathComponent)-kindle-ready.epub")
        }
        let preparer = MockDocumentPreparer { source, _, _, progress in
            progress(PreparationProgress(message: "Preparing EPUB for Kindle"))
            if source == sources[1] {
                throw DomainError.conversion("Fixture conversion failed")
            }
            let index = sources.firstIndex(of: source)!
            return Self.result(source: source, output: outputs[index])
        }
        let viewModel = DocumentWorkflowViewModel(preparer: preparer)
        let appState = AppState()
        viewModel.bind(appState: appState)
        viewModel.addFiles(sources)

        viewModel.prepareSelected()
        await waitUntil { !viewModel.queue.isProcessing }
        withExtendedLifetime(appState) {}

        XCTAssertEqual(preparer.recordedSources, sources)
        XCTAssertEqual(viewModel.queue.items.map(\.preparationState), [.ready, .failed, .ready])
        XCTAssertEqual(viewModel.queue.items[1].issue?.category, .conversion)
        XCTAssertEqual(viewModel.queue.completedCount, 2)
    }

    func testPreparationSnapshotExcludesFilesAddedAfterStart() async throws {
        let factory = try TemporaryDocumentFactory()
        let first = try factory.makeEPUB(named: "first.epub")
        let later = try factory.makeEPUB(named: "later.epub")
        let output = try factory.makeEPUB(named: "first-kindle-ready.epub")
        let gate = DispatchSemaphore(value: 0)
        let preparer = MockDocumentPreparer { source, _, _, _ in
            gate.wait()
            return Self.result(source: source, output: output)
        }
        let viewModel = DocumentWorkflowViewModel(preparer: preparer)
        let appState = AppState()
        viewModel.bind(appState: appState)
        viewModel.addFiles([first])

        viewModel.prepareSelected()
        await waitUntil { preparer.recordedSources == [first] }
        viewModel.addFiles([later])
        gate.signal()
        await waitUntil { !viewModel.queue.isProcessing }
        withExtendedLifetime(appState) {}

        XCTAssertEqual(preparer.recordedSources, [first])
        XCTAssertEqual(viewModel.queue.items.map(\.preparationState), [.ready, .queued])
    }

    func testCancelPendingPreservesActiveResultAndCancelsNotStartedItems() async throws {
        let factory = try TemporaryDocumentFactory()
        let first = try factory.makeEPUB(named: "first.epub")
        let second = try factory.makeEPUB(named: "second.epub")
        let output = try factory.makeEPUB(named: "first-kindle-ready.epub")
        let gate = DispatchSemaphore(value: 0)
        let preparer = MockDocumentPreparer { source, _, _, _ in
            gate.wait()
            return Self.result(source: source, output: output)
        }
        let viewModel = DocumentWorkflowViewModel(preparer: preparer)
        let appState = AppState()
        viewModel.bind(appState: appState)
        viewModel.addFiles([first, second])

        viewModel.prepareSelected()
        await waitUntil { viewModel.queue.activeItemID == viewModel.queue.items.first?.id }
        viewModel.cancelPendingPreparation()
        gate.signal()
        await waitUntil { !viewModel.queue.isProcessing }
        withExtendedLifetime(appState) {}

        XCTAssertEqual(viewModel.queue.items.map(\.preparationState), [.ready, .cancelled])
        XCTAssertEqual(preparer.recordedSources, [first])
    }

    func testRetryReturnsFailedItemToQueued() throws {
        let factory = try TemporaryDocumentFactory()
        let source = try factory.makeEPUB()
        var item = DocumentItem(
            sourceURL: source,
            canonicalIdentity: source.path,
            format: .epub,
            preparationState: .failed,
            issue: OperationIssue(category: .conversion, message: "Failed")
        )
        item.isSelected = true
        let viewModel = DocumentWorkflowViewModel(initialQueue: DocumentQueue(items: [item]))

        viewModel.retry(item.id)

        XCTAssertEqual(viewModel.queue.items.first?.preparationState, .queued)
        XCTAssertNil(viewModel.queue.items.first?.issue)
    }

    private static func result(source: URL, output: URL) -> DocumentPreparationResult {
        let report = ReadinessReport(
            inputPath: source,
            status: .ready,
            outputPath: output
        )
        return DocumentPreparationResult(
            sourceURL: source,
            report: report,
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
        XCTFail("Timed out waiting for workflow state")
    }
}

private final class MockDocumentPreparer: DocumentPreparing {
    typealias Handler = (
        URL,
        DocumentFormat,
        Bool,
        (PreparationProgress) -> Void
    ) throws -> DocumentPreparationResult

    private let lock = NSLock()
    private let handler: Handler
    private var sources: [URL] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var recordedSources: [URL] {
        lock.withLock { sources }
    }

    func prepare(
        source: URL,
        format: DocumentFormat,
        overwrite: Bool,
        progress: @escaping (PreparationProgress) -> Void
    ) throws -> DocumentPreparationResult {
        lock.withLock { sources.append(source) }
        return try handler(source, format, overwrite, progress)
    }
}
