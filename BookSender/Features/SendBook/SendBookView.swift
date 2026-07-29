import SwiftUI

struct SendBookView: View {
    @Bindable var model: AppModel
    @State private var isShowingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Send Book")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Books are checked and prepared locally before you confirm delivery.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit Setup", action: model.editSetup)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sendBook.editSetup")
            }

            BookDropTarget(isBusy: model.isImporting, add: model.addBooks)

            HStack {
                Button("Choose in Finder…") {
                    isShowingImporter = true
                }
                .accessibilityIdentifier("sendBook.choose")
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
                        .buttonStyle(.plain)
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
                    }
                }
                .listStyle(.inset)
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.eligibleCount == 0 || model.isSending)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("sendBook.send")
        }
        .padding(36)
        .frame(minWidth: 620, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
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
