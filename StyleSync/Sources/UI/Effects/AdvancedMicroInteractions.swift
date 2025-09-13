import SwiftUI
import Combine

// MARK: - Advanced Micro Interactions System
public class AdvancedMicroInteractionEngine: ObservableObject {
    @Published public var activeEffects: Set<String> = []

    private var effectTimers: [String: Timer] = [:]
    private var particleSystem = ParticleSystem()
    private let hapticEngine = HapticFeedbackSystem.shared

    public static let shared = AdvancedMicroInteractionEngine()

    private init() {}

    public func triggerEffect(_ effect: MicroEffect, at position: CGPoint? = nil) {
        let id = effect.id
        activeEffects.insert(id)

        // Trigger haptic feedback
        hapticEngine.impact(effect.hapticStyle)

        // Particle burst if needed
        if let position = position, let burst = effect.particleBurst {
            particleSystem.burst(at: position, with: burst)
        }

        // Auto-cleanup
        effectTimers[id]?.invalidate()
        effectTimers[id] = Timer.scheduledTimer(withTimeInterval: effect.duration, repeats: false) { [weak self] _ in
            self?.activeEffects.remove(id)
            self?.effectTimers.removeValue(forKey: id)
        }
    }

    public func isActive(_ effect: MicroEffect) -> Bool {
        activeEffects.contains(effect.id)
    }

    public func stopEffect(_ effect: MicroEffect) {
        activeEffects.remove(effect.id)
        effectTimers[effect.id]?.invalidate()
        effectTimers.removeValue(forKey: effect.id)
    }
}

// MARK: - Micro Effect Types
public enum MicroEffect: CaseIterable {
    // Button Effects
    case buttonPress
    case buttonHover
    case buttonRipple
    case buttonGlow
    case buttonPulse
    case buttonMagnetic
    case buttonElastic
    case buttonLiquid

    // Toggle Effects
    case toggleSlide
    case toggleBounce
    case toggleMorphPhysics
    case toggleElastic
    case toggleMagnetic
    case toggleGlitch

    // Slider Effects
    case sliderTrail
    case sliderMagnetic
    case sliderElastic
    case sliderWave
    case sliderParticles

    // Card Effects
    case cardHoverFloat
    case cardTiltPerspective
    case cardMagneticEdge
    case cardFlipReveal
    case cardLiquidMorph
    case cardGlowBorder
    case cardParallaxDepth
    case cardPhysicsBounce

    // Gesture Effects
    case gestureTrail
    case gestureMagnetic
    case gestureElastic
    case gestureRippleSpread
    case gestureParticleFollow

    public var id: String {
        switch self {
        case .buttonPress: return "buttonPress"
        case .buttonHover: return "buttonHover"
        case .buttonRipple: return "buttonRipple"
        case .buttonGlow: return "buttonGlow"
        case .buttonPulse: return "buttonPulse"
        case .buttonMagnetic: return "buttonMagnetic"
        case .buttonElastic: return "buttonElastic"
        case .buttonLiquid: return "buttonLiquid"
        case .toggleSlide: return "toggleSlide"
        case .toggleBounce: return "toggleBounce"
        case .toggleMorphPhysics: return "toggleMorphPhysics"
        case .toggleElastic: return "toggleElastic"
        case .toggleMagnetic: return "toggleMagnetic"
        case .toggleGlitch: return "toggleGlitch"
        case .sliderTrail: return "sliderTrail"
        case .sliderMagnetic: return "sliderMagnetic"
        case .sliderElastic: return "sliderElastic"
        case .sliderWave: return "sliderWave"
        case .sliderParticles: return "sliderParticles"
        case .cardHoverFloat: return "cardHoverFloat"
        case .cardTiltPerspective: return "cardTiltPerspective"
        case .cardMagneticEdge: return "cardMagneticEdge"
        case .cardFlipReveal: return "cardFlipReveal"
        case .cardLiquidMorph: return "cardLiquidMorph"
        case .cardGlowBorder: return "cardGlowBorder"
        case .cardParallaxDepth: return "cardParallaxDepth"
        case .cardPhysicsBounce: return "cardPhysicsBounce"
        case .gestureTrail: return "gestureTrail"
        case .gestureMagnetic: return "gestureMagnetic"
        case .gestureElastic: return "gestureElastic"
        case .gestureRippleSpread: return "gestureRippleSpread"
        case .gestureParticleFollow: return "gestureParticleFollow"
        }
    }

    public var duration: Double {
        switch self {
        case .buttonPress: return 0.3
        case .buttonHover: return 0.4
        case .buttonRipple: return 0.8
        case .buttonGlow: return 1.2
        case .buttonPulse: return 1.0
        case .buttonMagnetic: return 0.5
        case .buttonElastic: return 0.6
        case .buttonLiquid: return 1.0
        case .toggleSlide: return 0.4
        case .toggleBounce: return 0.6
        case .toggleMorphPhysics: return 0.8
        case .toggleElastic: return 0.5
        case .toggleMagnetic: return 0.4
        case .toggleGlitch: return 0.3
        case .sliderTrail: return 0.5
        case .sliderMagnetic: return 0.4
        case .sliderElastic: return 0.6
        case .sliderWave: return 0.8
        case .sliderParticles: return 1.0
        case .cardHoverFloat: return 2.0
        case .cardTiltPerspective: return 0.5
        case .cardMagneticEdge: return 0.6
        case .cardFlipReveal: return 1.2
        case .cardLiquidMorph: return 1.5
        case .cardGlowBorder: return 1.0
        case .cardParallaxDepth: return 0.8
        case .cardPhysicsBounce: return 1.0
        case .gestureTrail: return 0.3
        case .gestureMagnetic: return 0.5
        case .gestureElastic: return 0.8
        case .gestureRippleSpread: return 1.2
        case .gestureParticleFollow: return 0.6
        }
    }

    public var hapticStyle: HapticStyle {
        switch self {
        case .buttonPress, .toggleSlide: return .medium
        case .buttonHover, .cardHoverFloat: return .light
        case .buttonRipple, .gestureRippleSpread: return .soft
        case .toggleBounce, .cardPhysicsBounce: return .heavy
        case .sliderMagnetic, .gestureMagnetic: return .selection
        default: return .light
        }
    }

    public var particleBurst: BurstConfig? {
        switch self {
        case .buttonRipple:
            return BurstConfig(
                particleCount: 12,
                speedRange: 50...120,
                colors: [.blue.opacity(0.6), .cyan.opacity(0.4)],
                shapes: [.circle]
            )
        case .sliderParticles:
            return BurstConfig(
                particleCount: 8,
                speedRange: 30...80,
                colors: [.white.opacity(0.8), .gray.opacity(0.6)],
                shapes: [.circle, .square]
            )
        case .gestureParticleFollow:
            return BurstConfig(
                particleCount: 6,
                speedRange: 20...60,
                colors: [.purple.opacity(0.7), .pink.opacity(0.5)],
                shapes: [.star, .circle]
            )
        default:
            return nil
        }
    }
}

// MARK: - Advanced Button Component
public struct PixarButton: View {
    let title: String
    let action: () -> Void
    let style: PixarButtonStyle

    @State private var isPressed = false
    @State private var isHovered = false
    @State private var rippleCenter = CGPoint.zero
    @State private var rippleOpacity: Double = 0
    @State private var rippleScale: CGFloat = 0
    @State private var glowIntensity: Double = 0
    @StateObject private var microEngine = AdvancedMicroInteractionEngine.shared

    public init(
        title: String,
        style: PixarButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: {
            microEngine.triggerEffect(.buttonPress)
            action()
        }) {
            ZStack {
                // Base button
                RoundedRectangle(cornerRadius: 16)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style.borderColor, lineWidth: 2)
                    )

                // Glow effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(style.glowColor)
                    .blur(radius: 8)
                    .opacity(glowIntensity)

                // Ripple effect
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                    .position(rippleCenter)

                // Text
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(style.textColor)
            }
        }
        .frame(height: 50)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
        .shadow(
            color: style.shadowColor,
            radius: isHovered ? 12 : 8,
            y: isPressed ? 2 : (isHovered ? 6 : 4)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .animation(.easeInOut(duration: 0.3), value: glowIntensity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        rippleCenter = value.location

                        withAnimation(.easeOut(duration: 0.6)) {
                            rippleScale = 15
                            rippleOpacity = 1.0
                        }

                        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                            rippleOpacity = 0
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    rippleScale = 0
                }
        )
        .onHover { hovering in
            isHovered = hovering
            withAnimation(.easeInOut(duration: 0.3)) {
                glowIntensity = hovering ? 0.3 : 0
            }
            if hovering {
                microEngine.triggerEffect(.buttonHover)
            }
        }
    }
}

// MARK: - Button Styles
public enum PixarButtonStyle {
    case primary
    case secondary
    case success
    case warning
    case danger
    case glass
    case neon

    var backgroundColor: Color {
        switch self {
        case .primary: return Color.blue
        case .secondary: return Color.gray.opacity(0.2)
        case .success: return Color.green
        case .warning: return Color.orange
        case .danger: return Color.red
        case .glass: return Color.white.opacity(0.1)
        case .neon: return Color.purple
        }
    }

    var textColor: Color {
        switch self {
        case .primary, .success, .warning, .danger, .neon: return Color.white
        case .secondary, .glass: return Color.primary
        }
    }

    var borderColor: Color {
        switch self {
        case .primary: return Color.blue.opacity(0.5)
        case .secondary: return Color.gray.opacity(0.3)
        case .success: return Color.green.opacity(0.5)
        case .warning: return Color.orange.opacity(0.5)
        case .danger: return Color.red.opacity(0.5)
        case .glass: return Color.white.opacity(0.3)
        case .neon: return Color.purple.opacity(0.8)
        }
    }

    var glowColor: Color {
        switch self {
        case .primary: return Color.blue.opacity(0.4)
        case .secondary: return Color.gray.opacity(0.2)
        case .success: return Color.green.opacity(0.4)
        case .warning: return Color.orange.opacity(0.4)
        case .danger: return Color.red.opacity(0.4)
        case .glass: return Color.white.opacity(0.2)
        case .neon: return Color.purple.opacity(0.6)
        }
    }

    var shadowColor: Color {
        switch self {
        case .primary: return Color.blue.opacity(0.3)
        case .secondary: return Color.gray.opacity(0.2)
        case .success: return Color.green.opacity(0.3)
        case .warning: return Color.orange.opacity(0.3)
        case .danger: return Color.red.opacity(0.3)
        case .glass: return Color.black.opacity(0.1)
        case .neon: return Color.purple.opacity(0.4)
        }
    }
}

// MARK: - Advanced Toggle Component
public struct PixarToggle: View {
    @Binding var isOn: Bool
    let style: PixarToggleStyle

    @State private var dragOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0
    @State private var bounceScale: CGFloat = 1.0
    @StateObject private var microEngine = AdvancedMicroInteractionEngine.shared

    public init(
        isOn: Binding<Bool>,
        style: PixarToggleStyle = .standard
    ) {
        self._isOn = isOn
        self.style = style
    }

    public var body: some View {
        ZStack {
            // Track
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: isOn ? style.onTrackColors : style.offTrackColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(style.borderColor, lineWidth: 1)
                )

            // Glow
            RoundedRectangle(cornerRadius: 20)
                .fill(style.glowColor)
                .frame(width: 60, height: 32)
                .blur(radius: 6)
                .opacity(glowIntensity)

            // Thumb
            Circle()
                .fill(
                    LinearGradient(
                        colors: style.thumbColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .scaleEffect(bounceScale)
                .offset(x: (isOn ? 14 : -14) + dragOffset)
                .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isOn)
                .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: bounceScale)
        }
        .onTapGesture {
            microEngine.triggerEffect(.toggleBounce)

            withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
                bounceScale = 1.2
            }

            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.1)) {
                isOn.toggle()
                bounceScale = 1.0
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                glowIntensity = 0.6
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                glowIntensity = 0
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let clampedTranslation = max(-14, min(14, value.translation.x))
                    dragOffset = clampedTranslation

                    // Magnetic snap zones
                    if abs(clampedTranslation) > 10 {
                        let shouldBeOn = clampedTranslation > 0
                        if shouldBeOn != isOn {
                            microEngine.triggerEffect(.toggleMagnetic)
                        }
                    }
                }
                .onEnded { value in
                    let finalPosition = (isOn ? 14 : -14) + dragOffset
                    let shouldToggle = (finalPosition > 0) != isOn

                    dragOffset = 0

                    if shouldToggle {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                            isOn.toggle()
                        }
                    }
                }
        )
    }
}

// MARK: - Toggle Styles
public enum PixarToggleStyle {
    case standard
    case neon
    case gradient
    case glass

    var onTrackColors: [Color] {
        switch self {
        case .standard: return [.green, .mint]
        case .neon: return [.purple, .pink]
        case .gradient: return [.blue, .cyan]
        case .glass: return [.white.opacity(0.3), .white.opacity(0.1)]
        }
    }

    var offTrackColors: [Color] {
        switch self {
        case .standard: return [.gray.opacity(0.3), .gray.opacity(0.5)]
        case .neon: return [.gray.opacity(0.2), .gray.opacity(0.4)]
        case .gradient: return [.gray.opacity(0.2), .gray.opacity(0.4)]
        case .glass: return [.black.opacity(0.1), .black.opacity(0.2)]
        }
    }

    var thumbColors: [Color] {
        switch self {
        case .standard: return [.white, .gray.opacity(0.9)]
        case .neon: return [.white, .purple.opacity(0.1)]
        case .gradient: return [.white, .blue.opacity(0.1)]
        case .glass: return [.white.opacity(0.9), .white.opacity(0.7)]
        }
    }

    var borderColor: Color {
        switch self {
        case .standard: return .gray.opacity(0.3)
        case .neon: return .purple.opacity(0.5)
        case .gradient: return .blue.opacity(0.3)
        case .glass: return .white.opacity(0.5)
        }
    }

    var glowColor: Color {
        switch self {
        case .standard: return .green.opacity(0.4)
        case .neon: return .purple.opacity(0.6)
        case .gradient: return .blue.opacity(0.4)
        case .glass: return .white.opacity(0.3)
        }
    }
}

// MARK: - Advanced Card Component
public struct PixarCard<Content: View>: View {
    let content: Content
    let style: PixarCardStyle

    @State private var hoverOffset: CGSize = .zero
    @State private var tiltRotation: Double = 0
    @State private var perspective: CGFloat = 0
    @State private var glowIntensity: Double = 0
    @State private var scale: CGFloat = 1.0
    @StateObject private var microEngine = AdvancedMicroInteractionEngine.shared

    public init(
        style: PixarCardStyle = .elevated,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // Glow effect
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(style.glowColor)
                .blur(radius: 12)
                .opacity(glowIntensity)

            // Card background
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
                .shadow(
                    color: style.shadowColor,
                    radius: style.shadowRadius,
                    x: style.shadowOffset.x,
                    y: style.shadowOffset.y
                )

            // Content
            content
                .padding(style.contentPadding)
        }
        .scaleEffect(scale)
        .rotation3D(
            .degrees(tiltRotation),
            axis: (x: hoverOffset.height / 100, y: -hoverOffset.width / 100, z: 0),
            perspective: perspective
        )
        .offset(hoverOffset)
        .animation(.interpolatingSpring(stiffness: 200, damping: 15), value: hoverOffset)
        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: scale)
        .animation(.easeInOut(duration: 0.4), value: glowIntensity)
        .animation(.easeInOut(duration: 0.3), value: tiltRotation)
        .onHover { isHovering in
            if isHovering {
                microEngine.triggerEffect(.cardHoverFloat)

                withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                    hoverOffset = CGSize(width: 0, height: -8)
                    scale = 1.02
                    tiltRotation = 2
                    perspective = 0.5
                }

                withAnimation(.easeInOut(duration: 0.4)) {
                    glowIntensity = 0.4
                }
            } else {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    hoverOffset = .zero
                    scale = 1.0
                    tiltRotation = 0
                    perspective = 0
                }

                withAnimation(.easeOut(duration: 0.3)) {
                    glowIntensity = 0
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let dampedTranslation = CGSize(
                        width: value.translation.x * 0.3,
                        height: value.translation.y * 0.3
                    )
                    hoverOffset = dampedTranslation

                    // Tilt based on drag direction
                    tiltRotation = Double(value.translation.x * 0.05)
                    perspective = 1.0
                }
                .onEnded { _ in
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                        hoverOffset = .zero
                        tiltRotation = 0
                        perspective = 0
                    }
                }
        )
    }
}

// MARK: - Card Styles
public enum PixarCardStyle {
    case elevated
    case flat
    case glass
    case neon
    case gradient

    var backgroundColor: Color {
        switch self {
        case .elevated: return Color(.systemBackground)
        case .flat: return Color(.secondarySystemBackground)
        case .glass: return Color.white.opacity(0.1)
        case .neon: return Color.black.opacity(0.8)
        case .gradient: return Color.clear
        }
    }

    var borderColor: Color {
        switch self {
        case .elevated: return Color.clear
        case .flat: return Color(.separator)
        case .glass: return Color.white.opacity(0.2)
        case .neon: return Color.cyan.opacity(0.8)
        case .gradient: return Color.purple.opacity(0.3)
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .elevated: return 0
        case .flat: return 1
        case .glass: return 1.5
        case .neon: return 2
        case .gradient: return 1
        }
    }

    var shadowColor: Color {
        switch self {
        case .elevated: return Color.black.opacity(0.1)
        case .flat: return Color.clear
        case .glass: return Color.black.opacity(0.05)
        case .neon: return Color.cyan.opacity(0.3)
        case .gradient: return Color.purple.opacity(0.2)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .elevated: return 10
        case .flat: return 0
        case .glass: return 5
        case .neon: return 15
        case .gradient: return 8
        }
    }

    var shadowOffset: CGSize {
        switch self {
        case .elevated: return CGSize(width: 0, height: 4)
        case .flat: return .zero
        case .glass: return CGSize(width: 0, height: 2)
        case .neon: return CGSize(width: 0, height: 8)
        case .gradient: return CGSize(width: 0, height: 4)
        }
    }

    var glowColor: Color {
        switch self {
        case .elevated: return Color.blue.opacity(0.2)
        case .flat: return Color.gray.opacity(0.1)
        case .glass: return Color.white.opacity(0.3)
        case .neon: return Color.cyan.opacity(0.5)
        case .gradient: return Color.purple.opacity(0.4)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .elevated: return 16
        case .flat: return 8
        case .glass: return 20
        case .neon: return 12
        case .gradient: return 18
        }
    }

    var contentPadding: CGFloat {
        switch self {
        case .elevated: return 20
        case .flat: return 16
        case .glass: return 24
        case .neon: return 18
        case .gradient: return 20
        }
    }
}

// MARK: - View Extensions
public extension View {
    func pixarButton(
        title: String,
        style: PixarButtonStyle = .primary,
        action: @escaping () -> Void
    ) -> some View {
        PixarButton(title: title, style: style, action: action)
    }

    func pixarCard(style: PixarCardStyle = .elevated) -> some View {
        PixarCard(style: style) {
            self
        }
    }

    func microEffect(_ effect: MicroEffect, isActive: Bool = false) -> some View {
        self.onAppear {
            if isActive {
                AdvancedMicroInteractionEngine.shared.triggerEffect(effect)
            }
        }
    }

    func elasticPress() -> some View {
        self.scaleEffect(1.0)
            .onTapGesture {
                AdvancedMicroInteractionEngine.shared.triggerEffect(.buttonElastic)
            }
    }

    func magneticHover() -> some View {
        self.onHover { isHovering in
            if isHovering {
                AdvancedMicroInteractionEngine.shared.triggerEffect(.cardMagneticEdge)
            }
        }
    }
}