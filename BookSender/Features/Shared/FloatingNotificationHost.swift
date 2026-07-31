import AppKit
import SwiftUI

struct FloatingNotificationHost<Content: View>: View {
    @Bindable var center: FloatingNotificationCenter
    let destination: NotificationDestination
    let performAction: @MainActor (RecoveryAction) -> Bool
    private let content: Content

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(
        center: FloatingNotificationCenter,
        destination: NotificationDestination,
        performAction: @escaping @MainActor (RecoveryAction) -> Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.center = center
        self.destination = destination
        self.performAction = performAction
        self.content = content()
    }

    var body: some View {
        content
            .overlay(alignment: .topTrailing) {
                notificationStack
                    .padding(.top, 14)
                    .padding(.trailing, 20)
            }
            .onAppear {
                center.attach(destination)
            }
            .onDisappear {
                center.detach(destination)
            }
    }

    private var notificationStack: some View {
        let snapshot = center.snapshot(for: destination)
        return GlassEffectContainer(spacing: 10) {
            VStack(alignment: .trailing, spacing: 10) {
                ForEach(snapshot.visible) { entry in
                    FloatingNotificationCard(
                        entry: entry,
                        close: {
                            center.close(
                                feedbackID: entry.feedback.id,
                                destination: destination
                            )
                        },
                        activate: { _ in
                            activate(entry)
                        },
                        announce: {
                            announce(entry)
                        }
                    )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .trailing).combined(with: .opacity)
                    )
                }
            }
        }
        .frame(maxWidth: 360, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "notification.host.\(destination.accessibilityIdentifier)"
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: snapshot.visible.map(\.id)
        )
    }

    private func activate(_ entry: FloatingNotificationEntry) {
        guard let action = center.beginAction(
            feedbackID: entry.feedback.id,
            destination: destination
        ) else { return }
        let didChangeState = performAction(action.command)
        center.completeAction(
            feedbackID: entry.feedback.id,
            destination: destination,
            actionID: action.id,
            didChangeState: didChangeState
        )
    }

    private func announce(_ entry: FloatingNotificationEntry) {
        guard let application = NSApp,
              let announcement = center.takeAccessibilityAnnouncement(
                feedbackID: entry.feedback.id,
                destination: destination
              )
        else { return }
        NSAccessibility.post(
            element: application,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }
}
