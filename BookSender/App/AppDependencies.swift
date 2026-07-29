import Foundation

struct AppDependencies {
    enum BootstrapMode {
        case production
        case uiTesting(reset: Bool, configured: Bool)
    }

    let workspaceStore: any WorkspaceStoring
    let setupService: DeliverySetupService
    let pipeline: PipelineActor
    let shortcutDefaults: UserDefaults
    let bootstrapMode: BootstrapMode
    let bootstrapFixtureURLs: [URL]

    static func forCurrentInvocation(
        processInfo: ProcessInfo = .processInfo
    ) -> AppDependencies {
        let arguments = Set(processInfo.arguments)
        let isUITesting = arguments.contains("-uiTesting")
        let defaults: UserDefaults
        let defaultsSuiteName: String?
        let serviceName: String
        let bootstrapMode: BootstrapMode

        if isUITesting {
            let suiteName = "com.rckbrcls.BookSender.UITests"
            defaultsSuiteName = suiteName
            defaults = UserDefaults(suiteName: suiteName) ?? .standard
            serviceName = "com.rckbrcls.BookSender.UITests.smtp"
            bootstrapMode = .uiTesting(
                reset: arguments.contains("-resetSetup"),
                configured: arguments.contains("-configuredSetup")
            )
        } else {
            defaultsSuiteName = nil
            defaults = .standard
            serviceName = "com.rckbrcls.BookSender.smtp"
            bootstrapMode = .production
        }

        let workspaceRoot = isUITesting
            ? FileManager.default.temporaryDirectory
                .appending(component: "BookSender-UITests")
                .appending(component: "Workspaces")
            : nil
        let workspaceStore = WorkspaceStore(rootURL: workspaceRoot)
        let credentialStore = KeychainCredentialStore()
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
            if arguments.contains("-uiTestOutcomeFailed") {
                outcomes.append(
                    .failed(
                        SanitizedFailure(
                            family: .delivery,
                            code: "smtp.ui-test-rejected",
                            message: "The SMTP provider rejected this delivery.",
                            recoveryAction: .retryFailed
                        )
                    )
                )
            }
            if arguments.contains("-uiTestOutcomeUnknown") {
                outcomes.append(.deliveryUnknown)
            }
            if outcomes.isEmpty {
                outcomes = [.submitted]
            }
            transport = IsolatedUITestSMTPTransport(outcomes: outcomes)
        } else {
            transport = NIOSMTPClient()
        }
        let deliveryService = BookDeliveryService(
            credentials: credentialStore,
            transport: transport
        )
        let pipeline = PipelineActor(
            intakeService: intakeService,
            epubPreparer: epubPreparer,
            pdfPreparer: pdfPreparer,
            deliveryService: deliveryService,
            workspaceStore: workspaceStore
        )
        let bootstrapFixtureURLs: [URL]
        if isUITesting, arguments.contains("-uiTestPDFs") {
            bootstrapFixtureURLs = (
                try? makeIsolatedUITestPDFs(
                    count: arguments.contains("-uiTestTwoBooks") ? 2 : 1
                )
            ) ?? []
        } else {
            bootstrapFixtureURLs = []
        }
        return AppDependencies(
            workspaceStore: workspaceStore,
            setupService: setupService,
            pipeline: pipeline,
            shortcutDefaults: defaults,
            bootstrapMode: bootstrapMode,
            bootstrapFixtureURLs: bootstrapFixtureURLs
        )
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

private actor IsolatedUITestSMTPTransport: SMTPDelivering {
    private var outcomes: [TerminalOutcome]

    init(outcomes: [TerminalOutcome]) {
        self.outcomes = outcomes
    }

    func send(
        book: PreparedBook,
        setup: DeliverySetup,
        credential: String,
        progress: @escaping @Sendable (DeliveryProgress) async -> Void
    ) async -> TerminalOutcome {
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
                    ? .deliveryUnknown
                    : .cancelled
            }
            await progress(stage)
            await Task.yield()
        }
        return outcomes.isEmpty ? .submitted : outcomes.removeFirst()
    }

    func cancelActiveAttempt() {}
}
