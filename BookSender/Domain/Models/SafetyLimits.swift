import Foundation

struct SafetyLimits: Equatable, Sendable {
    let maximumBatchItems: Int
    let maximumBookBytes: Int64
    let maximumArchiveEntries: Int
    let maximumCompressedBytes: Int64
    let maximumExpandedBytes: Int64
    let maximumEntryBytes: Int64
    let maximumExpansionRatio: Double
    let maximumXMLBytes: Int
    let maximumXMLDepth: Int
    let maximumXMLElements: Int
    let maximumXMLAttributesPerElement: Int
    let maximumXMLTextBytes: Int
    let maximumSMTPLineBytes: Int
    let maximumSMTPReplyLines: Int
    let maximumAttachmentBytes: Int64
    let operationTimeout: Duration
    let smtpStageTimeout: Duration
    let orphanAge: Duration

    static let standard = SafetyLimits(
        maximumBatchItems: 100,
        maximumBookBytes: 50 * 1_024 * 1_024,
        maximumArchiveEntries: 10_000,
        maximumCompressedBytes: 50 * 1_024 * 1_024,
        maximumExpandedBytes: 250 * 1_024 * 1_024,
        maximumEntryBytes: 64 * 1_024 * 1_024,
        maximumExpansionRatio: 100,
        maximumXMLBytes: 8 * 1_024 * 1_024,
        maximumXMLDepth: 128,
        maximumXMLElements: 100_000,
        maximumXMLAttributesPerElement: 128,
        maximumXMLTextBytes: 8 * 1_024 * 1_024,
        maximumSMTPLineBytes: 998,
        maximumSMTPReplyLines: 100,
        maximumAttachmentBytes: 50 * 1_024 * 1_024,
        operationTimeout: .seconds(30),
        smtpStageTimeout: .seconds(20),
        orphanAge: .seconds(86_400)
    )

    func permitsArchiveEntryCount(_ value: Int) -> Bool { value <= maximumArchiveEntries }
    func permitsXMLDepth(_ value: Int) -> Bool { value <= maximumXMLDepth }
    func permitsAttachmentBytes(_ value: Int64) -> Bool { value <= maximumAttachmentBytes }
}
