import Foundation
import Observation

@MainActor
@Observable
final class FloatingNotificationCenter {
    private struct DestinationState {
        var entries: [NotificationKey: FloatingNotificationEntry] = [:]
        var visibleKeys: [NotificationKey] = []
        var queuedKeys: [NotificationKey] = []
        var hiddenKeys: Set<NotificationKey> = []
        var isHostAttached = false
    }

    private var states: [NotificationDestination: DestinationState] = [:]
    private(set) var focusRequest: NotificationFocusRequest?

    @ObservationIgnored
    private let sleep: FeedbackSleep
    @ObservationIgnored
    private var expiryTasks: [NotificationTaskKey: Task<Void, Never>] = [:]

    init(
        sleep: @escaping FeedbackSleep = { duration in
            try await Task.sleep(for: .seconds(duration))
        }
    ) {
        self.sleep = sleep
        for destination in NotificationDestination.allCases {
            states[destination] = DestinationState()
        }
    }

    func snapshot(
        for destination: NotificationDestination
    ) -> NotificationDestinationSnapshot {
        let state = state(for: destination)
        return NotificationDestinationSnapshot(
            destination: destination,
            visible: state.visibleKeys.compactMap { state.entries[$0] },
            queuedCount: state.queuedKeys.count,
            isHostAttached: state.isHostAttached
        )
    }

    func feedback(
        for scope: FeedbackScope,
        destination: NotificationDestination
    ) -> ActionFeedback? {
        state(for: destination).entries[
            NotificationKey(destination: destination, scope: scope)
        ]?.feedback
    }

    func takeAccessibilityAnnouncement(
        feedbackID: UUID,
        destination: NotificationDestination
    ) -> String? {
        guard let key = key(
            for: feedbackID,
            destination: destination
        ) else { return nil }
        var destinationState = state(for: destination)
        guard var entry = destinationState.entries[key],
              entry.phase == .visible,
              entry.feedback.state != .acknowledged,
              entry.lastAnnouncedState != entry.feedback.state
        else { return nil }
        entry.lastAnnouncedState = entry.feedback.state
        destinationState.entries[key] = entry
        states[destination] = destinationState
        return entry.feedback.accessibilityAnnouncement
    }

    func publish(
        _ feedback: ActionFeedback,
        destination: NotificationDestination,
        configuration requestedConfiguration:
            FloatingNotificationConfiguration? = nil,
        now: Date = Date()
    ) {
        let key = NotificationKey(
            destination: destination,
            scope: feedback.scope
        )
        var destinationState = state(for: destination)
        let configuration = (
            requestedConfiguration
                ?? .defaultConfiguration(for: feedback)
        ).normalized(for: feedback)

        if let current = destinationState.entries[key],
           current.feedback.id == feedback.id {
            var updated = current
            let shouldRestartExpiry =
                current.feedback.state != feedback.state
                || current.configuration.lifetime != configuration.lifetime
            updated.feedback = feedback
            updated.configuration = configuration
            destinationState.entries[key] = updated
            states[destination] = destinationState
            if updated.phase == .visible {
                if updated.configuration.lifetime.isTemporary {
                    let taskKey = NotificationTaskKey(
                        destination: destination,
                        feedbackID: feedback.id
                    )
                    if shouldRestartExpiry || expiryTasks[taskKey] == nil {
                        scheduleExpiryIfNeeded(for: key)
                    }
                } else {
                    cancelExpiry(for: updated)
                }
            }
            return
        }

        if let current = destinationState.entries[key],
           equivalent(current.feedback, feedback)
        {
            var updated = current
            updated.feedback = incrementingOccurrence(
                current: current.feedback,
                proposed: feedback
            )
            updated.configuration = configuration
            destinationState.entries[key] = updated
            states[destination] = destinationState
            return
        }

        if let current = destinationState.entries[key] {
            cancelExpiry(for: current)
            destinationState.visibleKeys.removeAll { $0 == key }
            destinationState.queuedKeys.removeAll { $0 == key }
            destinationState.hiddenKeys.remove(key)
        }

        let shouldShow = destinationState.isHostAttached
            && destinationState.visibleKeys.count
                < FloatingNotificationLimits.visiblePerDestination
        let phase: NotificationPhase = shouldShow ? .visible : .queued
        let entry = FloatingNotificationEntry(
            key: key,
            feedback: feedback,
            configuration: configuration,
            phase: phase,
            enqueuedAt: now,
            visibleAt: shouldShow ? now : nil
        )
        destinationState.entries[key] = entry
        if shouldShow {
            destinationState.visibleKeys.insert(key, at: 0)
        } else {
            destinationState.queuedKeys.append(key)
        }
        states[destination] = destinationState
        if shouldShow {
            scheduleExpiryIfNeeded(for: key)
        }
    }

    func close(
        feedbackID: UUID,
        destination: NotificationDestination
    ) {
        guard let key = key(
            for: feedbackID,
            destination: destination
        ) else { return }
        var destinationState = state(for: destination)
        guard var entry = destinationState.entries[key],
              entry.configuration.closePolicy == .shown
        else { return }

        cancelExpiry(for: entry)
        destinationState.visibleKeys.removeAll { $0 == key }
        destinationState.queuedKeys.removeAll { $0 == key }

        if entry.configuration.lifetime.isTemporary {
            destinationState.entries.removeValue(forKey: key)
            destinationState.hiddenKeys.remove(key)
        } else {
            entry.phase = .hidden
            entry.isActionInFlight = false
            destinationState.entries[key] = entry
            destinationState.hiddenKeys.insert(key)
        }
        states[destination] = destinationState
        promoteQueuedEntries(for: destination)
    }

    func remove(
        scope: FeedbackScope,
        destination: NotificationDestination
    ) {
        let key = NotificationKey(destination: destination, scope: scope)
        var destinationState = state(for: destination)
        guard let entry = destinationState.entries.removeValue(forKey: key)
        else { return }
        cancelExpiry(for: entry)
        destinationState.visibleKeys.removeAll { $0 == key }
        destinationState.queuedKeys.removeAll { $0 == key }
        destinationState.hiddenKeys.remove(key)
        states[destination] = destinationState
        promoteQueuedEntries(for: destination)
    }

    func beginAction(
        feedbackID: UUID,
        destination: NotificationDestination
    ) -> NotificationActionDescriptor? {
        guard let key = key(
            for: feedbackID,
            destination: destination
        ) else { return nil }
        var destinationState = state(for: destination)
        guard var entry = destinationState.entries[key],
              entry.phase == .visible,
              !entry.isActionInFlight,
              let action = entry.configuration.action
        else { return nil }
        entry.isActionInFlight = true
        destinationState.entries[key] = entry
        states[destination] = destinationState
        return action
    }

    func completeAction(
        feedbackID: UUID,
        destination: NotificationDestination,
        actionID: UUID,
        didChangeState: Bool
    ) {
        guard let key = key(
            for: feedbackID,
            destination: destination
        ) else { return }
        var destinationState = state(for: destination)
        guard var entry = destinationState.entries[key],
              let action = entry.configuration.action,
              action.id == actionID
        else { return }

        switch action.dismissalAfterActivation {
        case .keep:
            entry.isActionInFlight = false
            destinationState.entries[key] = entry
            states[destination] = destinationState
        case .hide:
            states[destination] = destinationState
            closeAfterAction(key: key, entry: entry)
        case .awaitReplacement:
            if !didChangeState {
                entry.isActionInFlight = false
                destinationState.entries[key] = entry
                states[destination] = destinationState
            }
        }
    }

    func requestFocus(
        destination: NotificationDestination,
        action: RecoveryAction
    ) {
        focusRequest = NotificationFocusRequest(
            destination: destination,
            action: action
        )
    }

    func consumeFocusRequest(id: UUID) {
        guard focusRequest?.id == id else { return }
        focusRequest = nil
    }

    func attach(_ destination: NotificationDestination) {
        var destinationState = state(for: destination)
        destinationState.isHostAttached = true
        states[destination] = destinationState
        promoteQueuedEntries(for: destination)
    }

    func detach(_ destination: NotificationDestination) {
        var destinationState = state(for: destination)
        destinationState.isHostAttached = false

        let keys = Array(destinationState.visibleKeys.reversed())
            + destinationState.queuedKeys
        destinationState.visibleKeys.removeAll()
        destinationState.queuedKeys.removeAll()

        for key in keys {
            guard var entry = destinationState.entries[key] else { continue }
            cancelExpiry(for: entry)
            if entry.configuration.lifetime.isTemporary {
                destinationState.entries.removeValue(forKey: key)
            } else {
                entry.phase = .queued
                entry.isActionInFlight = false
                destinationState.entries[key] = entry
                destinationState.queuedKeys.append(key)
            }
        }
        states[destination] = destinationState
    }

    private func state(
        for destination: NotificationDestination
    ) -> DestinationState {
        states[destination] ?? DestinationState()
    }

    private func key(
        for feedbackID: UUID,
        destination: NotificationDestination
    ) -> NotificationKey? {
        state(for: destination).entries.first {
            $0.value.feedback.id == feedbackID
        }?.key
    }

    private func equivalent(
        _ current: ActionFeedback,
        _ proposed: ActionFeedback
    ) -> Bool {
        current.scope == proposed.scope
            && current.action == proposed.action
            && current.state == proposed.state
            && current.title == proposed.title
            && current.message == proposed.message
            && current.failure == proposed.failure
    }

    private func incrementingOccurrence(
        current: ActionFeedback,
        proposed: ActionFeedback
    ) -> ActionFeedback {
        ActionFeedback(
            id: current.id,
            scope: current.scope,
            action: current.action,
            state: current.state,
            title: current.title,
            message: current.message,
            startedAt: current.startedAt,
            updatedAt: proposed.updatedAt,
            dismissal: current.dismissal,
            failure: current.failure,
            occurrenceCount: current.occurrenceCount + 1
        )
    }

    private func closeAfterAction(
        key: NotificationKey,
        entry: FloatingNotificationEntry
    ) {
        var destinationState = state(for: key.destination)
        cancelExpiry(for: entry)
        destinationState.visibleKeys.removeAll { $0 == key }
        destinationState.queuedKeys.removeAll { $0 == key }
        if entry.configuration.lifetime.isTemporary {
            destinationState.entries.removeValue(forKey: key)
        } else {
            var hidden = entry
            hidden.phase = .hidden
            hidden.isActionInFlight = false
            destinationState.entries[key] = hidden
            destinationState.hiddenKeys.insert(key)
        }
        states[key.destination] = destinationState
        promoteQueuedEntries(for: key.destination)
    }

    private func promoteQueuedEntries(
        for destination: NotificationDestination
    ) {
        var destinationState = state(for: destination)
        guard destinationState.isHostAttached else { return }

        var promotedKeys: [NotificationKey] = []
        while destinationState.visibleKeys.count
                < FloatingNotificationLimits.visiblePerDestination,
              !destinationState.queuedKeys.isEmpty
        {
            let key = destinationState.queuedKeys.removeFirst()
            guard var entry = destinationState.entries[key],
                  entry.phase == .queued
            else { continue }
            entry.phase = .visible
            entry.visibleAt = Date()
            destinationState.entries[key] = entry
            destinationState.visibleKeys.insert(key, at: 0)
            promotedKeys.append(key)
        }
        states[destination] = destinationState
        for key in promotedKeys {
            scheduleExpiryIfNeeded(for: key)
        }
    }

    private func scheduleExpiryIfNeeded(for key: NotificationKey) {
        guard let entry = state(for: key.destination).entries[key],
              entry.phase == .visible,
              let duration = entry.configuration.lifetime.temporaryDuration
        else { return }

        cancelExpiry(for: entry)
        let taskKey = NotificationTaskKey(
            destination: key.destination,
            feedbackID: entry.feedback.id
        )
        let sleep = sleep
        expiryTasks[taskKey] = Task { [weak self] in
            do {
                try await sleep(duration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.expire(key: key, taskKey: taskKey)
        }
    }

    private func expire(
        key: NotificationKey,
        taskKey: NotificationTaskKey
    ) {
        var destinationState = state(for: key.destination)
        guard let entry = destinationState.entries[key],
              entry.feedback.id == taskKey.feedbackID,
              entry.phase == .visible,
              entry.configuration.lifetime.isTemporary
        else {
            expiryTasks.removeValue(forKey: taskKey)
            return
        }
        destinationState.entries.removeValue(forKey: key)
        destinationState.visibleKeys.removeAll { $0 == key }
        expiryTasks.removeValue(forKey: taskKey)
        states[key.destination] = destinationState
        promoteQueuedEntries(for: key.destination)
    }

    private func cancelExpiry(for entry: FloatingNotificationEntry) {
        let taskKey = NotificationTaskKey(
            destination: entry.key.destination,
            feedbackID: entry.feedback.id
        )
        expiryTasks.removeValue(forKey: taskKey)?.cancel()
    }
}
