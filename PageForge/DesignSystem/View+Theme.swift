import SwiftUI

private struct AppLargeTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Baskerville", size: 34, relativeTo: .largeTitle))
            .fontWeight(.bold)
            .foregroundStyle(Color.Theme.textPrimary)
    }
}

extension View {
    func appLargeTitleStyle() -> some View {
        modifier(AppLargeTitleModifier())
    }

    func cardStyle(cornerRadius: CGFloat = 24) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.Theme.tertiaryBackground)
                .shadow(color: .black.opacity(0.06), radius: 24, x: 3, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.Theme.border, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    func themedScreenBackground() -> some View {
        background(Color.Theme.secondaryBackground.ignoresSafeArea())
    }
}
