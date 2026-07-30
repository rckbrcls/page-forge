import Foundation
import NIOCore
import NIOPosix
import NIOSSL

actor NIOSMTPClient: SMTPDelivering {
    private let limits: SafetyLimits
    private let encoder: MIMEMessageEncoder
    private var activeChannel: Channel?

    init(
        limits: SafetyLimits = .standard,
        encoder: MIMEMessageEncoder = MIMEMessageEncoder()
    ) {
        self.limits = limits
        self.encoder = encoder
    }

    func send(
        book: PreparedBook,
        setup: DeliverySetup,
        credential: String,
        progress: @escaping @Sendable (DeliveryProgress) async -> Void
    ) async -> TerminalOutcome {
        guard limits.permitsAttachmentBytes(book.byteCount) else {
            return .failed(
                failure(
                    .smtpAttachmentSize,
                    message: "This attachment exceeds the delivery size limit.",
                    phase: .inputValidation,
                    retryDisposition: .chooseAnotherFile,
                    recoveryAction: .chooseAnotherFile,
                    context: DiagnosticContext(safetyLimit: .attachmentBytes)
                )
            )
        }
        guard permitsAuthenticationCommands(
            username: setup.username,
            credential: credential
        ) else {
            return .failed(
                failure(
                    .smtpCommandSize,
                    message: "The SMTP credential is too large to send safely.",
                    phase: .inputValidation,
                    retryDisposition: .editSetup,
                    recoveryAction: .editSetup,
                    context: DiagnosticContext(safetyLimit: .smtpLine)
                )
            )
        }

        let transmission = SMTPTransmissionTracker()
        let usesImplicitTLS = setup.securityMode == .implicitTLS
        if usesImplicitTLS {
            await transmission.updatePhase(.smtpSecuring)
        }
        await progress(
            DeliveryProgress(
                stage: .connecting,
                dataTransmissionStarted: false
            )
        )

        do {
            let hostname = setup.smtpHost.value
            let tlsContext = try makeTLSContext()
            let stageSeconds = max(
                Int64(1),
                limits.smtpStageTimeout.components.seconds
            )
            let asyncChannel = try await ClientBootstrap(
                group: MultiThreadedEventLoopGroup.singleton
            )
            .channelOption(
                ChannelOptions.connectTimeout,
                value: .seconds(stageSeconds)
            )
            .connect(
                host: hostname,
                port: Int(setup.smtpPort)
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    if usesImplicitTLS {
                        let implicitHandler = try NIOSSLClientHandler(
                            context: tlsContext,
                            serverHostname: hostname
                        )
                        try channel.pipeline.syncOperations.addHandler(
                            implicitHandler,
                            position: .first
                        )
                    }
                    return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(
                        wrappingChannelSynchronously: channel
                    )
                }
            }
            activeChannel = asyncChannel.channel
            defer { activeChannel = nil }

            if setup.securityMode == .implicitTLS {
                await progress(
                    DeliveryProgress(
                        stage: .securing,
                        dataTransmissionStarted: false
                    )
                )
            }

            let outcome = try await asyncChannel.executeThenClose {
                inbound,
                outbound in
                let replyQueue = SMTPReplyQueue()
                let readerTask = Task {
                    var decoder = SMTPReplyDecoder(limits: limits)
                    do {
                        for try await incoming in inbound {
                            try Task.checkCancellation()
                            let data = Data(incoming.readableBytesView)
                            for reply in try decoder.append(data) {
                                await replyQueue.yield(reply)
                            }
                        }
                        await replyQueue.finish()
                    } catch let sanitized as SanitizedFailure {
                        await replyQueue.finish(failure: sanitized)
                    } catch {
                        await replyQueue.finish(
                            failure: failure(.smtpConnectionClosed)
                        )
                    }
                }
                defer {
                    readerTask.cancel()
                }

                var machine = SMTPStateMachine(
                    setup: setup,
                    credential: credential
                )
                let allocator = ByteBufferAllocator()

                let writeData: @Sendable (Data) async throws -> Void = { data in
                    var buffer = allocator.buffer(capacity: data.count)
                    buffer.writeBytes(data)
                    try await outbound.write(buffer)
                }

                while true {
                    try Task.checkCancellation()
                    let machinePhase = machine.diagnosticPhase
                    await transmission.updatePhase(
                        usesImplicitTLS && machinePhase == .smtpConnecting
                            ? .smtpSecuring
                            : machinePhase
                    )
                    let reply = try await nextReply(from: replyQueue)
                    var actions = machine.receive(reply)

                    while !actions.isEmpty {
                        let action = actions.removeFirst()
                        switch action {
                        case .write(let line, _):
                            let stage = stage(forCommand: line)
                            if let stage {
                                let started = await transmission.value
                                await transmission.updatePhase(
                                    diagnosticPhase(for: stage)
                                )
                                await progress(
                                    DeliveryProgress(
                                        stage: stage,
                                        dataTransmissionStarted: started
                                    )
                                )
                            }
                            try await writeData(Data(line.utf8))

                        case .upgradeTLS:
                            await transmission.updatePhase(.smtpSecuring)
                            await progress(
                                DeliveryProgress(
                                    stage: .securing,
                                    dataTransmissionStarted: false
                                )
                            )
                            let channel = asyncChannel.channel
                            try await channel.eventLoop.submit {
                                let handler = try NIOSSLClientHandler(
                                    context: tlsContext,
                                    serverHostname: hostname
                                )
                                try channel.pipeline.syncOperations.addHandler(
                                    handler,
                                    position: .first
                                )
                            }.get()
                            actions.append(contentsOf: machine.didUpgradeTLS())

                        case .beginMessageData:
                            await transmission.updatePhase(.smtpData)
                            await progress(
                                DeliveryProgress(
                                    stage: .transmitting,
                                    dataTransmissionStarted: false
                                )
                            )
                            let framer = SMTPDataFramer()
                            let envelope = SMTPEnvelope(
                                sender: setup.senderAddress,
                                recipient: setup.kindleAddress
                            )
                            try await encoder.streamMessage(
                                book: book,
                                envelope: envelope
                            ) { chunk in
                                let framed = await framer.frame(chunk)
                                guard !framed.isEmpty else { return }
                                try await writeData(framed)
                                if await transmission.markStartedIfNeeded() {
                                    await progress(
                                        DeliveryProgress(
                                            stage: .transmitting,
                                            dataTransmissionStarted: true
                                        )
                                    )
                                }
                            }
                            try await writeData(Data(".\r\n".utf8))
                            await progress(
                                DeliveryProgress(
                                    stage: .awaitingAcceptance,
                                    dataTransmissionStarted: true
                                )
                            )
                            await transmission.updatePhase(.smtpFinalAcceptance)

                        case .accepted:
                            return TerminalOutcome.submitted

                        case .failed(let failure):
                            let snapshot = await transmission.snapshot
                            return TerminalOutcome.failed(
                                contextualized(
                                    failure,
                                    phase: failure.evidence.phase,
                                    transmissionStarted: snapshot.started
                                )
                            )
                        }
                    }
                }
            }
            return outcome
        } catch is CancellationError {
            let snapshot = await transmission.snapshot
            return SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: snapshot.started,
                phase: snapshot.phase,
                termination: .cancelled
            )
        } catch let sanitized as SanitizedFailure {
            let snapshot = await transmission.snapshot
            let enrichedFailure = contextualized(
                sanitized,
                phase: snapshot.phase,
                transmissionStarted: snapshot.started
            )
            return SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: snapshot.started,
                phase: snapshot.phase,
                termination: .failed(enrichedFailure)
            )
        } catch {
            let snapshot = await transmission.snapshot
            let transportFailure = failure(
                snapshot.phase == .smtpSecuring
                    ? .smtpSecureChannel
                    : .smtpTransport,
                phase: snapshot.phase,
                retryDisposition: .retrySafe,
                recoveryAction: .retryFailed,
                context: DiagnosticContext(
                    transmissionStarted: snapshot.started
                )
            )
            return SMTPUncertaintyClassifier.outcome(
                dataTransmissionStarted: snapshot.started,
                phase: snapshot.phase,
                termination: .failed(transportFailure)
            )
        }
    }

    func cancelActiveAttempt() async {
        guard let channel = activeChannel else { return }
        try? await channel.close().get()
    }

    private func nextReply(
        from queue: SMTPReplyQueue
    ) async throws -> SMTPReply {
        let timeout = limits.smtpStageTimeout
        return try await withThrowingTaskGroup(of: SMTPReply.self) { group in
            group.addTask {
                guard let reply = try await queue.next() else {
                    throw self.failure(.smtpConnectionClosed)
                }
                return reply
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw self.failure(
                    .smtpTimeout,
                    context: DiagnosticContext(safetyLimit: .smtpTimeout)
                )
            }
            guard let reply = try await group.next() else {
                throw failure(.smtpConnectionClosed)
            }
            group.cancelAll()
            return reply
        }
    }

    private nonisolated func makeTLSContext() throws -> NIOSSLContext {
        var configuration = TLSConfiguration.makeClientConfiguration()
        configuration.minimumTLSVersion = .tlsv12
        configuration.maximumTLSVersion = .tlsv13
        configuration.certificateVerification = .fullVerification
        return try NIOSSLContext(configuration: configuration)
    }

    private nonisolated func stage(forCommand line: String) -> DeliveryStage? {
        let command = line.uppercased()
        if command.hasPrefix("EHLO") || command.hasPrefix("STARTTLS") {
            return .securing
        }
        if command.hasPrefix("AUTH")
            || (!command.contains(" ") && command.count > 8) {
            return .authenticating
        }
        if command.hasPrefix("MAIL FROM")
            || command.hasPrefix("RCPT TO")
            || command.hasPrefix("DATA") {
            return .envelope
        }
        return nil
    }

    private nonisolated func diagnosticPhase(
        for stage: DeliveryStage
    ) -> DiagnosticPhase {
        switch stage {
        case .connecting:
            .smtpConnecting
        case .securing:
            .smtpSecuring
        case .authenticating:
            .smtpAuthenticating
        case .envelope:
            .smtpSender
        case .transmitting:
            .smtpData
        case .awaitingAcceptance:
            .smtpFinalAcceptance
        }
    }

    private func permitsAuthenticationCommands(
        username: String,
        credential: String
    ) -> Bool {
        let plain = Data("\u{0}\(username)\u{0}\(credential)".utf8)
            .base64EncodedString()
        let loginUsername = Data(username.utf8).base64EncodedString()
        let loginPassword = Data(credential.utf8).base64EncodedString()
        return [
            "AUTH PLAIN \(plain)\r\n",
            "\(plain)\r\n",
            "\(loginUsername)\r\n",
            "\(loginPassword)\r\n",
        ].allSatisfy {
            limits.permitsSMTPLineBytes($0.utf8.count)
        }
    }

    private nonisolated func failure(
        _ code: DiagnosticCode,
        message: String = "The SMTP delivery could not be completed.",
        phase: DiagnosticPhase? = nil,
        retryDisposition: RetryDisposition = .retrySafe,
        recoveryAction: RecoveryAction = .retryFailed,
        context: DiagnosticContext = DiagnosticContext()
    ) -> SanitizedFailure {
        SanitizedFailure(
            family: .delivery,
            code: code,
            message: message,
            recoveryAction: recoveryAction,
            evidence: phase.map {
                DiagnosticEvidence(
                    phase: $0,
                    retryDisposition: retryDisposition,
                    context: context
                )
            }
        )
    }

    private nonisolated func contextualized(
        _ failure: SanitizedFailure,
        phase: DiagnosticPhase,
        transmissionStarted: Bool
    ) -> SanitizedFailure {
        let existing = failure.evidence.context
        let isSecureChannelClosure =
            phase == .smtpSecuring
            && failure.code == .smtpConnectionClosed
        return SanitizedFailure(
            family: failure.family,
            code: isSecureChannelClosure
                ? .smtpSecureChannel
                : failure.code,
            message: failure.message,
            recoveryAction: isSecureChannelClosure
                ? .editSetup
                : failure.recoveryAction,
            evidence: DiagnosticEvidence(
                phase: phase,
                severity: failure.evidence.severity,
                retryDisposition: isSecureChannelClosure
                    ? .editSetup
                    : failure.evidence.retryDisposition,
                providerStatus: failure.evidence.providerStatus,
                context: DiagnosticContext(
                    appVersion: existing.appVersion,
                    operationID: existing.operationID,
                    setupRevision: existing.setupRevision,
                    batchTotal: existing.batchTotal,
                    batchCompleted: existing.batchCompleted,
                    transmissionStarted: transmissionStarted,
                    safetyLimit: existing.safetyLimit
                )
            )
        )
    }
}

enum SMTPTransportTermination: Sendable {
    case cancelled
    case failed(SanitizedFailure)
}

struct SMTPUncertaintyClassifier: Sendable {
    static func outcome(
        dataTransmissionStarted: Bool,
        phase: DiagnosticPhase = .smtpData,
        termination: SMTPTransportTermination
    ) -> TerminalOutcome {
        if dataTransmissionStarted {
            let sourceFailure: SanitizedFailure? = switch termination {
            case .cancelled: nil
            case .failed(let failure): failure
            }
            let providerStatus = sourceFailure?.evidence.providerStatus
            return .deliveryUnknown(
                .deliveryUnknown(
                    phase: phase,
                    providerStatus: providerStatus
                )
            )
        }
        switch termination {
        case .cancelled:
            return .cancelled
        case .failed(let failure):
            return .failed(failure)
        }
    }
}

private actor SMTPTransmissionTracker {
    private(set) var value = false
    private(set) var phase = DiagnosticPhase.smtpConnecting

    var snapshot: (started: Bool, phase: DiagnosticPhase) {
        (value, phase)
    }

    func updatePhase(_ phase: DiagnosticPhase) {
        self.phase = phase
    }

    func markStartedIfNeeded() -> Bool {
        guard !value else { return false }
        value = true
        return true
    }
}

private actor SMTPReplyQueue {
    private var replies: [SMTPReply] = []
    private var waiters: [CheckedContinuation<SMTPReply?, any Error>] = []
    private var isFinished = false
    private var terminalFailure: SanitizedFailure?

    func yield(_ reply: SMTPReply) {
        guard !isFinished else { return }
        if waiters.isEmpty {
            replies.append(reply)
        } else {
            waiters.removeFirst().resume(returning: reply)
        }
    }

    func finish(failure: SanitizedFailure? = nil) {
        guard !isFinished else { return }
        isFinished = true
        terminalFailure = failure
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            if let failure {
                waiter.resume(throwing: failure)
            } else {
                waiter.resume(returning: nil)
            }
        }
    }

    func next() async throws -> SMTPReply? {
        if !replies.isEmpty {
            return replies.removeFirst()
        }
        if let terminalFailure {
            throw terminalFailure
        }
        if isFinished {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
