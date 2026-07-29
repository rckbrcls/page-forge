import SwiftUI

struct ItemDetailDisclosure: View {
    let item: BatchItem

    var body: some View {
        DisclosureGroup("Details") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(item.findings) { finding in
                    Text(finding.messageKey)
                }
                ForEach(item.appliedActions) { action in
                    Label(action.action.identifier, systemImage: action.verified ? "checkmark" : "exclamationmark")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("sendBook.itemDetails.\(item.id.uuidString)")
    }
}
