import AppKit
import SwiftUI

struct DocumentWorkflowView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: DocumentWorkflowViewModel
    let openSettings: () -> Void

    @State private var confirmsReplacement = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.queue.items.isEmpty {
                emptyState
            } else {
                queueContent
            }
            actionBar
        }
        .themedScreenBackground()
        .sheet(isPresented: Binding(
            get: { viewModel.inspectedMetadata != nil },
            set: { if !$0 { viewModel.inspectedMetadata = nil } }
        )) {
            metadataEditor
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PageForge")
                    .appLargeTitleStyle()
                Text("Prepare documents for Kindle, then save or send them.")
                    .foregroundStyle(Color.Theme.textSecondary)
            }
            Spacer()
            if !viewModel.queue.items.isEmpty {
                Text("\(viewModel.queue.completedCount) ready · \(viewModel.queue.items.count) total")
                    .foregroundStyle(Color.Theme.textSecondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var emptyState: some View {
        FileDropIntakeView(
            title: "Drop EPUB, MOBI, or PDF files",
            subtitle: "Add one document or a whole selection. Originals stay unchanged.",
            allowFolders: false,
            onPick: viewModel.addFiles
        )
        .padding(28)
        .frame(maxHeight: .infinity)
    }

    private var queueContent: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Select All") { viewModel.selectAll(true) }
                Button("Select None") { viewModel.selectAll(false) }
                Button("Remove Selected") { viewModel.removeSelected() }
                    .disabled(!viewModel.queue.canRemove)
                Spacer()
                if let summary = viewModel.queue.intakeSummary, summary.rejectedCount > 0 {
                    Text("\(summary.rejectedCount) rejected")
                        .foregroundStyle(Color.Theme.warning)
                }
            }
            .controlSize(.small)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.queue.items) { item in
                        DocumentQueueRow(
                            item: item,
                            onSelectionChanged: { viewModel.setSelected(item.id, selected: $0) },
                            onRemove: { viewModel.remove(item.id) },
                            onRetry: { viewModel.retry(item.id) },
                            onReveal: { viewModel.revealOutput(item.id) },
                            onInspectMetadata: { viewModel.inspectMetadata(item.id) },
                            onAggressiveRepair: {
                                viewModel.aggressiveRepair(item.id, confirmed: true)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Color.Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if viewModel.queue.isProcessing {
                Button("Cancel Pending") { viewModel.cancelPendingPreparation() }
            }
            Button("Prepare Files") { viewModel.prepareSelected() }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.queue.canPrepare)
            Menu("Save Files") {
                Button("Choose Folder…") {
                    chooseExportDirectory(replacingExisting: false)
                }
                Button("Replace Existing Files…", role: .destructive) {
                    confirmsReplacement = true
                }
            }
                .disabled(!viewModel.queue.canSaveFiles || viewModel.isSaving)
                .confirmationDialog(
                    "Replace files with matching names?",
                    isPresented: $confirmsReplacement
                ) {
                    Button("Replace Existing Files", role: .destructive) {
                        chooseExportDirectory(replacingExisting: true)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            if !viewModel.deliveryProfileNames.isEmpty {
                Picker("Profile", selection: $viewModel.selectedProfileName) {
                    ForEach(viewModel.deliveryProfileNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
                .accessibilityLabel("Delivery Profile")
            }
            Button("Send to Kindle") { viewModel.sendSelected() }
                .disabled(!viewModel.queue.canSendToKindle || viewModel.isSending)
            if viewModel.isSending {
                Button("Cancel Pending Send") { viewModel.cancelPendingDelivery() }
            }
            if viewModel.shouldOfferSettingsRecovery {
                Button("Open Settings", action: openSettings)
            }
        }
        .padding(18)
        .background(Color.Theme.secondaryBackground)
        .overlay(alignment: .top) { Divider() }
    }

    private var metadataEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Metadata")
                .font(.title2.weight(.semibold))
            TextField("Title", text: $viewModel.metadataTitle)
            TextField("Author", text: $viewModel.metadataAuthor)
            HStack {
                Spacer()
                Button("Cancel") { viewModel.inspectedMetadata = nil }
                Button("Save") {
                    viewModel.saveMetadata()
                    viewModel.inspectedMetadata = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func chooseExportDirectory(replacingExisting: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let configuredPath = try? appState.configService.load().defaultOutputDirectory,
           !configuredPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: configuredPath, isDirectory: true)
        }
        if panel.runModal() == .OK, let directory = panel.url {
            viewModel.saveSelected(to: directory, replacingExisting: replacingExisting)
        }
    }
}
