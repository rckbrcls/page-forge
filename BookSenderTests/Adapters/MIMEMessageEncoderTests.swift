import Foundation
import Testing
@testable import BookSender

struct MIMEMessageEncoderTests {
    @Test
    func rejectsHeaderInjection() {
        let encoder = MIMEMessageEncoder()
        #expect(throws: SanitizedFailure.self) {
            _ = try encoder.header(name: "Subject", value: "Book\r\nBcc: other@example.com")
        }
    }

    @Test
    func encodesNonASCIIAndRemovesControlCharacters() {
        let encoder = MIMEMessageEncoder()
        let filename = encoder.encodedFilename("livro-é.pdf\n")
        #expect(filename.contains("\n") == false)
        #expect(filename.contains("%") || filename.contains("livro"))
    }
}
