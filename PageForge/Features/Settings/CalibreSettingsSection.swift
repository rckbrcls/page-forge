import SwiftUI

struct CalibreSettingsSection: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: CalibreManagementAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: appState.calibreStatus.isReady
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill")
                    .foregroundStyle(appState.calibreStatus.isReady
                        ? Color.Theme.success
                        : Color.Theme.warning)
                Text(appState.calibreStatus.isReady
                    ? "Calibre is ready."
                    : "Calibre is required to prepare files.")
            }

            if appState.isCheckingCalibre || appState.isManagingCalibre {
                ProgressView()
                    .controlSize(.small)
            }

            if let message = appState.calibreMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Color.Theme.textSecondary)
            }

            HStack {
                Button("Check Again") {
                    appState.refreshCalibre()
                }
                .disabled(appState.isCheckingCalibre || appState.isManagingCalibre)

                if let action = appState.calibreAction {
                    Button(actionButtonTitle(for: action)) {
                        pendingAction = action
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isCheckingCalibre || appState.isManagingCalibre)
                }
            }
        }
        .sheet(item: $pendingAction) { action in
            CalibreConfirmationView(
                action: action,
                onCancel: { pendingAction = nil },
                onConfirm: {
                    pendingAction = nil
                    switch action {
                    case .install, .update:
                        appState.performCalibreAction(action)
                    case .openOfficialWebsite:
                        openURL(CalibreManagementService.officialDownloadURL)
                    }
                }
            )
        }
    }

    private func actionButtonTitle(for action: CalibreManagementAction) -> String {
        action.purpose == .install ? "Install Calibre" : "Update Calibre"
    }
}

private struct CalibreConfirmationView: View {
    let action: CalibreManagementAction
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(explanation)
                .foregroundStyle(.secondary)

            if let command = action.command {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(Color.Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var title: String {
        switch action {
        case .install: return "Install Calibre?"
        case .update: return "Update Calibre?"
        case .openOfficialWebsite(_, let reason):
            return reason == .homebrewMissing ? "Homebrew Not Found" : "Manual Calibre Update"
        }
    }

    private var explanation: String {
        switch action {
        case .install:
            return "PageForge uses Calibre to prepare books. Homebrew will install Calibre and its ebook tools. No documents are uploaded."
        case .update:
            return "Homebrew will update Calibre. Your documents and PageForge settings stay unchanged."
        case .openOfficialWebsite(_, let reason):
            return reason == .homebrewMissing
                ? "Automatic setup needs Homebrew. Download Calibre from the official website."
                : "This Calibre installation is managed manually. Update it from the official website."
        }
    }

    private var confirmTitle: String {
        switch action {
        case .install: return "Install"
        case .update: return "Update"
        case .openOfficialWebsite: return "Open Official Website"
        }
    }
}
