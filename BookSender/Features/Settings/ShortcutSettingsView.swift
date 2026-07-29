import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    let disable: () -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    KeyboardShortcuts.Recorder("Shortcut:", name: .showBookSender)
                        .accessibilityIdentifier("settings.shortcut")
                    Spacer()
                    Button("Disable", action: disable)
                        .accessibilityIdentifier("settings.shortcut.disable")
                }
            } header: {
                Text("Quick Access")
            } footer: {
                Text("Reveal the existing Book Sender window from any app.")
            }
        }
        .padding(20)
        .accessibilityIdentifier("settings.shortcut.content")
    }
}
