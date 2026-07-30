import Testing
@testable import BookSender

struct UnifiedDiagnosticRecorderTests {
    @Test
    func emitsOneTypedRecordWithFixedCategoryAndPersistedLevel() async {
        let sink = DiagnosticLogSinkSpy()
        let recorder = UnifiedDiagnosticRecorder { level, category, fields in
            await sink.append(level: level, category: category, fields: fields)
        }

        await recorder.record(DiagnosticTestFixtures.safeEvent())

        let records = await sink.records
        #expect(records.count == 1)
        #expect(records[0].level == .error)
        #expect(records[0].category == .delivery)
        #expect(records[0].fields.code == .smtpAuthenticationRejected)
        #expect(records[0].fields.providerStatus?.replyCode == 535)
        for forbidden in DiagnosticTestFixtures.forbiddenValues {
            #expect(!String(describing: records[0]).contains(forbidden))
        }
    }

    @Test
    func criticalStartupUsesFaultLevel() async {
        let sink = DiagnosticLogSinkSpy()
        let recorder = UnifiedDiagnosticRecorder { level, category, fields in
            await sink.append(level: level, category: category, fields: fields)
        }
        let failure = SanitizedFailure(
            family: .filesystem,
            code: .startupBootstrap,
            message: "Startup stopped.",
            recoveryAction: nil,
            evidence: DiagnosticEvidence(
                phase: .bootstrap,
                severity: .critical,
                retryDisposition: .restartApplication
            )
        )
        await recorder.record(
            DiagnosticEvent(
                action: .restoreApplication,
                outcome: .failed,
                failure: failure
            )
        )

        #expect(await sink.records.first?.level == .fault)
        #expect(await sink.records.first?.category == .application)
    }

    @Test
    func criticalNonStartupFailureRemainsAtErrorLevel() async {
        let sink = DiagnosticLogSinkSpy()
        let recorder = UnifiedDiagnosticRecorder { level, category, fields in
            await sink.append(level: level, category: category, fields: fields)
        }
        let failure = SanitizedFailure(
            family: .archive,
            code: .archiveEncrypted,
            message: "The archive is encrypted.",
            recoveryAction: .reviewBook,
            evidence: DiagnosticEvidence(
                phase: .archiveSafety,
                severity: .critical,
                retryDisposition: .reviewBook
            )
        )

        await recorder.record(
            DiagnosticEvent(
                action: .prepareBook,
                outcome: .failed,
                failure: failure
            )
        )

        #expect(await sink.records.first?.level == .error)
        #expect(await sink.records.first?.category == .preparation)
    }
}

private actor DiagnosticLogSinkSpy {
    struct Record: Sendable {
        let level: DiagnosticLogLevel
        let category: DiagnosticLogCategory
        let fields: UnifiedDiagnosticFields
    }

    private(set) var records: [Record] = []

    func append(
        level: DiagnosticLogLevel,
        category: DiagnosticLogCategory,
        fields: UnifiedDiagnosticFields
    ) {
        records.append(
            Record(level: level, category: category, fields: fields)
        )
    }
}
