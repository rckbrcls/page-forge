import AppKit
import SwiftUI

struct ActionFeedbackView: View {
    let feedback: ActionFeedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastAnnouncedID: UUID?
    @State private var lastAnnouncedState: FeedbackState?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.title)
                    .font(.callout.weight(.semibold))
                if let message = feedback.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if feedback.occurrenceCount > 1 {
                    Text("Occurred \(feedback.occurrenceCount) times.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(feedback.accessibilityAnnouncement)
        .accessibilityValue(stateTitle)
        .accessibilityIdentifier(
            "feedback.\(feedback.scope.accessibilityIdentifier)"
        )
        .transition(reduceMotion ? .identity : .opacity)
        .onAppear {
            announceIfNeeded()
        }
        .onChange(of: feedback.state) {
            announceIfNeeded()
        }
        .onChange(of: feedback.id) {
            announceIfNeeded()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch feedback.state {
        case .acknowledged:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)
        case .partial:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var stateTitle: String {
        switch feedback.state {
        case .acknowledged: "Acknowledged"
        case .inProgress: "In progress"
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .partial: "Partially completed"
        case .unknown: "Result unknown"
        }
    }

    private func announceIfNeeded() {
        guard feedback.state != .acknowledged else { return }
        guard lastAnnouncedID != feedback.id
            || lastAnnouncedState != feedback.state
        else {
            return
        }
        guard let application = NSApp else { return }
        lastAnnouncedID = feedback.id
        lastAnnouncedState = feedback.state
        NSAccessibility.post(
            element: application,
            notification: .announcementRequested,
            userInfo: [
                .announcement: feedback.accessibilityAnnouncement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }
}
