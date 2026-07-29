import Foundation

struct MIMEMessageEncoder: Sendable {
    private let lineLength = 76

    func header(name: String, value: String) throws -> Data {
        guard !name.contains(where: { $0.isNewline || $0 == ":" }),
              !value.contains(where: \.isNewline)
        else { throw failure("mime.header-injection") }
        return Data("\(name): \(value)\r\n".utf8)
    }

    func encodedFilename(_ filename: String) -> String {
        let clean = filename.filter { !$0.isNewline && !$0.isControl && $0 != "\"" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        if clean.unicodeScalars.allSatisfy(allowed.contains) { return clean }
        return "UTF-8''" + clean.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!.replacingOccurrences(of: "%20", with: " ")
    }

    func streamMessage(
        book: PreparedBook,
        envelope: SMTPEnvelope,
        write: @escaping @Sendable (Data) async throws -> Void
    ) async throws {
        let boundary = "BookSender-\(UUID().uuidString)"
        try await write(try header(name: "From", value: envelope.sender.value))
        try await write(try header(name: "To", value: envelope.recipient.value))
        try await write(try header(name: "Subject", value: "Book delivery"))
        try await write(try header(name: "MIME-Version", value: "1.0"))
        try await write(try header(name: "Content-Type", value: "multipart/mixed; boundary=\"\(boundary)\""))
        try await write(Data("\r\n--\(boundary)\r\n".utf8))
        try await write(Data("Content-Type: text/plain; charset=utf-8\r\n\r\nSent with Book Sender.\r\n".utf8))
        let mediaType = book.format == .epub ? "application/epub+zip" : "application/pdf"
        let filename = encodedFilename(book.originalDisplayName)
        try await write(Data("--\(boundary)\r\nContent-Type: \(mediaType)\r\n".utf8))
        try await write(Data("Content-Disposition: attachment; filename*=UTF-8''\(filename)\r\n".utf8))
        try await write(Data("Content-Transfer-Encoding: base64\r\n\r\n".utf8))

        let handle = try FileHandle(forReadingFrom: book.file.url)
        defer { try? handle.close() }
        var carry = Data()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 57 * 1_024) ?? Data()
            guard !chunk.isEmpty else { break }
            carry.append(chunk)
            let usable = carry.count - (carry.count % 57)
            guard usable > 0 else { continue }
            let bytes = carry.prefix(usable)
            carry.removeFirst(usable)
            try await writeWrappedBase64(Data(bytes), write: write)
        }
        if !carry.isEmpty { try await writeWrappedBase64(carry, write: write) }
        try await write(Data("\r\n--\(boundary)--\r\n".utf8))
    }

    private func writeWrappedBase64(
        _ data: Data,
        write: @escaping @Sendable (Data) async throws -> Void
    ) async throws {
        let encoded = data.base64EncodedString()
        var index = encoded.startIndex
        while index < encoded.endIndex {
            let end = encoded.index(index, offsetBy: lineLength, limitedBy: encoded.endIndex) ?? encoded.endIndex
            try await write(Data((encoded[index..<end] + "\r\n").utf8))
            index = end
        }
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: code,
            message: "The email message contains an invalid value.",
            recoveryAction: .editSetup
        )
    }
}
