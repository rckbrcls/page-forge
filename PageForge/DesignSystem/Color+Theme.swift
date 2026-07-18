import SwiftUI

extension Color {
    static let themeBackground = Color("Background")
    static let themeSecondaryBackground = Color("SecondaryBackground")
    static let themeTertiaryBackground = Color("TertiaryBackground")
    static let themeGroupedBackground = Color("GroupedBackground")

    static let themeTextPrimary = Color("TextPrimary")
    static let themeTextSecondary = Color("TextSecondary")
    static let themeTextTertiary = Color("TextTertiary")

    static let themeSeparator = Color("DividerColor")
    static let themeBorder = Color("Border")
    static let themeElementBackground = Color("ElementBackground")
    static let themeElementBorder = Color("ElementBorder")

    static let themeAccentForeground = Color("AccentForeground")

    static let themeSuccess = Color("Success")
    static let themeWarning = Color("Warning")
    static let themeDestructive = Color("Destructive")
}

extension Color {
    enum Theme {
        static let background = Color.themeBackground
        static let secondaryBackground = Color.themeSecondaryBackground
        static let tertiaryBackground = Color.themeTertiaryBackground
        static let groupedBackground = Color.themeGroupedBackground

        static let textPrimary = Color.themeTextPrimary
        static let textSecondary = Color.themeTextSecondary
        static let textTertiary = Color.themeTextTertiary

        static let separator = Color.themeSeparator
        static let border = Color.themeBorder
        static let elementBackground = Color.themeElementBackground
        static let elementBorder = Color.themeElementBorder

        static let accentForeground = Color.themeAccentForeground

        static let success = Color.themeSuccess
        static let warning = Color.themeWarning
        static let destructive = Color.themeDestructive
    }
}
