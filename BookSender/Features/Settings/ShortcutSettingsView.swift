import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @AppStorage(ShortcutService.isEnabledDefaultsKey) private var isEnabled = true
    let setEnabled: (Bool) -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    KeyboardShortcuts.Recorder(for: .showBookSender) { shortcut in
                        if shortcut == nil, isEnabled {
                            KeyboardShortcuts.reset(.showBookSender)
                        }
                    }
                        .disabled(!isEnabled)
                        .accessibilityIdentifier("settings.shortcut")
                    Spacer()

                    Toggle("", isOn: enabledBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Enable shortcut")
                        .accessibilityIdentifier("settings.shortcut.enabled")
                }
            } footer: {
                Text("Reveal the existing Book Sender window from any app.")
            }
        }
        .padding(20)
        .accessibilityIdentifier("settings.shortcut.content")
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { newValue in
                isEnabled = newValue
                setEnabled(newValue)
            }
        )
    }
}
