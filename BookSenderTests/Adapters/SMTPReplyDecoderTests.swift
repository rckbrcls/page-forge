import Foundation
import Testing
@testable import BookSender

struct SMTPReplyDecoderTests {
    @Test
    func parsesValidatedEnhancedStatusWithoutCopyingProviderProseIntoStatus() throws {
        var decoder = SMTPReplyDecoder()

        let reply = try #require(
            decoder.append(
                Data("535 5.7.8 \(DiagnosticTestFixtures.providerProse)\r\n".utf8)
            ).first
        )

        #expect(reply.providerStatus?.replyCode == 535)
        #expect(reply.providerStatus?.enhancedStatus?.description == "5.7.8")
        #expect(
            String(describing: reply.providerStatus)
                .contains(DiagnosticTestFixtures.providerProse) == false
        )
    }

    @Test
    func omitsAbsentOrMalformedEnhancedStatus() throws {
        var absentDecoder = SMTPReplyDecoder()
        let absent = try #require(
            absentDecoder.append(Data("550 Rejected\r\n".utf8)).first
        )
        #expect(absent.providerStatus?.enhancedStatus == nil)

        var malformedDecoder = SMTPReplyDecoder()
        let malformed = try #require(
            malformedDecoder.append(Data("535 9.1000.2 Rejected\r\n".utf8)).first
        )
        #expect(malformed.providerStatus?.enhancedStatus == nil)
        #expect(malformed.providerStatus?.replyCode == 535)
    }

    @Test
    func preservesMultilineFramingAndUsesTheFirstValidEnhancedStatus() throws {
        var decoder = SMTPReplyDecoder()
        let replies = try decoder.append(
            Data("550-first line\r\n550-5.1.1 mailbox unavailable\r\n550 final\r\n".utf8)
        )

        #expect(replies.count == 1)
        #expect(replies[0].lines.count == 3)
        #expect(replies[0].providerStatus?.enhancedStatus?.description == "5.1.1")
    }
}
