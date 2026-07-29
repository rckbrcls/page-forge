import KeyboardShortcuts
import SwiftUI

struct ShortcutPreferenceSection: View {
    let disable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Access")
                .font(.headline)
            Text("Reveal the existing Book Sender window from any app.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                KeyboardShortcuts.Recorder("Shortcut:", name: .showBookSender)
                    .accessibilityIdentifier("deliverySetup.shortcut")
                Spacer()
                Button("Disable", action: disable)
                    .buttonStyle(.plain)
            }
        }
    }
}
