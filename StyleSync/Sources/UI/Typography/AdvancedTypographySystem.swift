import SwiftUI
import CoreText

// MARK: - Advanced Typography System
public class TypographyManager: ObservableObject {
    @Published public var currentFontTheme: FontTheme = .system
    @Published public var dynamicTypeEnabled: Bool = true
    @Published public var lineHeightMultiplier: CGFloat = 1.0
    @Published public var letterSpacingOffset: CGFloat = 0.0
    @Published public var customFonts: [String: Font] = [:]
    
    private var registeredFontFamilies: Set<String> = []
    
    public init() {
        registerCustomFonts()
    }
    
    private func registerCustomFonts() {
        // Register SF Pro variants
        registerFontFamily("SF Pro Display")
        registerFontFamily("SF Pro Text")
        registerFontFamily("SF Pro Rounded")
        
        // Register other system fonts
        registerFontFamily("New York")
        registerFontFamily("Helvetica Neue")
        registerFontFamily("Avenir Next")
    }
    
    private func registerFontFamily(_ familyName: String) {
        registeredFontFamilies.insert(familyName)
    }
    
    public func setFontTheme(_ theme: FontTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentFontTheme = theme
        }
    }
}

// MARK: - Font Themes
public enum FontTheme: String, CaseIterable {
    case system = "system"
    case modern = "modern"
    case elegant = "elegant"
    case playful = "playful"
    case technical = "technical"
    case editorial = "editorial"
    
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .modern: return "Modern"
        case .elegant: return "Elegant"
        case .playful: return "Playful"
        case .technical: return "Technical"
        case .editorial: return "Editorial"
        }
    }
    
    public func font(for style: TypographyStyle, size: CGFloat) -> Font {
        switch self {
        case .system:
            return systemFont(for: style, size: size)
        case .modern:
            return modernFont(for: style, size: size)
        case .elegant:
            return elegantFont(for: style, size: size)
        case .playful:
            return playfulFont(for: style, size: size)
        case .technical:
            return technicalFont(for: style, size: size)
        case .editorial:
            return editorialFont(for: style, size: size)
        }
    }
    
    private func systemFont(for style: TypographyStyle, size: CGFloat) -> Font {
        switch style {
        case .display1, .display2, .heading1, .heading2:
            return .custom("SF Pro Display", size: size)
        case .body1, .body2, .caption1, .caption2:
            return .custom("SF Pro Text", size: size)
        default:
            return .system(size: size, weight: style.weight, design: .default)
        }
    }
    
    private func modernFont(for style: TypographyStyle, size: CGFloat) -> Font {
        switch style {
        case .display1, .display2:
            return .custom("Helvetica Neue", size: size)
        case .heading1, .heading2, .heading3:
            return .custom("Avenir Next", size: size)
        default:
            return .custom("SF Pro Text", size: size)
        }
    }
    
    private func elegantFont(for style: TypographyStyle, size: CGFloat) -> Font {
        switch style {
        case .display1, .display2, .heading1:
            return .custom("New York", size: size)
        default:
            return .custom("SF Pro Text", size: size)
        }
    }
    
    private func playfulFont(for style: TypographyStyle, size: CGFloat) -> Font {
        return .custom("SF Pro Rounded", size: size)
    }
    
    private func technicalFont(for style: TypographyStyle, size: CGFloat) -> Font {
        return Font.system(size: size, weight: style.weight, design: .monospaced)
    }
    
    private func editorialFont(for style: TypographyStyle, size: CGFloat) -> Font {
        switch style {
        case .display1, .display2, .heading1, .heading2:
            return .custom("New York", size: size)
        default:
            return .custom("SF Pro Text", size: size)
        }
    }
}

// MARK: - Typography Styles
public enum TypographyStyle: String, CaseIterable {
    case display1, display2
    case heading1, heading2, heading3, heading4
    case subheading1, subheading2
    case body1, body2
    case caption1, caption2
    case overline, button
    case code, monospace
    
    public var size: CGFloat {
        switch self {
        case .display1: return 57
        case .display2: return 45
        case .heading1: return 36
        case .heading2: return 32
        case .heading3: return 28
        case .heading4: return 24
        case .subheading1: return 20
        case .subheading2: return 18
        case .body1: return 16
        case .body2: return 14
        case .caption1: return 12
        case .caption2: return 11
        case .overline: return 10
        case .button: return 14
        case .code, .monospace: return 14
        }
    }
    
    public var weight: Font.Weight {
        switch self {
        case .display1, .display2: return .black
        case .heading1, .heading2: return .bold
        case .heading3, .heading4: return .semibold
        case .subheading1, .subheading2: return .medium
        case .body1: return .regular
        case .body2: return .regular
        case .caption1, .caption2: return .medium
        case .overline: return .semibold
        case .button: return .semibold
        case .code, .monospace: return .regular
        }
    }
    
    public var lineHeight: CGFloat {
        switch self {
        case .display1, .display2: return 1.12
        case .heading1, .heading2, .heading3: return 1.2
        case .heading4: return 1.25
        case .subheading1, .subheading2: return 1.3
        case .body1: return 1.5
        case .body2: return 1.43
        case .caption1, .caption2: return 1.33
        case .overline: return 1.2
        case .button: return 1.0
        case .code, .monospace: return 1.4
        }
    }
    
    public var letterSpacing: CGFloat {
        switch self {
        case .display1, .display2: return -0.25
        case .heading1: return -0.15
        case .heading2: return -0.1
        case .heading3, .heading4: return -0.05
        case .subheading1, .subheading2: return 0
        case .body1, .body2: return 0
        case .caption1, .caption2: return 0.4
        case .overline: return 1.5
        case .button: return 0.1
        case .code, .monospace: return 0
        }
    }
}

// MARK: - Animated Text Effects
public struct AnimatedTextModifier: ViewModifier {
    let effect: TextAnimationEffect
    let isActive: Bool
    @State private var animationValue: Double = 0
    
    public init(effect: TextAnimationEffect, isActive: Bool = true) {
        self.effect = effect
        self.isActive = isActive
    }
    
    public func body(content: Content) -> some View {
        content
            .modifier(effect.createModifier(animationValue: animationValue, isActive: isActive))
            .onAppear {
                if isActive {
                    startAnimation()
                }
            }
    }
    
    private func startAnimation() {
        withAnimation(effect.animation.repeatForever(autoreverses: effect.autoreverses)) {
            animationValue = 1.0
        }
    }
}

public enum TextAnimationEffect {
    case typewriter(speed: Double)
    case fade(duration: Double)
    case slide(direction: SlideDirection, duration: Double)
    case bounce(intensity: Double)
    case glow(color: Color, intensity: Double)
    case rainbow(speed: Double)
    case shake(intensity: Double)
    case wave(frequency: Double)
    case matrix(speed: Double)
    case gradient(colors: [Color], speed: Double)
    
    public enum SlideDirection {
        case left, right, up, down
    }
    
    public var animation: Animation {
        switch self {
        case .typewriter(let speed):
            return .linear(duration: 1.0 / speed)
        case .fade(let duration):
            return .easeInOut(duration: duration)
        case .slide(_, let duration):
            return .spring(response: duration, dampingFraction: 0.8)
        case .bounce:
            return .interpolatingSpring(stiffness: 200, damping: 10)
        case .glow:
            return .easeInOut(duration: 2.0)
        case .rainbow(let speed):
            return .linear(duration: 1.0 / speed)
        case .shake:
            return .easeInOut(duration: 0.1)
        case .wave(let frequency):
            return .linear(duration: 1.0 / frequency)
        case .matrix(let speed):
            return .linear(duration: 1.0 / speed)
        case .gradient(_, let speed):
            return .linear(duration: 1.0 / speed)
        }
    }
    
    public var autoreverses: Bool {
        switch self {
        case .typewriter, .fade, .slide, .matrix: return false
        case .bounce, .glow, .rainbow, .shake, .wave, .gradient: return true
        }
    }
    
    public func createModifier(animationValue: Double, isActive: Bool) -> some ViewModifier {
        switch self {
        case .glow(let color, let intensity):
            return AnyViewModifier(
                GlowTextModifier(
                    color: color,
                    intensity: intensity * animationValue,
                    isActive: isActive
                )
            )
        case .shake(let intensity):
            return AnyViewModifier(
                ShakeTextModifier(
                    intensity: intensity,
                    phase: animationValue,
                    isActive: isActive
                )
            )
        case .rainbow:
            return AnyViewModifier(
                RainbowTextModifier(
                    phase: animationValue,
                    isActive: isActive
                )
            )
        default:
            return AnyViewModifier(EmptyModifier())
        }
    }
}

// MARK: - Text Effect Modifiers
struct GlowTextModifier: ViewModifier {
    let color: Color
    let intensity: Double
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .shadow(color: color.opacity(0.3), radius: 2 * intensity, x: 0, y: 0)
                .shadow(color: color.opacity(0.2), radius: 4 * intensity, x: 0, y: 0)
                .shadow(color: color.opacity(0.1), radius: 8 * intensity, x: 0, y: 0)
        } else {
            content
        }
    }
}

struct ShakeTextModifier: ViewModifier {
    let intensity: Double
    let phase: Double
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .offset(x: sin(phase * 50) * intensity * 2)
        } else {
            content
        }
    }
}

struct RainbowTextModifier: ViewModifier {
    let phase: Double
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .red, .orange, .yellow, .green, .blue, .purple, .red
                        ].map { $0.opacity(0.8) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .hueRotation(.degrees(phase * 360))
        } else {
            content
        }
    }
}

// MARK: - Gradient Text Support
public struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    let style: TypographyStyle
    let fontTheme: FontTheme
    
    public init(
        _ text: String,
        gradient: LinearGradient,
        style: TypographyStyle = .body1,
        fontTheme: FontTheme = .system
    ) {
        self.text = text
        self.gradient = gradient
        self.style = style
        self.fontTheme = fontTheme
    }
    
    public var body: some View {
        Text(text)
            .font(fontTheme.font(for: style, size: style.size))
            .foregroundStyle(gradient)
    }
}

// MARK: - Variable Font Support
public struct VariableFontText: View {
    let text: String
    let fontWeight: CGFloat // 100-900
    let fontWidth: CGFloat // 50-200 (percentage)
    let style: TypographyStyle
    @State private var animatedWeight: CGFloat
    @State private var animatedWidth: CGFloat
    
    public init(
        _ text: String,
        weight: CGFloat = 400,
        width: CGFloat = 100,
        style: TypographyStyle = .body1
    ) {
        self.text = text
        self.fontWeight = weight
        self.fontWidth = width
        self.style = style
        self._animatedWeight = State(initialValue: weight)
        self._animatedWidth = State(initialValue: width)
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: style.size, weight: Font.Weight(rawValue: animatedWeight / 100)))
            .scaleEffect(x: animatedWidth / 100, y: 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    animatedWeight = fontWeight * 1.2
                    animatedWidth = fontWidth * 1.1
                }
            }
    }
}

// MARK: - Dynamic Type Support
public struct DynamicTypeText: View {
    let text: String
    let style: TypographyStyle
    let fontTheme: FontTheme
    let maxSize: CGFloat?
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var typographyManager: TypographyManager
    
    public init(
        _ text: String,
        style: TypographyStyle = .body1,
        fontTheme: FontTheme? = nil,
        maxSize: CGFloat? = nil
    ) {
        self.text = text
        self.style = style
        self.fontTheme = fontTheme ?? .system
        self.maxSize = maxSize
    }
    
    public var body: some View {
        let baseSize = style.size
        let scaledSize = min(
            baseSize * dynamicTypeMultiplier,
            maxSize ?? baseSize * 2
        )
        
        Text(text)
            .font(fontTheme.font(for: style, size: scaledSize))
            .lineSpacing(scaledSize * style.lineHeight - scaledSize)
            .kerning(style.letterSpacing + typographyManager.letterSpacingOffset)
    }
    
    private var dynamicTypeMultiplier: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 0.85
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        case .accessibility1: return 1.5
        case .accessibility2: return 1.6
        case .accessibility3: return 1.8
        case .accessibility4: return 2.0
        case .accessibility5: return 2.2
        @unknown default: return 1.0
        }
    }
}

// MARK: - Responsive Typography
public struct ResponsiveText: View {
    let text: String
    let style: TypographyStyle
    let breakpoints: [CGFloat: TypographyStyle]
    
    public init(
        _ text: String,
        style: TypographyStyle = .body1,
        breakpoints: [CGFloat: TypographyStyle] = [:]
    ) {
        self.text = text
        self.style = style
        self.breakpoints = breakpoints
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let responsiveStyle = getResponsiveStyle(for: width)
            
            Text(text)
                .font(.system(size: responsiveStyle.size, weight: responsiveStyle.weight))
                .lineSpacing(responsiveStyle.size * responsiveStyle.lineHeight - responsiveStyle.size)
                .kerning(responsiveStyle.letterSpacing)
        }
    }
    
    private func getResponsiveStyle(for width: CGFloat) -> TypographyStyle {
        let sortedBreakpoints = breakpoints.keys.sorted(by: >)
        
        for breakpoint in sortedBreakpoints {
            if width >= breakpoint {
                return breakpoints[breakpoint] ?? style
            }
        }
        
        return style
    }
}

// MARK: - Text Measurement Utilities
public extension Text {
    func measure(with style: TypographyStyle, maxWidth: CGFloat = .infinity) -> CGSize {
        let font = UIFont.systemFont(ofSize: style.size, weight: UIFont.Weight(style.weight.rawValue))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let string = NSAttributedString(string: "Sample Text", attributes: attributes)
        
        let boundingRect = string.boundingRect(
            with: CGSize(width: maxWidth, height: .infinity),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return boundingRect.size
    }
}

// MARK: - Helper Types
struct AnyViewModifier: ViewModifier {
    private let _body: (Content) -> AnyView
    
    init<M: ViewModifier>(_ modifier: M) {
        _body = { content in
            AnyView(content.modifier(modifier))
        }
    }
    
    func body(content: Content) -> some View {
        _body(content)
    }
}

struct EmptyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

// MARK: - View Extensions
public extension View {
    func typography(
        _ style: TypographyStyle,
        theme: FontTheme = .system
    ) -> some View {
        self
            .font(theme.font(for: style, size: style.size))
            .lineSpacing(style.size * style.lineHeight - style.size)
            .kerning(style.letterSpacing)
    }
    
    func animatedText(
        _ effect: TextAnimationEffect,
        isActive: Bool = true
    ) -> some View {
        modifier(AnimatedTextModifier(effect: effect, isActive: isActive))
    }
    
    func responsiveTypography(
        baseStyle: TypographyStyle,
        breakpoints: [CGFloat: TypographyStyle] = [:]
    ) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let responsiveStyle = getResponsiveStyle(
                for: width,
                baseStyle: baseStyle,
                breakpoints: breakpoints
            )
            
            self
                .font(.system(size: responsiveStyle.size, weight: responsiveStyle.weight))
                .lineSpacing(responsiveStyle.size * responsiveStyle.lineHeight - responsiveStyle.size)
                .kerning(responsiveStyle.letterSpacing)
        }
    }
    
    private func getResponsiveStyle(
        for width: CGFloat,
        baseStyle: TypographyStyle,
        breakpoints: [CGFloat: TypographyStyle]
    ) -> TypographyStyle {
        let sortedBreakpoints = breakpoints.keys.sorted(by: >)
        
        for breakpoint in sortedBreakpoints {
            if width >= breakpoint {
                return breakpoints[breakpoint] ?? baseStyle
            }
        }
        
        return baseStyle
    }
}

// MARK: - Environment Key
private struct TypographyEnvironmentKey: EnvironmentKey {
    static let defaultValue = TypographyManager()
}

extension EnvironmentValues {
    public var typographyManager: TypographyManager {
        get { self[TypographyEnvironmentKey.self] }
        set { self[TypographyEnvironmentKey.self] = newValue }
    }
}