import Foundation

struct AppDependencies {
    enum NotificationUITestScenario: Sendable {
        case configurationMatrix
        case stackAndQueue
        case appearance
    }

    enum BootstrapMode {
        case production
        case uiTesting(
            reset: Bool,
            configured: Bool,
            slowInitialSetupLoad: Bool,
            resetHistory: Bool,
            seedHistory: Bool,
            reintakeAfterReset: Bool
        )
    }

    let workspaceStore: any WorkspaceStoring
    let setupService: DeliverySetupService
    let pipeline: PipelineActor
    let historyService: SendHistoryService
    let shortcutDefaults: UserDefaults
    let diagnosticService: DiagnosticService
    let diagnosticFormatter: DiagnosticFormatter
    let diagnosticClipboard: any DiagnosticClipboard
    let feedbackSleep: FeedbackSleep
    let appVersion: String
    let bootstrapMode: BootstrapMode
    let bootstrapFixtureURLs: [URL]
    let notificationUITestScenario: NotificationUITestScenario?

    static func forCurrentInvocation(
        processInfo: ProcessInfo = .processInfo
    ) -> AppDependencies {
        let arguments = Set(processInfo.arguments)
        let isUITesting = arguments.contains("-uiTesting")
        let defaults: UserDefaults
        let defaultsSuiteName: String?
        let serviceName: String
        let bootstrapMode: BootstrapMode
        let notificationUITestScenario: NotificationUITestScenario?

        if isUITesting {
            let suiteName = "com.rckbrcls.BookSender.UITests"
            defaultsSuiteName = suiteName
            defaults = UserDefaults(suiteName: suiteName) ?? .standard
            serviceName = "com.rckbrcls.BookSender.UITests.smtp"
            bootstrapMode = .uiTesting(
                reset: arguments.contains("-resetSetup"),
                configured: arguments.contains("-configuredSetup"),
                slowInitialSetupLoad: arguments.contains(
                    "-uiTestSlowSetupLoad"
                ),
                resetHistory: arguments.contains("-resetHistory"),
                seedHistory: arguments.contains("-uiTestHistory"),
                reintakeAfterReset: arguments.contains(
                    "-uiTestReintakeAfterReset"
                )
            )
        } else {
            defaultsSuiteName = nil
            defaults = .standard
            serviceName = "com.rckbrcls.BookSender.smtp"
            bootstrapMode = .production
        }

        if arguments.contains("-uiTestNotificationMatrix") {
            notificationUITestScenario = .configurationMatrix
        } else if arguments.contains("-uiTestNotificationStack") {
            notificationUITestScenario = .stackAndQueue
        } else if arguments.contains("-uiTestNotificationAppearance") {
            notificationUITestScenario = .appearance
        } else {
            notificationUITestScenario = nil
        }

        let workspaceRoot = isUITesting
            ? FileManager.default.temporaryDirectory
                .appending(component: "BookSender-UITests")
                .appending(component: "Workspaces")
            : nil
        let workspaceStore = WorkspaceStore(rootURL: workspaceRoot)
        let credentialStore: any CredentialStoring
        if isUITesting {
            credentialStore = IsolatedUITestCredentialStore(
                serviceName: serviceName
            )
        } else {
            credentialStore = KeychainCredentialStore()
        }
        let preferencesStore = DeliveryPreferencesStore(
            suiteName: defaultsSuiteName
        )
        let setupService = DeliverySetupService(
            credentials: credentialStore,
            preferences: preferencesStore,
            serviceName: serviceName
        )
        let intakeService = BookIntakeService(
            workspaceStore: workspaceStore
        )
        let epubPreparer = EPUBRepairEngine(
            writer: EPUBArchiveWriter(),
            workspaceStore: workspaceStore
        )
        let pdfPreparer = PDFEligibilityService(
            workspaceStore: workspaceStore
        )
        let transport: any SMTPDelivering
        if isUITesting {
            var outcomes: [TerminalOutcome] = []
            if let failure = controlledSMTPFailure(
                for: arguments
            ) {
                outcomes.append(.failed(failure))
            } else if arguments.contains("-uiTestOutcomeFailed") {
                outcomes.append(
                    .failed(
                        SanitizedFailure(
                            family: .delivery,
                            code: .smtpUITestRejected,
                            message: "The SMTP provider rejected this delivery.",
                            recoveryAction: .retryFailed
                        )
                    )
                )
            }
            if arguments.contains("-uiTestOutcomeUnknown") {
                outcomes.append(.deliveryUnknown(.deliveryUnknown()))
            }
            if outcomes.isEmpty {
                outcomes = [.submitted]
            }
            transport = IsolatedUITestSMTPTransport(
                outcomes: outcomes,
                delaysBeforeTransmission: arguments.contains(
                    "-uiTestSlowDelivery"
                )
            )
        } else {
            transport = NIOSMTPClient()
        }
        let deliveryService = BookDeliveryService(
            credentials: credentialStore,
            transport: transport
        )
        let historyStore: any SendHistoryStoring
        if isUITesting && arguments.contains("-uiTestHistoryUnavailable") {
            historyStore = IsolatedUITestUnavailableHistoryStore()
        } else if isUITesting
                    && arguments.contains("-uiTestHistoryWriteFailure") {
            historyStore = IsolatedUITestWriteFailingHistoryStore(
                rootURL: FileManager.default.temporaryDirectory
                    .appending(component: "BookSender-UITests")
                    .appending(component: "SendHistory-WriteFailure")
            )
        } else if isUITesting
                    && arguments.contains("-uiTestHistoryClearFailure") {
            historyStore = IsolatedUITestClearFailingHistoryStore(
                rootURL: FileManager.default.temporaryDirectory
                    .appending(component: "BookSender-UITests")
                    .appending(component: "SendHistory-ClearFailure")
            )
        } else if isUITesting {
            historyStore = FileSendHistoryStore(
                rootURL: FileManager.default.temporaryDirectory
                    .appending(component: "BookSender-UITests")
                    .appending(component: "SendHistory")
            )
        } else if let applicationSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            historyStore = FileSendHistoryStore(
                rootURL: applicationSupportURL
                    .appending(component: "Book Sender")
                    .appending(component: "SendHistory")
            )
        } else {
            historyStore = IsolatedUITestUnavailableHistoryStore()
        }
        let historyService = SendHistoryService(store: historyStore)
        let pipeline = PipelineActor(
            intakeService: intakeService,
            epubPreparer: epubPreparer,
            pdfPreparer: pdfPreparer,
            deliveryService: deliveryService,
            workspaceStore: workspaceStore,
            historyService: historyService
        )
        let bootstrapFixtureURLs: [URL]
        if isUITesting, arguments.contains("-uiTestInvalidEPUB") {
            bootstrapFixtureURLs = (
                try? makeIsolatedUITestInvalidEPUB()
            ).map { [$0] } ?? []
        } else if isUITesting, arguments.contains("-uiTestPDFs") {
            bootstrapFixtureURLs = (
                try? makeIsolatedUITestPDFs(
                    count: arguments.contains("-uiTestTwentyBooks")
                        ? 20
                        : (
                            arguments.contains("-uiTestThreeBooks")
                                ? 3
                                : (
                                    arguments.contains("-uiTestTwoBooks")
                                        ? 2
                                        : 1
                                )
                        )
                )
            ) ?? []
        } else {
            bootstrapFixtureURLs = []
        }
        let appVersion =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
            ?? "unknown"
        let diagnosticClipboard: any DiagnosticClipboard
        if isUITesting && arguments.contains("-uiTestClipboardFailure") {
            diagnosticClipboard = IsolatedUITestDiagnosticClipboard(
                rejectsWrites: true
            )
        } else {
            diagnosticClipboard = AppKitDiagnosticClipboard()
        }
        return AppDependencies(
            workspaceStore: workspaceStore,
            setupService: setupService,
            pipeline: pipeline,
            historyService: historyService,
            shortcutDefaults: defaults,
            diagnosticService: DiagnosticService(
                recorder: UnifiedDiagnosticRecorder(),
                appVersion: appVersion
            ),
            diagnosticFormatter: DiagnosticFormatter(),
            diagnosticClipboard: diagnosticClipboard,
            feedbackSleep: { duration in
                try await Task.sleep(for: .seconds(duration))
            },
            appVersion: appVersion,
            bootstrapMode: bootstrapMode,
            bootstrapFixtureURLs: bootstrapFixtureURLs,
            notificationUITestScenario: notificationUITestScenario
        )
    }

    var shouldReintakeAfterReset: Bool {
        guard case .uiTesting(
            _,
            _,
            _,
            _,
            _,
            let reintakeAfterReset
        ) = bootstrapMode
        else {
            return false
        }
        return reintakeAfterReset
    }

    private static func controlledSMTPFailure(
        for arguments: Set<String>
    ) -> SanitizedFailure? {
        let scenario: (
            code: DiagnosticCode,
            phase: DiagnosticPhase,
            replyCode: Int,
            retry: RetryDisposition,
            recovery: RecoveryAction
        )?
        if arguments.contains("-uiTestSMTPConnecting") {
            scenario = (
                .smtpConnectionClosed,
                .smtpConnecting,
                421,
                .retrySafe,
                .retryFailed
            )
        } else if arguments.contains("-uiTestSMTPSecuring") {
            scenario = (
                .smtpSecureChannel,
                .smtpSecuring,
                454,
                .editSetup,
                .editSetup
            )
        } else if arguments.contains("-uiTestSMTPAuthenticating") {
            scenario = (
                .smtpAuthenticationRejected,
                .smtpAuthenticating,
                535,
                .editSetup,
                .editSetup
            )
        } else if arguments.contains("-uiTestSMTPSender") {
            scenario = (
                .smtpSenderRejected,
                .smtpSender,
                550,
                .editSetup,
                .editSetup
            )
        } else if arguments.contains("-uiTestSMTPRecipient") {
            scenario = (
                .smtpRecipientRejected,
                .smtpRecipient,
                550,
                .editSetup,
                .editSetup
            )
        } else if arguments.contains("-uiTestSMTPData") {
            scenario = (
                .smtpDataRejected,
                .smtpData,
                450,
                .retrySafe,
                .retryFailed
            )
        } else if arguments.contains("-uiTestSMTPFinalAcceptance") {
            scenario = (
                .smtpFinalAcceptanceRejected,
                .smtpFinalAcceptance,
                550,
                .reviewBook,
                .reviewBook
            )
        } else {
            scenario = nil
        }
        guard let scenario else { return nil }
        return SanitizedFailure(
            family: .delivery,
            code: scenario.code,
            message: "The controlled SMTP operation was rejected.",
            recoveryAction: scenario.recovery,
            evidence: DiagnosticEvidence(
                phase: scenario.phase,
                retryDisposition: scenario.retry,
                providerStatus: ProviderStatus(
                    replyCode: scenario.replyCode
                )
            )
        )
    }

    private static func makeIsolatedUITestInvalidEPUB() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "BookSender-UITests")
            .appending(component: "Fixtures")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appending(component: "Needs-Attention.epub")
        try Data("not-an-epub".utf8).write(to: url, options: .atomic)
        return url
    }

    private static func makeIsolatedUITestPDFs(
        count: Int
    ) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "BookSender-UITests")
            .appending(component: "Fixtures")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return try (0..<count).map { index in
            let url = directory.appending(
                component: "UITest-\(index + 1).pdf"
            )
            try Data(
                "%PDF-1.7\n\(index + 1) 0 obj\n<<>>\nendobj\n%%EOF\n".utf8
            ).write(to: url, options: .atomic)
            return url
        }
    }
}

private struct IsolatedUITestDiagnosticClipboard: DiagnosticClipboard {
    let rejectsWrites: Bool

    @MainActor
    func write(_ copy: DiagnosticCopy) throws {
        if rejectsWrites {
            throw DiagnosticClipboardError.writeFailed
        }
    }
}

private actor IsolatedUITestUnavailableHistoryStore: SendHistoryStoring {
    func load() throws -> [SubmissionRecord] {
        throw HistoryFailure(operation: .load, code: .unavailable)
    }

    func replace(with records: [SubmissionRecord]) throws {
        throw HistoryFailure(operation: .record, code: .write)
    }

    func clear() throws {
        throw HistoryFailure(operation: .clear, code: .clear)
    }
}

private actor IsolatedUITestClearFailingHistoryStore: SendHistoryStoring {
    private let backing: FileSendHistoryStore

    init(rootURL: URL) {
        backing = FileSendHistoryStore(rootURL: rootURL)
    }

    func load() async throws -> [SubmissionRecord] {
        try await backing.load()
    }

    func replace(with records: [SubmissionRecord]) async throws {
        try await backing.replace(with: records)
    }

    func clear() throws {
        throw HistoryFailure(operation: .clear, code: .clear)
    }
}

private actor IsolatedUITestWriteFailingHistoryStore: SendHistoryStoring {
    private let backing: FileSendHistoryStore

    init(rootURL: URL) {
        backing = FileSendHistoryStore(rootURL: rootURL)
    }

    func load() async throws -> [SubmissionRecord] {
        try await backing.load()
    }

    func replace(with records: [SubmissionRecord]) throws {
        throw HistoryFailure(operation: .record, code: .write)
    }

    func clear() async throws {
        try await backing.clear()
    }
}

private actor IsolatedUITestCredentialStore: CredentialStoring {
    private let serviceName: String

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func save(
        secret: String,
        service: String,
        account: String,
        revision: Int
    ) throws -> CredentialReference {
        guard !secret.isEmpty,
              service == serviceName,
              account.hasPrefix("revision-"),
              revision > 0
        else {
            throw failure()
        }
        return CredentialReference(
            service: service,
            account: account,
            revision: revision
        )
    }

    func read(_ reference: CredentialReference) throws -> String {
        guard exists(reference) else {
            throw failure()
        }
        return "isolated-ui-test-credential"
    }

    func exists(_ reference: CredentialReference) -> Bool {
        reference.service == serviceName
            && reference.account.hasPrefix("revision-")
            && reference.revision > 0
    }

    func delete(_ reference: CredentialReference) {}

    private func failure() -> SanitizedFailure {
        SanitizedFailure(
            family: .credential,
            code: .credentialUITest,
            message: "The UI test credential is unavailable.",
            recoveryAction: .editSetup
        )
    }
}

private actor IsolatedUITestSMTPTransport: SMTPDelivering {
    private var outcomes: [TerminalOutcome]
    private let delaysBeforeTransmission: Bool

    init(
        outcomes: [TerminalOutcome],
        delaysBeforeTransmission: Bool = false
    ) {
        self.outcomes = outcomes
        self.delaysBeforeTransmission = delaysBeforeTransmission
    }

    func send(
        book: PreparedBook,
        setup: DeliverySetup,
        credential: String,
        progress: @escaping @Sendable (DeliveryProgress) async -> Void
    ) async -> TerminalOutcome {
        if delaysBeforeTransmission {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return .cancelled
            }
        }
        let stages: [DeliveryProgress] = [
            DeliveryProgress(
                stage: .connecting,
                dataTransmissionStarted: false
            ),
            DeliveryProgress(
                stage: .authenticating,
                dataTransmissionStarted: false
            ),
            DeliveryProgress(
                stage: .transmitting,
                dataTransmissionStarted: true
            ),
            DeliveryProgress(
                stage: .awaitingAcceptance,
                dataTransmissionStarted: true
            ),
        ]
        for stage in stages {
            if Task.isCancelled {
                return stage.dataTransmissionStarted
                    ? .deliveryUnknown(.deliveryUnknown())
                    : .cancelled
            }
            await progress(stage)
            await Task.yield()
        }
        return outcomes.isEmpty ? .submitted : outcomes.removeFirst()
    }

    func cancelActiveAttempt() {}
}
