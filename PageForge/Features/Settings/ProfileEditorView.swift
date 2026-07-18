import SwiftUI

struct ProfileEditorView: View {
    @Binding var profile: DeliveryProfile
    @Binding var secretDraft: String
    let hasSecret: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery profile")
                .font(.title3.weight(.semibold))
            TextField("Profile name", text: $profile.name)
            TextField("Sender email", text: $profile.senderEmail)
            TextField("Kindle email", text: $profile.kindleEmail)
            TextField("SMTP host", text: $profile.smtpHost)
            TextField("SMTP port", value: $profile.smtpPort, format: .number)
            TextField("SMTP username (optional)", text: $profile.smtpUsername)
            Toggle("Use TLS", isOn: $profile.useTLS)
            TextField("Default output directory", text: $profile.defaultOutputDir)
            SecureField(hasSecret ? "Replace SMTP password/token" : "SMTP password/token", text: $secretDraft)
            Text(hasSecret ? "Secret present in Keychain" : "Secret missing")
                .font(.caption)
                .foregroundStyle(hasSecret ? .green : .orange)
            Button("Save Profile") { onSave() }
                .buttonStyle(.borderedProminent)
        }
    }
}
