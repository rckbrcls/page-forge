import AppKit
import SwiftUI

struct SendBookView: View {
    @Bindable var model: AppModel
    @State private var isShowingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(screenTitle)
                .font(.largeTitle.weight(.bold))
                .accessibilityIdentifier("sendBook.title")

            if model.sendBookTab == .send {
            BookDropTarget(
                isBusy: model.isImporting
                    || model.isSending
                    || model.isShowingConfirmation
                    || model.canStartAnotherSend,
                disabledReason: intakeDisabledReason,
                choose: { isShowingImporter = true },
                add: model.addBooks
            )

            if let feedback = sendFeedback {
                ActionFeedbackView(feedback: feedback)
                if let failure = feedback.failure {
                    FailureDetailView(
                        presentation: failure,
                        diagnosticEvent: model.currentDiagnosticEvent,
                        copyFeedback: model.currentCopyFeedback,
                        copyErrorDetails: model.copyCurrentErrorDetails,
                        performRecovery: handleRecovery
                    )
                }
            }

            if model.isImporting || !model.items.isEmpty {
                HStack {
                    if model.isImporting {
                        ProgressView()
                            .controlSize(.small)
                        Text("Preparing books…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.canCancel {
                        Button("Cancel", action: model.cancel)
                            .accessibilityIdentifier("sendBook.cancel")
                    }
                    if !model.items.isEmpty, !model.canStartAnotherSend {
                        Button("Clear", action: model.clear)
                            .disabled(
                                !model.canEditBatch
                                    || model.isShowingConfirmation
                            )
                            .accessibilityIdentifier("sendBook.clear")
                    }
                }
            }

            if !model.items.isEmpty {
                GroupBox {
                    List {
                        ForEach(model.items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                BatchItemRow(
                                    item: item,
                                    canRemove: model.canEditBatch
                                        && !model.isShowingConfirmation
                                ) {
                                    model.remove(item.id)
                                }
                                if shouldShowDetails(for: item) {
                                    let itemEvent = model.diagnosticEvent(
                                        for: item.id
                                    )
                                    ItemDetailDisclosure(
                                        item: item,
                                        diagnosticEvent: itemEvent,
                                        copyFeedback: model.currentCopyFeedback,
                                        copyErrorDetails: {
                                            model.copyErrorDetails(for: itemEvent)
                                        },
                                        performRecovery: handleRecovery
                                    )
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 156)
                    .accessibilityIdentifier("sendBook.batch")
                }
                .frame(minHeight: 180)
                .accessibilityIdentifier("sendBook.batch.card")
            }

            if let aggregateMessage = model.aggregateMessage {
                Text(aggregateMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("sendBook.aggregateState")
            }

            if model.hasDeliveryUnknown {
                Text("Review Delivery Unknown items before sending them again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("sendBook.unknownGuidance")
            }

            if model.failedCount > 0, !model.isSending {
                Button("Retry Failed", action: model.requestRetryConfirmation)
                    .accessibilityIdentifier("sendBook.retryFailed")
            }

            Button(action: primaryAction) {
                Text(primaryActionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .padding(.top, 8)
            .disabled(
                primaryActionDisabled
            )
            .accessibilityHint(sendDisabledReason ?? "Reviews the eligible books before sending.")
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(
                model.canStartAnotherSend
                    ? "sendBook.sendMore"
                    : "sendBook.send"
            )
            } else {
                SendHistoryView(model: model)
            }
        }
        .padding(36)
        .frame(
            minWidth: 620,
            maxWidth: .infinity,
            minHeight: 620,
            maxHeight: .infinity
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Section", selection: $model.sendBookTab) {
                    ForEach(SendBookTab.allCases, id: \.self) { tab in
                        Text(tab.title)
                            .tag(tab)
                            .accessibilityIdentifier(
                                "sendBook.tab.\(tab.rawValue)"
                            )
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("sendBook.tabs")
            }

            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Edit Setup", systemImage: "gearshape")
                        .labelStyle(.titleAndIcon)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        model.settingsTab = .delivery
                    }
                )
                .buttonStyle(.glass)
                .accessibilityIdentifier("sendBook.editSetup")
            }
        }
        .modifier(
            BookFileImporter(
                isPresented: $isShowingImporter,
                add: model.addBooks,
                failed: model.handleFileImporterFailure
            )
        )
        .sheet(isPresented: $model.isShowingConfirmation) {
            BatchConfirmationView(
                destination: model.confirmation?.destination ?? "",
                eligibleCount: model.eligibleCount,
                excludedCount: model.excludedCount,
                cancel: model.dismissConfirmation,
                confirm: model.confirmSend
            )
            .interactiveDismissDisabled()
        }
        .alert(
            "Start Another Send?",
            isPresented: $model.isShowingResetConfirmation
        ) {
            Button("Keep Results", role: .cancel) {
                model.cancelStartAnotherSend()
            }
            Button("Send More Books", role: .destructive) {
                model.confirmStartAnotherSend()
            }
        } message: {
            Text(
                "A Delivery Unknown item may already have been accepted by the provider. Starting another send clears the visible result without retrying it."
            )
        }
    }

    private var sendFeedback: ActionFeedback? {
        model.feedback(for: .batch)
            ?? model.feedback(for: .deliverySetup)
            ?? model.feedback(for: .application)
    }

    private var screenTitle: String {
        model.sendBookTab == .history ? "History" : "Send Book"
    }

    private var intakeDisabledReason: String? {
        if model.isImporting { return "Book preparation is already in progress." }
        if model.isSending { return "Wait for delivery to finish." }
        if model.isShowingConfirmation { return "Close the confirmation first." }
        if model.canStartAnotherSend {
            return "Start another send before adding more books."
        }
        return nil
    }

    private var primaryActionTitle: String {
        if model.canStartAnotherSend {
            return "Send More Books"
        }
        return model.isSending ? "Sending…" : "Send"
    }

    private var primaryActionDisabled: Bool {
        if model.canStartAnotherSend {
            return false
        }
        return model.setup == nil
            || model.initialEligibleCount == 0
            || model.isSending
            || model.isImporting
            || model.isShowingConfirmation
    }

    private func primaryAction() {
        if model.canStartAnotherSend {
            model.requestStartAnotherSend()
        } else {
            model.requestSendConfirmation()
        }
    }

    private var sendDisabledReason: String? {
        if model.setup == nil { return "Complete delivery setup first." }
        if model.initialEligibleCount == 0 { return "Add at least one ready book." }
        if model.isSending { return "Delivery is already in progress." }
        if model.isImporting { return "Wait for book preparation to finish." }
        if model.isShowingConfirmation { return "Use the open confirmation." }
        return nil
    }

    private func handleRecovery(_ action: RecoveryAction) {
        switch action {
        case .editSetup:
            model.settingsTab = .delivery
            showSettingsWindow()
        case .chooseAnotherFile:
            isShowingImporter = true
        case .retryFailed:
            model.requestRetryConfirmation()
        case .chooseAnotherShortcut:
            model.settingsTab = .shortcut
            showSettingsWindow()
        case .confirmUnknownRetry, .reviewBook:
            break
        case .retryHistoryLoad:
            model.retryHistoryLoad()
        case .retryHistoryClear:
            model.requestClearHistory()
        }
    }

    private func showSettingsWindow() {
        NSApp.sendAction(
            Selector(("showSettingsWindow:")),
            to: nil,
            from: nil
        )
    }

    private func shouldShowDetails(for item: BatchItemPresentation) -> Bool {
        if !item.appliedActions.isEmpty { return true }
        switch item.preparation {
        case .needsAttention, .excluded:
            return true
        case .waiting, .checking, .preparing, .ready, .cancelled:
            break
        }
        switch item.delivery {
        case .failed, .deliveryUnknown:
            return true
        case .notScheduled, .sending, .submitted, .cancelled:
            return false
        }
    }
}
