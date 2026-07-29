import Foundation

struct MIMEMessageEncoder: Sendable {
    private let lineLength = 76

    func header(name: String, value: String) throws -> Data {
        guard !name.isEmpty,
              !name.contains(where: { $0.isNewline || $0 == ":" || $0.isControl }),
              !value.contains(where: { $0.isNewline || $0.isControl })
        else {
            throw failure("mime.header-injection")
        }
        return Data("\(name): \(value)\r\n".utf8)
    }

    func encodedFilename(_ filename: String) -> String {
        let clean = sanitizedFilename(filename)
        let allowed = CharacterSet(
            charactersIn:
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
        )
        return clean.addingPercentEncoding(withAllowedCharacters: allowed)
            ?? "book"
    }

    func asciiFilename(_ filename: String) -> String {
        let clean = sanitizedFilename(filename)
        let ascii = clean.unicodeScalars.map { scalar -> Character in
            scalar.isASCII ? Character(String(scalar)) : "_"
        }
        let result = String(ascii)
        return result.isEmpty ? "book" : result
    }

    func streamMessage(
        book: PreparedBook,
        envelope: SMTPEnvelope,
        write: @escaping @Sendable (Data) async throws -> Void
    ) async throws {
        try Task.checkCancellation()
        let boundary = "BookSender-\(UUID().uuidString)"
        try await write(try header(name: "From", value: envelope.sender.value))
        try await write(try header(name: "To", value: envelope.recipient.value))
        try await write(try header(name: "Subject", value: "Book delivery"))
        try await write(try header(name: "MIME-Version", value: "1.0"))
        try await write(
            try header(
                name: "Content-Type",
                value: "multipart/mixed; boundary=\"\(boundary)\""
            )
        )
        try await write(Data("\r\n--\(boundary)\r\n".utf8))
        try await write(
            Data(
                "Content-Type: text/plain; charset=utf-8\r\n"
                    .appending("Content-Transfer-Encoding: 7bit\r\n\r\n")
                    .appending("Sent with Book Sender.\r\n")
                    .utf8
            )
        )

        let mediaType = book.format == .epub
            ? "application/epub+zip"
            : "application/pdf"
        let encoded = encodedFilename(book.originalDisplayName)
        let ascii = asciiFilename(book.originalDisplayName)
            .replacingOccurrences(of: "\"", with: "_")
        try await write(Data("--\(boundary)\r\n".utf8))
        try await write(try header(name: "Content-Type", value: mediaType))
        try await write(
            try header(
                name: "Content-Disposition",
                value: "attachment; filename=\"\(ascii)\"; filename*=UTF-8''\(encoded)"
            )
        )
        try await write(
            try header(name: "Content-Transfer-Encoding", value: "base64")
        )
        try await write(Data("\r\n".utf8))

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
        if !carry.isEmpty {
            try await writeWrappedBase64(carry, write: write)
        }
        try await write(Data("\r\n--\(boundary)--\r\n".utf8))
    }

    private func sanitizedFilename(_ value: String) -> String {
        let filtered = value.filter {
            !$0.isNewline && !$0.isControl && $0 != "\"" && $0 != "\\"
        }
        let trimmed = filtered.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "book" : trimmed).prefix(180))
    }

    private func writeWrappedBase64(
        _ data: Data,
        write: @escaping @Sendable (Data) async throws -> Void
    ) async throws {
        let encoded = data.base64EncodedString()
        var index = encoded.startIndex
        while index < encoded.endIndex {
            try Task.checkCancellation()
            let end = encoded.index(
                index,
                offsetBy: lineLength,
                limitedBy: encoded.endIndex
            ) ?? encoded.endIndex
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

actor SMTPDataFramer {
    private var isAtLineStart = true

    func frame(_ data: Data) -> Data {
        var output = Data()
        output.reserveCapacity(data.count + 16)
        for byte in data {
            if isAtLineStart, byte == 0x2E {
                output.append(0x2E)
            }
            output.append(byte)
            if byte == 0x0A {
                isAtLineStart = true
            } else if byte != 0x0D {
                isAtLineStart = false
            }
        }
        return output
    }
}
