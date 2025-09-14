import SwiftUI

struct DesignSystem {

    struct Colors {
        // Primary Colors
        static let primary = Color("PrimaryColor")
        static let primaryVariant = Color("PrimaryVariantColor")
        static let secondary = Color("SecondaryColor")
        static let accent = Color("AccentColor")

        // Background Colors
        static let background = Color("BackgroundColor")
        static let surface = Color("SurfaceColor")
        static let surfaceVariant = Color("SurfaceVariantColor")

        // Text Colors
        static let onPrimary = Color("OnPrimaryColor")
        static let onSecondary = Color("OnSecondaryColor")
        static let onBackground = Color("OnBackgroundColor")
        static let onSurface = Color("OnSurfaceColor")

        // Utility Colors
        static let success = Color("SuccessColor")
        static let warning = Color("WarningColor")
        static let error = Color("ErrorColor")
        static let shadow = Color("ShadowColor")

        // Gradient Definitions
        static let primaryGradient = LinearGradient(
            colors: [primary, primaryVariant],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGradient = LinearGradient(
            colors: [accent, accent.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    struct Typography {
        // SF Pro Font Weights
        static let largeTitle = Font.custom("SF Pro Display", size: 34, relativeTo: .largeTitle).weight(.bold)
        static let title1 = Font.custom("SF Pro Display", size: 28, relativeTo: .title).weight(.bold)
        static let title2 = Font.custom("SF Pro Display", size: 22, relativeTo: .title2).weight(.semibold)
        static let title3 = Font.custom("SF Pro Display", size: 20, relativeTo: .title3).weight(.semibold)

        static let headline = Font.custom("SF Pro Text", size: 17, relativeTo: .headline).weight(.semibold)
        static let body = Font.custom("SF Pro Text", size: 17, relativeTo: .body).weight(.regular)
        static let bodyMedium = Font.custom("SF Pro Text", size: 17, relativeTo: .body).weight(.medium)
        static let callout = Font.custom("SF Pro Text", size: 16, relativeTo: .callout).weight(.regular)
        static let subheadline = Font.custom("SF Pro Text", size: 15, relativeTo: .subheadline).weight(.regular)
        static let footnote = Font.custom("SF Pro Text", size: 13, relativeTo: .footnote).weight(.regular)
        static let caption1 = Font.custom("SF Pro Text", size: 12, relativeTo: .caption).weight(.regular)
        static let caption2 = Font.custom("SF Pro Text", size: 11, relativeTo: .caption2).weight(.regular)
    }

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let circle: CGFloat = 50
    }

    struct Elevation {
        static let none: CGFloat = 0
        static let low: CGFloat = 2
        static let medium: CGFloat = 4
        static let high: CGFloat = 8
        static let veryHigh: CGFloat = 16
    }

    struct Animation {
        static let quick = Animation.easeInOut(duration: 0.2)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let gentle = Animation.easeInOut(duration: 0.5)
        static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - Custom Button Styles

struct PremiumButtonStyle: ButtonStyle {
    let variant: ButtonVariant

    init(_ variant: ButtonVariant = .primary) {
        self.variant = variant
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(variant.foregroundColor)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(variant.backgroundColor)
                    .shadow(
                        color: DesignSystem.Colors.shadow.opacity(0.2),
                        radius: configuration.isPressed ? 2 : 4,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

enum ButtonVariant {
    case primary, secondary, accent, ghost

    var backgroundColor: Color {
        switch self {
        case .primary: return DesignSystem.Colors.primary
        case .secondary: return DesignSystem.Colors.surface
        case .accent: return DesignSystem.Colors.accent
        case .ghost: return Color.clear
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary: return DesignSystem.Colors.onPrimary
        case .secondary: return DesignSystem.Colors.onSurface
        case .accent: return DesignSystem.Colors.onPrimary
        case .ghost: return DesignSystem.Colors.primary
        }
    }
}

// MARK: - Custom Card Style

struct PremiumCardStyle: ViewModifier {
    let elevation: CGFloat

    init(elevation: CGFloat = DesignSystem.Elevation.medium) {
        self.elevation = elevation
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .shadow(
                        color: DesignSystem.Colors.shadow.opacity(0.1),
                        radius: elevation,
                        y: elevation / 2
                    )
            )
    }
}

extension View {
    func premiumCard(elevation: CGFloat = DesignSystem.Elevation.medium) -> some View {
        modifier(PremiumCardStyle(elevation: elevation))
    }
}

// MARK: - Custom TextField Style

struct PremiumTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(DesignSystem.Typography.body)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(
                                isFocused ? DesignSystem.Colors.accent : DesignSystem.Colors.surfaceVariant,
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .focused($isFocused)
            .animation(DesignSystem.Animation.quick, value: isFocused)
    }
}