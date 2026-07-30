import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var model: AppModel
    let setEnabled: @MainActor @Sendable (Bool) -> Void
    let shortcutChanged: @MainActor @Sendable () -> Void
    @FocusState private var isShortcutFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                KeyboardShortcuts.Recorder(for: .showBookSender) { _ in
                    shortcutChanged()
                }
                .disabled(!model.shortcutPreference.isEnabled)
                .focused($isShortcutFocused)
                .accessibilityIdentifier("settings.shortcut")
                Spacer()

                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("Enable shortcut")
                    .accessibilityIdentifier("settings.shortcut.enabled")
            }

            if let feedback = model.feedback(for: .shortcut) {
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

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.shortcut.content")
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.shortcutPreference.isEnabled },
            set: { isEnabled in
                setEnabled(isEnabled)
            }
        )
    }

    private func handleRecovery(_ action: RecoveryAction) {
        if action == .chooseAnotherShortcut {
            isShortcutFocused = true
        }
    }
}
