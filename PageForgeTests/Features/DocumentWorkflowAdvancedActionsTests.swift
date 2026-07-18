import XCTest
@testable import PageForge

@MainActor
final class DocumentWorkflowAdvancedActionsTests: XCTestCase {
    func testMetadataActionsAreContextualToSelectedExistingRow() throws {
        let factory = try TemporaryDocumentFactory()
        let selectedURL = try factory.makeEPUB(named: "selected.epub")
        let unselectedURL = try factory.makeEPUB(named: "unselected.epub")
        let selected = makeItem(source: selectedURL, selected: true)
        let unselected = makeItem(source: unselectedURL, selected: false)
        let metadata = MockWorkflowMetadataService()
        let viewModel = DocumentWorkflowViewModel(
            metadataService: metadata,
            initialQueue: DocumentQueue(items: [selected, unselected])
        )

        XCTAssertTrue(viewModel.canInspectMetadata(selected.id))
        XCTAssertFalse(viewModel.canInspectMetadata(unselected.id))
        XCTAssertFalse(viewModel.canInspectMetadata(UUID()))

        viewModel.inspectMetadata(unselected.id)
        XCTAssertTrue(metadata.inspectedSources.isEmpty)

        viewModel.inspectMetadata(selected.id)
        XCTAssertEqual(metadata.inspectedSources, [selectedURL])
        XCTAssertEqual(viewModel.metadataTitle, "Fixture Title")
        XCTAssertEqual(viewModel.metadataAuthor, "Fixture Author")

        viewModel.metadataTitle = "Updated Title"
        viewModel.metadataAuthor = "Updated Author"
        viewModel.saveMetadata()
        XCTAssertEqual(metadata.updates.first?.title, "Updated Title")
        XCTAssertEqual(metadata.updates.first?.author, "Updated Author")
    }

    func testAggressiveRepairRequiresEligibleEPUBAndExplicitConfirmation() async throws {
        let factory = try TemporaryDocumentFactory()
        let epubURL = try factory.makeEPUB(named: "failed.epub")
        let mobiURL = try factory.makeMOBI(named: "failed.mobi")
        let eligible = makeItem(
            source: epubURL,
            selected: true,
            format: .epub,
            state: .failed
        )
        let wrongFormat = makeItem(
            source: mobiURL,
            selected: true,
            format: .mobi,
            state: .failed
        )
        let repair = MockWorkflowRepairService(outputDirectory: factory.directoryURL)
        let viewModel = DocumentWorkflowViewModel(
            repairService: repair,
            initialQueue: DocumentQueue(items: [eligible, wrongFormat])
        )

        XCTAssertTrue(viewModel.canAggressivelyRepair(eligible.id))
        XCTAssertFalse(viewModel.canAggressivelyRepair(wrongFormat.id))

        viewModel.aggressiveRepair(eligible.id, confirmed: false)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(repair.requests.isEmpty)

        viewModel.aggressiveRepair(eligible.id, confirmed: true)
        await waitUntil { repair.requests.count == 1 }

        XCTAssertEqual(repair.requests.first?.source, epubURL)
        XCTAssertEqual(repair.requests.first?.mode, .aggressive)
        XCTAssertEqual(repair.requests.first?.overwrite, false)
    }

    func testAdvancedActionsDoNotRunDuringDefaultIntake() throws {
        let factory = try TemporaryDocumentFactory()
        let source = try factory.makeEPUB()
        let metadata = MockWorkflowMetadataService()
        let repair = MockWorkflowRepairService(outputDirectory: factory.directoryURL)
        let viewModel = DocumentWorkflowViewModel(
            metadataService: metadata,
            repairService: repair
        )

        viewModel.addFiles([source])

        XCTAssertEqual(viewModel.queue.items.count, 1)
        XCTAssertNil(viewModel.inspectedMetadata)
        XCTAssertTrue(metadata.inspectedSources.isEmpty)
        XCTAssertTrue(repair.requests.isEmpty)
    }

    private func makeItem(
        source: URL,
        selected: Bool,
        format: DocumentFormat = .epub,
        state: PreparationState = .queued
    ) -> DocumentItem {
        DocumentItem(
            sourceURL: source,
            canonicalIdentity: source.path,
            format: format,
            isSelected: selected,
            preparationState: state
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
        XCTFail("Timed out waiting for advanced action")
    }
}

private final class MockWorkflowMetadataService: WorkflowMetadataServicing {
    struct Update {
        let source: URL
        let title: String?
        let author: String?
    }

    private(set) var inspectedSources: [URL] = []
    private(set) var updates: [Update] = []

    func inspect(source: URL) throws -> BookMetadata {
        inspectedSources.append(source)
        return BookMetadata(
            path: source,
            raw: "Fixture metadata",
            fields: ["Title": "Fixture Title", "Author(s)": "Fixture Author"]
        )
    }

    func update(source: URL, title: String?, author: String?) throws -> BookMetadata {
        updates.append(Update(source: source, title: title, author: author))
        return BookMetadata(
            path: source,
            raw: "Updated metadata",
            fields: ["Title": title ?? "", "Author(s)": author ?? ""]
        )
    }
}

private final class MockWorkflowRepairService: WorkflowRepairing {
    struct Request {
        let source: URL
        let mode: RepairMode
        let overwrite: Bool
    }

    private let lock = NSLock()
    private let outputDirectory: URL
    private var storedRequests: [Request] = []

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    var requests: [Request] {
        lock.withLock { storedRequests }
    }

    func repair(
        source: URL,
        mode: RepairMode,
        output: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> RepairResult {
        lock.withLock {
            storedRequests.append(Request(source: source, mode: mode, overwrite: overwrite))
        }
        return RepairResult(
            inputPath: source,
            outputPath: output ?? outputDirectory.appendingPathComponent("repaired.epub"),
            mode: mode
        )
    }
}
