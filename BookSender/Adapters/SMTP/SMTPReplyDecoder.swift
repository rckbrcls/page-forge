import Foundation

struct SMTPReply: Equatable, Sendable {
    let code: Int
    let lines: [String]
    let providerStatus: ProviderStatus?

    init(
        code: Int,
        lines: [String],
        providerStatus: ProviderStatus? = nil
    ) {
        self.code = code
        self.lines = lines
        self.providerStatus = providerStatus
            ?? ProviderStatus(
                replyCode: code,
                enhancedStatus: Self.enhancedStatus(in: lines)
            )
    }

    private static func enhancedStatus(
        in lines: [String]
    ) -> EnhancedStatusCode? {
        for line in lines {
            for token in line.split(whereSeparator: \.isWhitespace) {
                let candidate = token.trimmingCharacters(
                    in: CharacterSet(charactersIn: "[](),;:")
                )
                if let status = EnhancedStatusCode(parsing: candidate) {
                    return status
                }
            }
        }
        return nil
    }
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
                throw failure(.smtpReplyLine)
            }

            let separator = line[line.index(line.startIndex, offsetBy: 3)]
            guard separator == " " || separator == "-" else {
                throw failure(.smtpReplyFormat)
            }
            if let pendingCode {
                guard pendingCode == code else {
                    throw failure(.smtpReplyCode)
                }
            } else {
                self.pendingCode = code
            }
            pendingLines.append(String(line.dropFirst(4)))
            guard limits.permitsSMTPReplyLines(pendingLines.count) else {
                throw failure(.smtpReplyCount)
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
            throw failure(.smtpReplyLine)
        }
        return replies
    }

    private func failure(_ code: DiagnosticCode) -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: code,
            message: "The SMTP server returned an invalid response.",
            recoveryAction: .editSetup
        )
    }
}
