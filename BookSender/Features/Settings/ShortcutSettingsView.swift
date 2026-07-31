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

            if let failure = shortcutFeedback?.failure {
                FailureDetailView(
                    presentation: failure,
                    diagnosticEvent: model.currentDiagnosticEvent,
                    copyErrorDetails: {
                        model.copyCurrentErrorDetails(
                            destination: .settings
                        )
                    },
                    performRecovery: handleRecovery
                )
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.shortcut.content")
        .onAppear {
            consumeFocusRequestIfNeeded(
                model.notificationCenter.focusRequest
            )
        }
        .onChange(of: model.notificationCenter.focusRequest) { _, request in
            consumeFocusRequestIfNeeded(request)
        }
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

    private func consumeFocusRequestIfNeeded(
        _ request: NotificationFocusRequest?
    ) {
        guard let request,
              request.destination == .settings,
              request.action == .chooseAnotherShortcut
        else { return }
        isShortcutFocused = true
        model.notificationCenter.consumeFocusRequest(id: request.id)
    }

    private var shortcutFeedback: ActionFeedback? {
        model.feedback(for: .shortcut)
    }
}
