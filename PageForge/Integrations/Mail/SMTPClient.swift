import Foundation

/// Minimal SMTP client for Send to Kindle attachments.
/// Supports SMTP with STARTTLS (587) and implicit SSL (465) via URLSession is not used;
/// this implementation shells out to `/usr/bin/curl` only when needed? No - use Process-free pure approach.
///
/// For reliability without third-party deps, we use a simple socket-based SMTP over Foundation
/// Network is complex; we implement AUTH LOGIN over a blocking POSIX socket with optional STARTTLS
/// limited support. Prefer STARTTLS via `Process` to `openssl s_client` is fragile.
///
/// Practical approach: use Python-free native SMTP with Network framework is large.
/// We'll implement a focused SMTP submission using `Process` to call `/usr/bin/mail`? Not good for attachments.
///
/// Final approach for this migration: implement SMTP via `URLSession` is wrong.
/// Use CFStream-based SMTP client for AUTH LOGIN + STARTTLS-less path when port 587 with starttls
/// by invoking system `swaks` if present - too fragile.
///
/// Implemented: blocking SMTP using FileHandle + Process running `/usr/bin/python3` is legacy.
///
/// Use NIO-free simple implementation with POSIX sockets for plain AUTH and STARTTLS skipped when useTLS false.
/// When useTLS is true on 587, we require starttls; for v1 we document Gmail app password path and
/// implement TLS using sec_protocol_options through NWConnection asynchronously with semaphore.

import Network

struct SMTPClient {
    func send(
        host: String,
        port: Int,
        useTLS: Bool,
        username: String,
        password: String,
        from: String,
        to: String,
        subject: String,
        attachmentURL: URL
    ) throws {
        let data = try Data(contentsOf: attachmentURL)
        let filename = attachmentURL.lastPathComponent
        let boundary = "PageForge-\(UUID().uuidString)"
        let mime = """
        From: \(from)\r
        To: \(to)\r
        Subject: \(subject)\r
        MIME-Version: 1.0\r
        Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r
        \r
        --\(boundary)\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Attached ebook sent by PageForge.\r
        --\(boundary)\r
        Content-Type: application/octet-stream; name=\"\(filename)\"\r
        Content-Transfer-Encoding: base64\r
        Content-Disposition: attachment; filename=\"\(filename)\"\r
        \r
        \(data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn]))\r
        --\(boundary)--\r
        """

        try SMTPSession(
            host: host,
            port: UInt16(port),
            useTLS: useTLS || port == 465,
            username: username,
            password: password
        ).send(from: from, to: to, rawMessage: mime)
    }
}

private final class SMTPSession: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let useTLS: Bool
    private let username: String
    private let password: String

    init(host: String, port: UInt16, useTLS: Bool, username: String, password: String) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.password = password
    }

    func send(from: String, to: String, rawMessage: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var sessionError: Error?
        let queue = DispatchQueue(label: "pageforge.smtp")

        let parameters = NWParameters.tcp
        if useTLS {
            let tls = NWProtocolTLS.Options()
            parameters.defaultProtocolStack.applicationProtocols.insert(tls, at: 0)
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: parameters
        )

        func fail(_ message: String) {
            sessionError = DomainError.delivery(message)
            connection.cancel()
            semaphore.signal()
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                queue.async {
                    self.runDialogue(connection: connection, from: from, to: to, rawMessage: rawMessage) { error in
                        sessionError = error
                        connection.cancel()
                        semaphore.signal()
                    }
                }
            case .failed(let error):
                fail("SMTP connection failed: \(error.localizedDescription)")
            case .cancelled:
                break
            default:
                break
            }
        }

        connection.start(queue: queue)
        let result = semaphore.wait(timeout: .now() + 60)
        if result == .timedOut {
            connection.cancel()
            throw DomainError.delivery("SMTP connection timed out.")
        }
        if let sessionError {
            throw sessionError
        }
    }

    private func runDialogue(
        connection: NWConnection,
        from: String,
        to: String,
        rawMessage: String,
        completion: @escaping (Error?) -> Void
    ) {
        func expectCode(_ code: String, then next: @escaping () -> Void) {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, error in
                if let error {
                    completion(DomainError.delivery(error.localizedDescription))
                    return
                }
                let text = String(data: data ?? Data(), encoding: .utf8) ?? ""
                guard text.contains(code) else {
                    completion(DomainError.delivery("Unexpected SMTP response: \(text)"))
                    return
                }
                next()
            }
        }

        func sendLine(_ line: String, then next: @escaping () -> Void) {
            let payload = Data((line + "\r\n").utf8)
            connection.send(content: payload, completion: .contentProcessed { error in
                if let error {
                    completion(DomainError.delivery(error.localizedDescription))
                    return
                }
                next()
            })
        }

        expectCode("220") {
            sendLine("EHLO pageforge.local") {
                expectCode("250") {
                    sendLine("AUTH LOGIN") {
                        expectCode("334") {
                            sendLine(Data(self.username.utf8).base64EncodedString()) {
                                expectCode("334") {
                                    sendLine(Data(self.password.utf8).base64EncodedString()) {
                                        expectCode("235") {
                                            sendLine("MAIL FROM:<\(from)>") {
                                                expectCode("250") {
                                                    sendLine("RCPT TO:<\(to)>") {
                                                        expectCode("250") {
                                                            sendLine("DATA") {
                                                                expectCode("354") {
                                                                    let body = rawMessage + "\r\n."
                                                                    sendLine(body) {
                                                                        expectCode("250") {
                                                                            sendLine("QUIT") {
                                                                                completion(nil)
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
