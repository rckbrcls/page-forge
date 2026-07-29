import Foundation

struct SMTPReply: Equatable, Sendable {
    let code: Int
    let lines: [String]
}

struct SMTPReplyDecoder: Sendable {
    private let limits: SafetyLimits
    private var buffered = Data()
    private var pendingCode: Int?
    private var pendingLines: [String] = []

    init(limits: SafetyLimits = .standard) {
        self.limits = limits
    }

    mutating func append(_ data: Data) throws -> [SMTPReply] {
        buffered.append(data)
        var replies: [SMTPReply] = []

        while let range = buffered.range(of: Data("\r\n".utf8)) {
            let lineData = buffered[..<range.lowerBound]
            buffered.removeSubrange(..<range.upperBound)
            guard limits.permitsSMTPLineBytes(lineData.count + 2),
                  let line = String(data: lineData, encoding: .utf8),
                  line.count >= 4,
                  let code = Int(line.prefix(3)),
                  (200...599).contains(code)
            else {
                throw failure("smtp.reply-line")
            }

            let separator = line[line.index(line.startIndex, offsetBy: 3)]
            guard separator == " " || separator == "-" else {
                throw failure("smtp.reply-format")
            }
            if let pendingCode {
                guard pendingCode == code else {
                    throw failure("smtp.reply-code")
                }
            } else {
                self.pendingCode = code
            }
            pendingLines.append(String(line.dropFirst(4)))
            guard limits.permitsSMTPReplyLines(pendingLines.count) else {
                throw failure("smtp.reply-count")
            }

            if separator == " " {
                replies.append(
                    SMTPReply(code: code, lines: pendingLines)
                )
                pendingCode = nil
                pendingLines.removeAll(keepingCapacity: true)
            }
        }

        guard buffered.count <= limits.maximumSMTPLineBytes else {
            throw failure("smtp.reply-line")
        }
        return replies
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: code,
            message: "The SMTP server returned an invalid response.",
            recoveryAction: .editSetup
        )
    }
}

