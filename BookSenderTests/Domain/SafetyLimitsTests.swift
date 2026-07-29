import Testing
@testable import BookSender

struct SafetyLimitsTests {
    private let limits = SafetyLimits.standard

    @Test(arguments: [-1, 0, 1])
    func batchBoundary(offset: Int) {
        #expect(
            limits.permitsBatchItemCount(limits.maximumBatchItems + offset)
                == (offset <= 0)
        )
    }

    @Test(arguments: Int64(-1)...Int64(1))
    func bookBoundary(offset: Int64) {
        #expect(
            limits.permitsBookBytes(limits.maximumBookBytes + offset)
                == (offset <= 0)
        )
    }

    @Test(arguments: [-1, 0, 1])
    func archiveEntryBoundary(offset: Int) {
        #expect(
            limits.permitsArchiveEntryCount(
                limits.maximumArchiveEntries + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: Int64(-1)...Int64(1))
    func compressedArchiveBoundary(offset: Int64) {
        #expect(
            limits.permitsCompressedBytes(
                limits.maximumCompressedBytes + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: Int64(-1)...Int64(1))
    func expandedArchiveBoundary(offset: Int64) {
        #expect(
            limits.permitsExpandedBytes(
                limits.maximumExpandedBytes + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: [-1, 0, 1])
    func xmlDepthBoundary(offset: Int) {
        #expect(
            limits.permitsXMLDepth(limits.maximumXMLDepth + offset)
                == (offset <= 0)
        )
    }

    @Test(arguments: [-1, 0, 1])
    func xmlElementBoundary(offset: Int) {
        #expect(
            limits.permitsXMLElementCount(
                limits.maximumXMLElements + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: [-1, 0, 1])
    func smtpLineBoundary(offset: Int) {
        #expect(
            limits.permitsSMTPLineBytes(
                limits.maximumSMTPLineBytes + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: [-1, 0, 1])
    func smtpReplyBoundary(offset: Int) {
        #expect(
            limits.permitsSMTPReplyLines(
                limits.maximumSMTPReplyLines + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: Int64(-1)...Int64(1))
    func attachmentBoundary(offset: Int64) {
        #expect(
            limits.permitsAttachmentBytes(
                limits.maximumAttachmentBytes + offset
            ) == (offset <= 0)
        )
    }

    @Test(arguments: Int64(-1)...Int64(1))
    func operationTimeoutBoundary(offset: Int64) {
        let limit = limits.operationTimeout.components.seconds
        #expect(
            limits.permitsOperationElapsed(.seconds(limit + offset))
                == (offset <= 0)
        )
    }

    @Test(arguments: [TimeInterval(-1), 0, 1])
    func orphanAgeBoundary(offset: TimeInterval) {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let threshold = TimeInterval(limits.orphanAge.components.seconds)
        let modified = now.addingTimeInterval(-(threshold + offset))
        #expect(limits.isOrphan(lastModified: modified, now: now) == (offset >= 0))
    }
}
