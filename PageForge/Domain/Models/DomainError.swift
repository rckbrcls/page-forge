import Foundation

enum DomainError: LocalizedError, Equatable {
    case dependency(String)
    case validation(String)
    case filesystem(String)
    case conversion(String)
    case repair(String)
    case configuration(String)
    case delivery(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .dependency(let message),
             .validation(let message),
             .filesystem(let message),
             .conversion(let message),
             .repair(let message),
             .configuration(let message),
             .delivery(let message):
            return message
        case .cancelled:
            return "Operation cancelled."
        }
    }
}
