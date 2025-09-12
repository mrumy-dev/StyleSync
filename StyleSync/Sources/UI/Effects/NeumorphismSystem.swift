import SwiftUI

// MARK: - Neumorphism Effect System
public struct NeumorphismModifier: ViewModifier {
    let style: NeumorphismStyle
    let intensity: NeumorphismIntensity
    let cornerRadius: CGFloat
    let isPressed: Bool
    
    public init(
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        isPressed: Bool = false
    ) {
        self.style = style
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.isPressed = isPressed
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                NeumorphismBackground(
                    style: isPressed ? style.pressed : style,
                    intensity: intensity,
                    cornerRadius: cornerRadius
                )
            )
    }
}

public enum NeumorphismStyle {
    case raised
    case inset
    case flat
    case convex
    case concave
    case floating
    
    var pressed: NeumorphismStyle {
        switch self {
        case .raised: return .inset
        case .inset: return .raised
        case .flat: return .inset
        case .convex: return .concave
        case .concave: return .convex
        case .floating: return .inset
        }
    }
    
    func shadowConfiguration(for intensity: NeumorphismIntensity) -> (light: ShadowConfig, dark: ShadowConfig) {
        let baseRadius = intensity.shadowRadius
        let baseOffset = intensity.shadowOffset
        let opacity = intensity.shadowOpacity
        
        switch self {
        case .raised:
            return (
                light: ShadowConfig(
                    color: Color.white,
                    radius: baseRadius,
                    offset: CGSize(width: -baseOffset, height: -baseOffset),
                    opacity: opacity
                ),
                dark: ShadowConfig(
                    color: Color.black,
                    radius: baseRadius,
                    offset: CGSize(width: baseOffset, height: baseOffset),
                    opacity: opacity * 0.3
                )
            )
            
        case .inset:
            return (
                light: ShadowConfig(
                    color: Color.black,
                    radius: baseRadius * 0.8,
                    offset: CGSize(width: baseOffset * 0.5, height: baseOffset * 0.5),
                    opacity: opacity * 0.4,
                    inner: true
                ),
                dark: ShadowConfig(
                    color: Color.white,
                    radius: baseRadius * 0.6,
                    offset: CGSize(width: -baseOffset * 0.3, height: -baseOffset * 0.3),
                    opacity: opacity * 0.8,
                    inner: true
                )
            )
            
        case .flat:
            return (
                light: ShadowConfig(
                    color: Color.white,
                    radius: baseRadius * 0.5,
                    offset: CGSize(width: -baseOffset * 0.5, height: -baseOffset * 0.5),
                    opacity: opacity * 0.6
                ),
                dark: ShadowConfig(
                    color: Color.black,
                    radius: baseRadius * 0.5,
                    offset: CGSize(width: baseOffset * 0.5, height: baseOffset * 0.5),
                    opacity: opacity * 0.2
                )
            )
            
        case .convex:
            return (
                light: ShadowConfig(
                    color: Color.white,
                    radius: baseRadius * 1.2,
                    offset: CGSize(width: -baseOffset * 1.5, height: -baseOffset * 1.5),
                    opacity: opacity * 1.2
                ),
                dark: ShadowConfig(
                    color: Color.black,
                    radius: baseRadius * 1.2,
                    offset: CGSize(width: baseOffset * 1.5, height: baseOffset * 1.5),
                    opacity: opacity * 0.4
                )
            )
            
        case .concave:
            return (
                light: ShadowConfig(
                    color: Color.black,
                    radius: baseRadius,
                    offset: CGSize(width: baseOffset, height: baseOffset),
                    opacity: opacity * 0.5,
                    inner: true
                ),
                dark: ShadowConfig(
                    color: Color.white,
                    radius: baseRadius * 0.8,
                    offset: CGSize(width: -baseOffset * 0.8, height: -baseOffset * 0.8),
                    opacity: opacity,
                    inner: true
                )
            )
            
        case .floating:
            return (
                light: ShadowConfig(
                    color: Color.white,
                    radius: baseRadius * 0.8,
                    offset: CGSize(width: -baseOffset * 0.5, height: -baseOffset * 2),
                    opacity: opacity
                ),
                dark: ShadowConfig(
                    color: Color.black,
                    radius: baseRadius * 2,
                    offset: CGSize(width: 0, height: baseOffset * 3),
                    opacity: opacity * 0.3
                )
            )
        }
    }
}

public enum NeumorphismIntensity {
    case subtle, light, medium, strong, dramatic
    
    var shadowRadius: CGFloat {
        switch self {
        case .subtle: return 4
        case .light: return 8
        case .medium: return 16
        case .strong: return 24
        case .dramatic: return 32
        }
    }
    
    var shadowOffset: CGFloat {
        switch self {
        case .subtle: return 2
        case .light: return 4
        case .medium: return 8
        case .strong: return 12
        case .dramatic: return 16
        }
    }
    
    var shadowOpacity: Double {
        switch self {
        case .subtle: return 0.1
        case .light: return 0.2
        case .medium: return 0.3
        case .strong: return 0.4
        case .dramatic: return 0.5
        }
    }
}

struct ShadowConfig {
    let color: Color
    let radius: CGFloat
    let offset: CGSize
    let opacity: Double
    let inner: Bool
    
    init(color: Color, radius: CGFloat, offset: CGSize, opacity: Double, inner: Bool = false) {
        self.color = color
        self.radius = radius
        self.offset = offset
        self.opacity = opacity
        self.inner = inner
    }
}

struct NeumorphismBackground: View {
    let style: NeumorphismStyle
    let intensity: NeumorphismIntensity
    let cornerRadius: CGFloat
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        let shadows = style.shadowConfiguration(for: intensity)
        
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(theme.colors.surface)
            .shadow(
                color: shadows.light.color.opacity(shadows.light.opacity),
                radius: shadows.light.radius,
                x: shadows.light.offset.width,
                y: shadows.light.offset.height
            )
            .shadow(
                color: shadows.dark.color.opacity(shadows.dark.opacity),
                radius: shadows.dark.radius,
                x: shadows.dark.offset.width,
                y: shadows.dark.offset.height
            )
            .overlay(
                // Inner shadows simulation
                Group {
                    if shadows.light.inner {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        shadows.light.color.opacity(shadows.light.opacity),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blur(radius: shadows.light.radius / 4)
                    }
                    
                    if shadows.dark.inner {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        shadows.dark.color.opacity(shadows.dark.opacity)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .blur(radius: shadows.dark.radius / 4)
                    }
                }
            )
    }
}

// MARK: - Advanced Neumorphism Variants
public struct DynamicNeumorphismModifier: ViewModifier {
    @State private var isPressed = false
    @State private var pressIntensity: Double = 0
    
    let style: NeumorphismStyle
    let intensity: NeumorphismIntensity
    let cornerRadius: CGFloat
    let animationDuration: Double
    
    public init(
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        animationDuration: Double = 0.2
    ) {
        self.style = style
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.animationDuration = animationDuration
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                NeumorphismBackground(
                    style: style,
                    intensity: intensity,
                    cornerRadius: cornerRadius
                )
                .scaleEffect(1 - pressIntensity * 0.02)
                .animation(.spring(response: animationDuration, dampingFraction: 0.7), value: pressIntensity)
            )
            .scaleEffect(1 - pressIntensity * 0.01)
            .onLongPressGesture(minimumDuration: 0) { pressing in
                withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                    isPressed = pressing
                    pressIntensity = pressing ? 1.0 : 0.0
                }
            }
    }
}

// MARK: - Morphing Neumorphism
public struct MorphingNeumorphismModifier: ViewModifier {
    @State private var morphPhase: Double = 0
    let styles: [NeumorphismStyle]
    let intensity: NeumorphismIntensity
    let cornerRadius: CGFloat
    let morphDuration: Double
    
    public init(
        styles: [NeumorphismStyle] = [.raised, .flat, .inset, .convex],
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        morphDuration: Double = 3.0
    ) {
        self.styles = styles
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.morphDuration = morphDuration
    }
    
    public func body(content: Content) -> some View {
        let currentStyleIndex = Int(morphPhase) % styles.count
        let currentStyle = styles[currentStyleIndex]
        
        content
            .background(
                NeumorphismBackground(
                    style: currentStyle,
                    intensity: intensity,
                    cornerRadius: cornerRadius
                )
            )
            .onAppear {
                withAnimation(.linear(duration: morphDuration * Double(styles.count)).repeatForever(autoreverses: false)) {
                    morphPhase = Double(styles.count)
                }
            }
    }
}

// MARK: - Breathing Neumorphism
public struct BreathingNeumorphismModifier: ViewModifier {
    @State private var breathPhase: Double = 0
    let style: NeumorphismStyle
    let baseIntensity: NeumorphismIntensity
    let cornerRadius: CGFloat
    let breathRate: Double
    
    public init(
        style: NeumorphismStyle = .raised,
        baseIntensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        breathRate: Double = 3.0
    ) {
        self.style = style
        self.baseIntensity = baseIntensity
        self.cornerRadius = cornerRadius
        self.breathRate = breathRate
    }
    
    public func body(content: Content) -> some View {
        let intensityMultiplier = 1.0 + 0.3 * sin(breathPhase)
        let dynamicRadius = cornerRadius + 2 * sin(breathPhase)
        
        content
            .background(
                NeumorphismBackground(
                    style: style,
                    intensity: adjustedIntensity(baseIntensity, multiplier: intensityMultiplier),
                    cornerRadius: dynamicRadius
                )
            )
            .onAppear {
                withAnimation(.linear(duration: breathRate).repeatForever(autoreverses: false)) {
                    breathPhase = 2 * .pi
                }
            }
    }
    
    private func adjustedIntensity(_ base: NeumorphismIntensity, multiplier: Double) -> NeumorphismIntensity {
        if multiplier > 1.2 { return .strong }
        if multiplier < 0.8 { return .light }
        return base
    }
}

// MARK: - Liquid Neumorphism
public struct LiquidNeumorphismModifier: ViewModifier {
    @State private var liquidPhase: Double = 0
    let viscosity: LiquidViscosity
    let style: NeumorphismStyle
    let intensity: NeumorphismIntensity
    let baseRadius: CGFloat
    
    public init(
        viscosity: LiquidViscosity = .medium,
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        baseRadius: CGFloat = 16
    ) {
        self.viscosity = viscosity
        self.style = style
        self.intensity = intensity
        self.baseRadius = baseRadius
    }
    
    public func body(content: Content) -> some View {
        let flowMultiplier = viscosity.flowMultiplier
        let radiusVariation = baseRadius + 4 * sin(liquidPhase * flowMultiplier)
        
        content
            .background(
                NeumorphismBackground(
                    style: style,
                    intensity: intensity,
                    cornerRadius: radiusVariation
                )
                .clipShape(
                    LiquidShape(phase: liquidPhase, viscosity: viscosity)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 4.0 / flowMultiplier).repeatForever(autoreverses: false)) {
                    liquidPhase = 2 * .pi
                }
            }
    }
}

struct LiquidShape: Shape {
    let phase: Double
    let viscosity: LiquidViscosity
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waves = 3
        let amplitude = rect.width * 0.05 / viscosity.flowMultiplier
        
        path.move(to: CGPoint(x: 0, y: 0))
        
        for i in 0...Int(rect.width) {
            let x = CGFloat(i)
            let y = amplitude * sin((Double(i) / rect.width) * Double(waves) * 2 * .pi + phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Interactive Neumorphism
public struct InteractiveNeumorphismModifier: ViewModifier {
    @State private var dragOffset = CGSize.zero
    @State private var isPressed = false
    
    let style: NeumorphismStyle
    let intensity: NeumorphismIntensity
    let cornerRadius: CGFloat
    let sensitivity: Double
    
    public init(
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        sensitivity: Double = 1.0
    ) {
        self.style = style
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.sensitivity = sensitivity
    }
    
    public func body(content: Content) -> some View {
        let dynamicStyle = calculateDynamicStyle(from: dragOffset)
        
        content
            .background(
                NeumorphismBackground(
                    style: isPressed ? style.pressed : dynamicStyle,
                    intensity: intensity,
                    cornerRadius: cornerRadius
                )
            )
            .offset(dragOffset)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = CGSize(
                            width: value.translation.x * sensitivity,
                            height: value.translation.y * sensitivity
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            dragOffset = .zero
                        }
                    }
            )
            .onLongPressGesture(minimumDuration: 0) { pressing in
                isPressed = pressing
            }
    }
    
    private func calculateDynamicStyle(from offset: CGSize) -> NeumorphismStyle {
        let distance = sqrt(offset.width * offset.width + offset.height * offset.height)
        
        if distance > 20 {
            return offset.height > 0 ? .convex : .concave
        } else if distance > 10 {
            return .flat
        }
        
        return style
    }
}

// MARK: - View Extensions
public extension View {
    func neumorphism(
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        isPressed: Bool = false
    ) -> some View {
        modifier(NeumorphismModifier(
            style: style,
            intensity: intensity,
            cornerRadius: cornerRadius,
            isPressed: isPressed
        ))
    }
    
    func dynamicNeumorphism(
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        animationDuration: Double = 0.2
    ) -> some View {
        modifier(DynamicNeumorphismModifier(
            style: style,
            intensity: intensity,
            cornerRadius: cornerRadius,
            animationDuration: animationDuration
        ))
    }
    
    func morphingNeumorphism(
        styles: [NeumorphismStyle] = [.raised, .flat, .inset, .convex],
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        morphDuration: Double = 3.0
    ) -> some View {
        modifier(MorphingNeumorphismModifier(
            styles: styles,
            intensity: intensity,
            cornerRadius: cornerRadius,
            morphDuration: morphDuration
        ))
    }
    
    func breathingNeumorphism(
        style: NeumorphismStyle = .raised,
        baseIntensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        breathRate: Double = 3.0
    ) -> some View {
        modifier(BreathingNeumorphismModifier(
            style: style,
            baseIntensity: baseIntensity,
            cornerRadius: cornerRadius,
            breathRate: breathRate
        ))
    }
    
    func liquidNeumorphism(
        viscosity: LiquidViscosity = .medium,
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        baseRadius: CGFloat = 16
    ) -> some View {
        modifier(LiquidNeumorphismModifier(
            viscosity: viscosity,
            style: style,
            intensity: intensity,
            baseRadius: baseRadius
        ))
    }
    
    func interactiveNeumorphism(
        style: NeumorphismStyle = .raised,
        intensity: NeumorphismIntensity = .medium,
        cornerRadius: CGFloat = 16,
        sensitivity: Double = 1.0
    ) -> some View {
        modifier(InteractiveNeumorphismModifier(
            style: style,
            intensity: intensity,
            cornerRadius: cornerRadius,
            sensitivity: sensitivity
        ))
    }
}