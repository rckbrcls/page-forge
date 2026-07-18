import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private enum Keys {
        static let appTheme = "settings.appTheme"
    }

    private let defaults: UserDefaults

    @Published private(set) var currentTheme: AppTheme {
        didSet {
            defaults.set(currentTheme.rawValue, forKey: Keys.appTheme)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTheme = defaults.string(forKey: Keys.appTheme) ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: storedTheme) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        currentTheme.colorScheme
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}
