import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var model: AppModel
    let setEnabled: @MainActor @Sendable (Bool) -> Void
    let shortcutChanged: @MainActor @Sendable () -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    KeyboardShortcuts.Recorder(for: .showBookSender) { _ in
                        shortcutChanged()
                    }
                    .disabled(!model.shortcutPreference.isEnabled)
                    .accessibilityIdentifier("settings.shortcut")
                    Spacer()

                    Toggle("", isOn: enabledBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Enable shortcut")
                        .accessibilityIdentifier("settings.shortcut.enabled")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reveal the existing Book Sender window from any app.")
                    Text(registrationMessage)
                        .foregroundStyle(registrationColor)
                        .accessibilityIdentifier(
                            "settings.shortcut.registrationState"
                        )
                }
            }
        }
        .padding(20)
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

    private var registrationMessage: String {
        switch model.shortcutPreference.registrationState {
        case .registered: "Shortcut registered."
        case .disabled: "Shortcut disabled."
        case .conflict(let message): message
        }
    }

    private var registrationColor: Color {
        if case .conflict = model.shortcutPreference.registrationState {
            return .orange
        }
        return .secondary
    }
}
