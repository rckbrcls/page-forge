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
                if model.isPreviewingSendBook {
                    Button("Back to Setup", action: model.returnToDeliverySetup)
                        .accessibilityIdentifier("sendBook.backToSetup")
                } else {
                    Button("Edit Setup") {
                        model.settingsTab = .delivery
                        openSettings()
                    }
                    .accessibilityIdentifier("sendBook.editSetup")
                }
            }

            BookDropTarget(
                isBusy: model.isImporting,
                choose: { isShowingImporter = true },
                add: model.addBooks
            )

            if model.isImporting || !model.items.isEmpty {
                HStack {
                    if model.isImporting {
                        ProgressView()
                            .controlSize(.small)
                        Text("Adding books…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.items.isEmpty {
                        Button("Clear", action: model.clear)
                    }
                }
            }

            if !model.items.isEmpty {
                List {
                    ForEach(model.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            BatchItemRow(item: item) { model.remove(item.id) }
                            if case .needsAttention = item.preparation {
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

            Button {
                model.requestSendConfirmation()
            } label: {
                Text(model.isSending ? "Sending…" : "Send")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .disabled(model.setup == nil || model.eligibleCount == 0 || model.isSending)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("sendBook.send")
        }
        .padding(36)
        .frame(minWidth: 620, minHeight: 620)
        .modifier(BookFileImporter(isPresented: $isShowingImporter, add: model.addBooks))
        .sheet(isPresented: $model.isShowingConfirmation) {
            BatchConfirmationView(
                destination: model.setup?.kindleAddress.value ?? "",
                eligibleCount: model.eligibleCount,
                excludedCount: model.excludedCount,
                cancel: { model.isShowingConfirmation = false },
                confirm: model.confirmSend
            )
        }
    }
}
