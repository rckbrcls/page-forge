import Testing
@testable import BookSender

struct SafetyLimitsTests {
    private let limits = SafetyLimits.standard

    @Test(arguments: [-1, 0, 1])
    func archiveEntryBoundary(offset: Int) {
        let value = limits.maximumArchiveEntries + offset
        #expect(limits.permitsArchiveEntryCount(value) == (offset <= 0))
    }

    @Test(arguments: [-1, 0, 1])
    func xmlDepthBoundary(offset: Int) {
        let value = limits.maximumXMLDepth + offset
        #expect(limits.permitsXMLDepth(value) == (offset <= 0))
    }

    @Test(arguments: [-1, 0, 1])
    func attachmentBoundary(offset: Int64) {
        let value = limits.maximumAttachmentBytes + offset
        #expect(limits.permitsAttachmentBytes(value) == (offset <= 0))
    }
}
