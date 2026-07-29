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
        #expect(encoder.encodedFilename("a b.pdf").contains("%20"))
        #expect(encoder.asciiFilename("livro-é.pdf").isEmpty == false)
    }

    @Test
    func streamsCRLFHeadersAndWrappedBase64WithoutLoadingResultIntoProduction() async throws {
        let directory = try FixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(component: "book.pdf")
        try Data((0..<1_024).map { UInt8($0 % 251) }).write(to: file)
        let book = PreparedBook(
            id: UUID(),
            batchItemID: UUID(),
            file: StagedFileReference(identifier: UUID(), url: file),
            originalDisplayName: "My Book é.pdf",
            format: .pdf,
            byteCount: 1_024,
            contentDigest: "digest",
            comparison: nil
        )
        let sink = MIMEDataSink()

        try await MIMEMessageEncoder().streamMessage(
            book: book,
            envelope: SMTPEnvelope(
                sender: try EmailAddress("sender@example.com"),
                recipient: try EmailAddress("reader@kindle.com")
            )
        ) { data in
            await sink.append(data)
        }

        let message = String(
            decoding: await sink.data,
            as: UTF8.self
        )
        #expect(message.contains("\r\n"))
        #expect(message.contains("filename*=UTF-8''My%20Book%20%C3%A9.pdf"))
        #expect(message.contains("\nBcc:") == false)
        let base64Lines = message.components(separatedBy: "\r\n").filter {
            !$0.isEmpty
                && $0.allSatisfy {
                    $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "="
                }
        }
        #expect(base64Lines.allSatisfy { $0.count <= 76 })
    }

    @Test
    func dotStuffsOnlyAtLineStartsAcrossChunks() async {
        let framer = SMTPDataFramer()
        let first = await framer.frame(Data(".first\r\n.".utf8))
        let second = await framer.frame(Data("second\r\nthird".utf8))

        #expect(String(decoding: first + second, as: UTF8.self)
            == "..first\r\n..second\r\nthird")
    }
}

private actor MIMEDataSink {
    private(set) var data = Data()

    func append(_ chunk: Data) {
        data.append(chunk)
    }
}
