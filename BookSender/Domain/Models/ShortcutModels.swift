import Foundation

enum ShortcutRegistrationState: Equatable, Sendable {
    case registered
    case disabled
    case conflict(message: String)
}

struct ShortcutPreference: Equatable, Sendable {
    var isEnabled: Bool
    var keyCombinationDescription: String?
    var registrationState: ShortcutRegistrationState
}
