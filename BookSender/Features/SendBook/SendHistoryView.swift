import SwiftUI

struct SendHistoryView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            historyContent
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .layoutPriority(1)

            if let failure = historyFeedback?.failure {
                FailureDetailView(
                    presentation: failure,
                    diagnosticEvent: model.currentDiagnosticEvent,
                    copyErrorDetails: {
                        model.copyCurrentErrorDetails(destination: .main)
                    },
                    performRecovery: handleRecovery
                )
            }

            HStack {
                Text(historyCount)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("sendBook.history.count")
                Spacer()
                Button("Clear History", action: model.requestClearHistory)
                    .disabled(
                        model.historySnapshot.records.isEmpty
                            || model.isClearingHistory
                    )
                    .accessibilityIdentifier("sendBook.history.clear")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            model.ensureHistoryLoaded()
        }
        .alert(
            "Clear Send History?",
            isPresented: $model.isShowingClearHistoryConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                model.cancelClearHistory()
            }
            Button("Clear History", role: .destructive) {
                model.confirmClearHistory()
            }
        } message: {
            Text(
                "This removes the local submission record. Delivery setup and the current batch are unchanged."
            )
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        switch model.historyLoadState {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading send history…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("sendBook.history.loading")

        case .unavailable:
            ContentUnavailableView {
                Label("Send History Unavailable", systemImage: "clock.badge.exclamationmark")
            } description: {
                Text("The local submission record could not be loaded.")
            } actions: {
                Button("Retry", action: model.retryHistoryLoad)
                    .accessibilityIdentifier("sendBook.history.retry")
            }
            .accessibilityIdentifier("sendBook.history.unavailable")

        case .loaded where model.historySnapshot.records.isEmpty:
            ContentUnavailableView {
                Label("No books submitted yet.", systemImage: "clock")
            } description: {
                Text("Books accepted by the SMTP provider will appear here.")
            }
            .accessibilityIdentifier("sendBook.history.empty")

        case .loaded:
            List(model.historySnapshot.records) { record in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(record.displayName)
                        .lineLimit(1)
                    Spacer(minLength: 20)
                    Text(
                        record.acceptedAt,
                        format: .dateTime
                            .year()
                            .month(.abbreviated)
                            .day()
                            .hour()
                            .minute()
                    )
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    "sendBook.history.record.\(record.id.uuidString)"
                )
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("sendBook.history.list")
        }
    }

    private var historyCount: String {
        let count = model.historySnapshot.records.count
        return count == 1 ? "1 submission" : "\(count) submissions"
    }

    private var historyFeedback: ActionFeedback? {
        model.notificationFeedback(for: .history, destination: .main)
    }

    private func handleRecovery(_ action: RecoveryAction) {
        switch action {
        case .retryHistoryLoad:
            model.retryHistoryLoad()
        case .retryHistoryClear:
            model.requestClearHistory()
        case .editSetup, .chooseAnotherFile, .reviewBook, .retryFailed,
             .confirmUnknownRetry, .chooseAnotherShortcut:
            break
        }
    }
}
