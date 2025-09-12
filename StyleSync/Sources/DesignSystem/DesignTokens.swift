import SwiftUI

// MARK: - Design Tokens Foundation
public struct DesignTokens {
    
    // MARK: - Spacing System
    public enum Spacing {
        public static let none: CGFloat = 0
        public static let xxxs: CGFloat = 2
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 40
        public static let xxxl: CGFloat = 48
        public static let huge: CGFloat = 64
        public static let massive: CGFloat = 96
    }
    
    // MARK: - Corner Radius System
    public enum CornerRadius {
        public static let none: CGFloat = 0
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
        public static let xxl: CGFloat = 24
        public static let full: CGFloat = 1000
    }
    
    // MARK: - Shadow System
    public enum Shadow {
        public static let none = ShadowToken(
            color: Color.clear,
            radius: 0,
            x: 0,
            y: 0,
            opacity: 0
        )
        
        public static let xs = ShadowToken(
            color: Color.black,
            radius: 2,
            x: 0,
            y: 1,
            opacity: 0.05
        )
        
        public static let sm = ShadowToken(
            color: Color.black,
            radius: 4,
            x: 0,
            y: 2,
            opacity: 0.1
        )
        
        public static let md = ShadowToken(
            color: Color.black,
            radius: 8,
            x: 0,
            y: 4,
            opacity: 0.15
        )
        
        public static let lg = ShadowToken(
            color: Color.black,
            radius: 16,
            x: 0,
            y: 8,
            opacity: 0.2
        )
        
        public static let xl = ShadowToken(
            color: Color.black,
            radius: 24,
            x: 0,
            y: 12,
            opacity: 0.25
        )
        
        public static let xxl = ShadowToken(
            color: Color.black,
            radius: 32,
            x: 0,
            y: 16,
            opacity: 0.3
        )
    }
    
    // MARK: - Animation Timing
    public enum AnimationDuration {
        public static let instant: Double = 0.1
        public static let quick: Double = 0.2
        public static let normal: Double = 0.3
        public static let slow: Double = 0.5
        public static let slower: Double = 0.8
        public static let slowest: Double = 1.2
    }
    
    // MARK: - Spring Animation Presets
    public enum SpringPreset {
        public static let bouncy = Animation.spring(
            response: 0.6,
            dampingFraction: 0.7,
            blendDuration: 0.3
        )
        
        public static let smooth = Animation.spring(
            response: 0.4,
            dampingFraction: 0.8,
            blendDuration: 0.2
        )
        
        public static let snappy = Animation.spring(
            response: 0.3,
            dampingFraction: 0.9,
            blendDuration: 0.1
        )
        
        public static let gentle = Animation.spring(
            response: 0.8,
            dampingFraction: 0.9,
            blendDuration: 0.4
        )
        
        public static let playful = Animation.spring(
            response: 0.5,
            dampingFraction: 0.6,
            blendDuration: 0.3
        )
    }
    
    // MARK: - Typography Scale
    public enum Typography {
        public static let display1 = TypographyToken(
            size: 48,
            weight: .black,
            lineHeight: 1.1,
            letterSpacing: -0.02
        )
        
        public static let display2 = TypographyToken(
            size: 40,
            weight: .heavy,
            lineHeight: 1.1,
            letterSpacing: -0.02
        )
        
        public static let heading1 = TypographyToken(
            size: 32,
            weight: .bold,
            lineHeight: 1.2,
            letterSpacing: -0.015
        )
        
        public static let heading2 = TypographyToken(
            size: 28,
            weight: .bold,
            lineHeight: 1.2,
            letterSpacing: -0.01
        )
        
        public static let heading3 = TypographyToken(
            size: 24,
            weight: .semibold,
            lineHeight: 1.3,
            letterSpacing: -0.01
        )
        
        public static let heading4 = TypographyToken(
            size: 20,
            weight: .semibold,
            lineHeight: 1.3,
            letterSpacing: -0.005
        )
        
        public static let body1 = TypographyToken(
            size: 16,
            weight: .regular,
            lineHeight: 1.5,
            letterSpacing: 0
        )
        
        public static let body2 = TypographyToken(
            size: 14,
            weight: .regular,
            lineHeight: 1.4,
            letterSpacing: 0
        )
        
        public static let caption1 = TypographyToken(
            size: 12,
            weight: .medium,
            lineHeight: 1.3,
            letterSpacing: 0.01
        )
        
        public static let caption2 = TypographyToken(
            size: 11,
            weight: .medium,
            lineHeight: 1.3,
            letterSpacing: 0.01
        )
        
        public static let overline = TypographyToken(
            size: 10,
            weight: .semibold,
            lineHeight: 1.2,
            letterSpacing: 0.05
        )
    }
    
    // MARK: - Opacity System
    public enum Opacity {
        public static let transparent: Double = 0.0
        public static let subtle: Double = 0.05
        public static let light: Double = 0.1
        public static let medium: Double = 0.2
        public static let strong: Double = 0.3
        public static let intense: Double = 0.5
        public static let heavy: Double = 0.7
        public static let opaque: Double = 1.0
    }
    
    // MARK: - Z-Index System
    public enum ZIndex {
        public static let background: Double = -10
        public static let base: Double = 0
        public static let raised: Double = 10
        public static let overlay: Double = 100
        public static let modal: Double = 1000
        public static let popover: Double = 1100
        public static let tooltip: Double = 1200
        public static let notification: Double = 1300
    }
}

// MARK: - Token Structures
public struct ShadowToken {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
    public let opacity: Double
    
    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
        self.opacity = opacity
    }
}

public struct TypographyToken {
    public let size: CGFloat
    public let weight: Font.Weight
    public let lineHeight: CGFloat
    public let letterSpacing: CGFloat
    
    public init(size: CGFloat, weight: Font.Weight, lineHeight: CGFloat, letterSpacing: CGFloat) {
        self.size = size
        self.weight = weight
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
    }
    
    public var font: Font {
        return Font.system(size: size, weight: weight)
    }
}

// MARK: - View Extensions for Design Tokens
extension View {
    public func applyShadow(_ shadow: ShadowToken) -> some View {
        self.shadow(
            color: shadow.color.opacity(shadow.opacity),
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    public func applyTypography(_ typography: TypographyToken) -> some View {
        self
            .font(typography.font)
            .lineSpacing(typography.size * typography.lineHeight - typography.size)
            .kerning(typography.letterSpacing * typography.size)
    }
}