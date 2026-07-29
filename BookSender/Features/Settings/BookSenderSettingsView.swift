import SwiftUI

struct BookSenderSettingsView: View {
    @Bindable var model: AppModel
    let shortcutService: ShortcutService

    var body: some View {
        TabView(selection: $model.settingsTab) {
            DeliverySetupView(model: model, presentation: .settings)
                .tabItem {
                    Label("Delivery", systemImage: "envelope")
                        .accessibilityIdentifier("settings.tab.delivery")
                }
                .tag(AppModel.SettingsTab.delivery)
                .accessibilityIdentifier("settings.delivery.content")

            ShortcutSettingsView(
                model: model,
                setEnabled: { [shortcutService] isEnabled in
                    shortcutService.setEnabled(isEnabled)
                },
                shortcutChanged: { [shortcutService] in
                    shortcutService.shortcutChanged()
                }
            )
                .tabItem {
                    Label("Shortcut", systemImage: "keyboard")
                        .accessibilityIdentifier("settings.tab.shortcut")
                }
                .tag(AppModel.SettingsTab.shortcut)
        }
        .frame(width: 560, height: 500)
    }
}
