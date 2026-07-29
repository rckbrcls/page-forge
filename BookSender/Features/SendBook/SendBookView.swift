import SwiftUI

struct SendBookView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable var model: AppModel
    @State private var isShowingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Send Book")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                Button("Edit Setup") {
                    model.settingsTab = .delivery
                    openSettings()
                }
                .accessibilityIdentifier("sendBook.editSetup")
            }

            BookDropTarget(
                isBusy: model.isImporting
                    || model.isSending
                    || model.isShowingConfirmation,
                choose: { isShowingImporter = true },
                add: model.addBooks
            )

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
                    if !model.items.isEmpty {
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
                                ItemDetailDisclosure(item: item)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .accessibilityIdentifier("sendBook.batch")
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

            Button(action: model.requestSendConfirmation) {
                Text(model.isSending ? "Sending…" : "Send")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .padding(.top, 8)
            .disabled(
                model.setup == nil
                    || model.initialEligibleCount == 0
                    || model.isSending
                    || model.isImporting
                    || model.isShowingConfirmation
            )
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("sendBook.send")
        }
        .padding(36)
        .frame(minWidth: 620, minHeight: 620)
        .modifier(
            BookFileImporter(
                isPresented: $isShowingImporter,
                add: model.addBooks
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
