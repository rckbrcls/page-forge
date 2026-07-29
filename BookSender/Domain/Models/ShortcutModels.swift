import Foundation

enum ShortcutRegistrationState: Equatable, Sendable {
    case registered
    case disabled
    case conflict(message: String)
}

struct ShortcutPreference: Equatable, Sendable {
    var isEnabled: Bool
    var registrationState: ShortcutRegistrationState
}
