import Foundation

enum FloatingNotificationLimits {
    static let visiblePerDestination = 3
}

enum NotificationReason: CaseIterable, Equatable, Sendable {
    case protectedCredentialPersistence
    case protectedCredentialDeletion
    case clipboardWrite
    case submissionHistoryPersistence
    case consequentialHiddenFailure
    case auxiliarySystemActionFailure
}

enum NotificationPublicationIntent: Equatable, Sendable {
    case contextual
    case floating(NotificationReason)

    func approvedReason(for state: FeedbackState) -> NotificationReason? {
        guard state.isTerminal, case .floating(let reason) = self else {
            return nil
        }
        return reason
    }
}

enum NotificationDestination: String, CaseIterable, Equatable, Hashable, Sendable {
    case main
    case settings

    var accessibilityIdentifier: String {
        rawValue
    }
}

struct NotificationKey: Equatable, Hashable, Sendable {
    let destination: NotificationDestination
    let scope: FeedbackScope
}

enum NotificationIcon: Equatable, Sendable {
    case automatic
    case system(String)
    case none

    func normalized() -> NotificationIcon {
        guard case .system(let name) = self else { return self }
        let normalizedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return normalizedName.isEmpty
            ? .automatic
            : .system(normalizedName)
    }
}

enum NotificationLifetime: Equatable, Sendable {
    static let defaultTemporaryDuration: TimeInterval = 4
    static let permittedTemporaryRange: ClosedRange<TimeInterval> = 1...5

    case temporary(seconds: TimeInterval)
    case persistentUntilReplaced
    case explicit
    case stateDriven

    static func normalizedTemporary(
        _ requestedDuration: TimeInterval?
    ) -> NotificationLifetime {
        guard let requestedDuration, requestedDuration.isFinite else {
            return .temporary(seconds: defaultTemporaryDuration)
        }
        return .temporary(
            seconds: min(
                max(requestedDuration, permittedTemporaryRange.lowerBound),
                permittedTemporaryRange.upperBound
            )
        )
    }

    var temporaryDuration: TimeInterval? {
        guard case .temporary(let seconds) = self else { return nil }
        return seconds
    }

    var isTemporary: Bool {
        temporaryDuration != nil
    }
}

enum NotificationClosePolicy: Equatable, Sendable {
    case shown
    case hidden
}

enum NotificationActionDismissal: Equatable, Sendable {
    case keep
    case hide
    case awaitReplacement
}

struct NotificationActionDescriptor: Identifiable, Equatable, Sendable {
    let id: UUID
    let label: String
    let command: RecoveryAction
    let dismissalAfterActivation: NotificationActionDismissal

    init(
        id: UUID = UUID(),
        label: String,
        command: RecoveryAction,
        dismissalAfterActivation: NotificationActionDismissal
    ) {
        let normalizedLabel = label.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        precondition(!normalizedLabel.isEmpty)
        self.id = id
        self.label = normalizedLabel
        self.command = command
        self.dismissalAfterActivation = dismissalAfterActivation
    }
}

struct FloatingNotificationConfiguration: Equatable, Sendable {
    static let defaultMessageLineLimit = 3

    let icon: NotificationIcon
    let lifetime: NotificationLifetime
    let closePolicy: NotificationClosePolicy
    let action: NotificationActionDescriptor?
    let messageLineLimit: Int

    init(
        icon: NotificationIcon = .automatic,
        lifetime: NotificationLifetime,
        closePolicy: NotificationClosePolicy,
        action: NotificationActionDescriptor? = nil,
        messageLineLimit: Int = defaultMessageLineLimit
    ) {
        self.icon = icon.normalized()
        self.lifetime = lifetime
        self.closePolicy = closePolicy
        self.action = action
        self.messageLineLimit = max(1, messageLineLimit)
    }

    static func defaultConfiguration(
        for feedback: ActionFeedback
    ) -> FloatingNotificationConfiguration {
        switch feedback.state {
        case .acknowledged, .inProgress:
            return FloatingNotificationConfiguration(
                lifetime: .stateDriven,
                closePolicy: .hidden
            )
        case .succeeded:
            let requestedDuration: TimeInterval? = switch feedback.dismissal {
            case .delayed(let duration): duration
            case .persistentUntilReplaced, .explicit, .replaceOnNextAction: nil
            }
            return FloatingNotificationConfiguration(
                lifetime: .normalizedTemporary(requestedDuration),
                closePolicy: .shown
            )
        case .failed, .cancelled, .partial, .unknown:
            let lifetime: NotificationLifetime = switch feedback.dismissal {
            case .explicit: .explicit
            case .persistentUntilReplaced, .replaceOnNextAction, .delayed:
                .persistentUntilReplaced
            }
            return FloatingNotificationConfiguration(
                lifetime: lifetime,
                closePolicy: .shown
            )
        }
    }

    func normalized(
        for feedback: ActionFeedback
    ) -> FloatingNotificationConfiguration {
        var safeLifetime = lifetime
        var safeClosePolicy = closePolicy

        switch feedback.state {
        case .acknowledged, .inProgress:
            safeLifetime = .stateDriven
        case .succeeded:
            safeLifetime = .normalizedTemporary(lifetime.temporaryDuration)
        case .failed, .cancelled, .partial, .unknown:
            if lifetime.isTemporary {
                safeLifetime = .persistentUntilReplaced
            }
        }

        if !safeLifetime.isTemporary,
           safeClosePolicy == .hidden,
           action == nil,
           safeLifetime != .stateDriven
        {
            safeClosePolicy = .shown
        }

        return FloatingNotificationConfiguration(
            icon: icon,
            lifetime: safeLifetime,
            closePolicy: safeClosePolicy,
            action: action,
            messageLineLimit: messageLineLimit
        )
    }
}

enum NotificationPhase: Equatable, Sendable {
    case queued
    case visible
    case hidden
}

struct FloatingNotificationEntry: Identifiable, Equatable, Sendable {
    var id: UUID {
        feedback.id
    }

    let key: NotificationKey
    var feedback: ActionFeedback
    var configuration: FloatingNotificationConfiguration
    var phase: NotificationPhase
    let enqueuedAt: Date
    var visibleAt: Date?
    var isActionInFlight: Bool
    var lastAnnouncedState: FeedbackState?

    init(
        key: NotificationKey,
        feedback: ActionFeedback,
        configuration: FloatingNotificationConfiguration,
        phase: NotificationPhase,
        enqueuedAt: Date,
        visibleAt: Date? = nil,
        isActionInFlight: Bool = false,
        lastAnnouncedState: FeedbackState? = nil
    ) {
        precondition(feedback.scope == key.scope)
        precondition(phase != .visible || visibleAt != nil)
        self.key = key
        self.feedback = feedback
        self.configuration = configuration.normalized(for: feedback)
        self.phase = phase
        self.enqueuedAt = enqueuedAt
        self.visibleAt = visibleAt
        self.isActionInFlight = isActionInFlight
        self.lastAnnouncedState = lastAnnouncedState
    }
}

struct NotificationDestinationSnapshot: Equatable, Sendable {
    let destination: NotificationDestination
    let visible: [FloatingNotificationEntry]
    let queuedCount: Int
    let isHostAttached: Bool

    init(
        destination: NotificationDestination,
        visible: [FloatingNotificationEntry],
        queuedCount: Int,
        isHostAttached: Bool
    ) {
        precondition(
            visible.count
                <= FloatingNotificationLimits.visiblePerDestination
        )
        precondition(visible.allSatisfy { $0.key.destination == destination })
        self.destination = destination
        self.visible = visible
        self.queuedCount = max(0, queuedCount)
        self.isHostAttached = isHostAttached
    }
}

struct NotificationTaskKey: Equatable, Hashable, Sendable {
    let destination: NotificationDestination
    let feedbackID: UUID
}

struct NotificationFocusRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let destination: NotificationDestination
    let action: RecoveryAction

    init(
        id: UUID = UUID(),
        destination: NotificationDestination,
        action: RecoveryAction
    ) {
        self.id = id
        self.destination = destination
        self.action = action
    }
}

struct BatchRowPosition: Equatable, Sendable {
    let itemID: UUID
    let index: Int
    let count: Int

    init(itemID: UUID, index: Int, count: Int) {
        precondition(index >= 0)
        precondition(count > 0)
        precondition(index < count)
        self.itemID = itemID
        self.index = index
        self.count = count
    }

    var showsDivider: Bool {
        index < count - 1
    }

    static func positions(for itemIDs: [UUID]) -> [BatchRowPosition] {
        itemIDs.enumerated().map { index, itemID in
            BatchRowPosition(
                itemID: itemID,
                index: index,
                count: itemIDs.count
            )
        }
    }
}
