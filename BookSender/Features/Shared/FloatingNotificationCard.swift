import AppKit
import SwiftUI

struct FloatingNotificationCard: View {
    let entry: FloatingNotificationEntry
    let close: () -> Void
    let activate: (NotificationActionDescriptor) -> Void
    let announce: () -> Void

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            notificationIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.feedback.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = entry.feedback.message,
                   !message.trimmingCharacters(
                       in: .whitespacesAndNewlines
                   ).isEmpty {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(entry.configuration.messageLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if entry.feedback.occurrenceCount > 1 {
                    Text("\(entry.feedback.occurrenceCount) occurrences")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityIdentifier(
                            "notification.count.\(scopeIdentifier)"
                        )
                }

                if let action = entry.configuration.action {
                    Button(action.label) {
                        activate(action)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(entry.isActionInFlight)
                    .accessibilityHint(
                        "Performs the suggested recovery action once."
                    )
                    .accessibilitySortPriority(2)
                    .accessibilityIdentifier(
                        "notification.action.\(scopeIdentifier)"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if entry.configuration.closePolicy == .shown {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss notification")
                .accessibilityHint(
                    "Hides this notification without changing the operation."
                )
                .accessibilitySortPriority(1)
                .accessibilityIdentifier(
                    "notification.close.\(scopeIdentifier)"
                )
            }
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 14)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(entry.feedback.accessibilityAnnouncement)
        .accessibilityValue(stateTitle)
        .accessibilityIdentifier("notification.\(scopeIdentifier)")
        .onAppear(perform: announce)
        .onChange(of: entry.feedback.state) {
            announce()
        }
    }

    @ViewBuilder
    private var notificationIcon: some View {
        switch entry.configuration.icon {
        case .none:
            EmptyView()
        case .automatic:
            if entry.feedback.state == .inProgress {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: automaticSymbol)
                    .font(.title3)
                    .foregroundStyle(semanticColor)
                    .accessibilityHidden(true)
            }
        case .system(let name):
            Image(systemName: name)
                .font(.title3)
                .foregroundStyle(
                    colorSchemeContrast == .increased
                        ? Color.primary
                        : semanticColor
                )
                .accessibilityHidden(true)
        }
    }

    private var scopeIdentifier: String {
        entry.feedback.scope.accessibilityIdentifier
    }

    private var automaticSymbol: String {
        switch entry.feedback.state {
        case .acknowledged: "info.circle"
        case .inProgress: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .cancelled: "slash.circle"
        case .partial: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.diamond.fill"
        }
    }

    private var stateTitle: String {
        switch entry.feedback.state {
        case .acknowledged: "Acknowledged"
        case .inProgress: "In progress"
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .partial: "Partial"
        case .unknown: "Unknown"
        }
    }

    private var semanticColor: Color {
        switch entry.feedback.state {
        case .acknowledged, .inProgress:
            .secondary
        case .succeeded:
            .green
        case .failed:
            .red
        case .cancelled:
            .secondary
        case .partial, .unknown:
            .orange
        }
    }
}
