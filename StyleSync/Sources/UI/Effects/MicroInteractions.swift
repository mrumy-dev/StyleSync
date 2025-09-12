import SwiftUI
import Combine

// MARK: - Micro Interaction System
public class MicroInteractionManager: ObservableObject {
    @Published public var activeInteractions: Set<String> = []
    
    private var timers: [String: Timer] = [:]
    private var particleSystem = ParticleSystem()
    
    public init() {}
    
    public func trigger(_ interaction: MicroInteractionType, at position: CGPoint? = nil) {
        let id = interaction.id
        activeInteractions.insert(id)
        
        // Trigger particle effects if position is provided
        if let position = position, let burstConfig = interaction.particleBurst {
            particleSystem.burst(at: position, with: burstConfig)
        }
        
        // Auto-remove after duration
        timers[id]?.invalidate()
        timers[id] = Timer.scheduledTimer(withTimeInterval: interaction.duration, repeats: false) { [weak self] _ in
            self?.activeInteractions.remove(id)
            self?.timers.removeValue(forKey: id)
        }
    }
    
    public func isActive(_ interaction: MicroInteractionType) -> Bool {
        activeInteractions.contains(interaction.id)
    }
    
    public func getParticleSystem() -> ParticleSystem {
        return particleSystem
    }
}

// MARK: - Micro Interaction Types
public enum MicroInteractionType: CaseIterable {
    case buttonTap
    case buttonHover
    case swipeRight
    case swipeLeft
    case pullToRefresh
    case loading
    case success
    case error
    case heartbeat
    case bounce
    case shake
    case glow
    case ripple
    case magnetic
    case float
    case breath
    case shimmer
    case sparkle
    case confetti
    case fireworks
    
    public var id: String {
        switch self {
        case .buttonTap: return "buttonTap"
        case .buttonHover: return "buttonHover"
        case .swipeRight: return "swipeRight"
        case .swipeLeft: return "swipeLeft"
        case .pullToRefresh: return "pullToRefresh"
        case .loading: return "loading"
        case .success: return "success"
        case .error: return "error"
        case .heartbeat: return "heartbeat"
        case .bounce: return "bounce"
        case .shake: return "shake"
        case .glow: return "glow"
        case .ripple: return "ripple"
        case .magnetic: return "magnetic"
        case .float: return "float"
        case .breath: return "breath"
        case .shimmer: return "shimmer"
        case .sparkle: return "sparkle"
        case .confetti: return "confetti"
        case .fireworks: return "fireworks"
        }
    }
    
    public var duration: Double {
        switch self {
        case .buttonTap: return 0.2
        case .buttonHover: return 0.3
        case .swipeRight, .swipeLeft: return 0.4
        case .pullToRefresh: return 0.6
        case .loading: return 2.0
        case .success: return 0.8
        case .error: return 0.5
        case .heartbeat: return 1.0
        case .bounce: return 0.6
        case .shake: return 0.5
        case .glow: return 1.5
        case .ripple: return 0.8
        case .magnetic: return 0.4
        case .float: return 2.0
        case .breath: return 2.0
        case .shimmer: return 1.0
        case .sparkle: return 1.2
        case .confetti: return 2.0
        case .fireworks: return 1.5
        }
    }
    
    public var particleBurst: BurstConfig? {
        switch self {
        case .success:
            return BurstConfig(
                particleCount: 15,
                colors: [.green, .mint, .cyan],
                shapes: [.star, .circle]
            )
        case .confetti:
            return BurstConfig(
                particleCount: 30,
                colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
                shapes: [.square, .triangle, .circle]
            )
        case .fireworks:
            return BurstConfig(
                particleCount: 25,
                speedRange: 150...300,
                colors: [.yellow, .orange, .red, .purple, .blue],
                shapes: [.star, .sparkle, .diamond]
            )
        case .sparkle:
            return BurstConfig(
                particleCount: 8,
                speedRange: 50...120,
                colors: [.white, .yellow, .cyan],
                shapes: [.sparkle, .star]
            )
        default:
            return nil
        }
    }
}

// MARK: - Micro Interaction Modifiers
public struct MicroInteractionModifier: ViewModifier {
    let interaction: MicroInteractionType
    let isActive: Bool
    @StateObject private var manager = MicroInteractionManager()
    
    public init(interaction: MicroInteractionType, isActive: Bool = false) {
        self.interaction = interaction
        self.isActive = isActive
    }
    
    public func body(content: Content) -> some View {
        content
            .modifier(InteractionEffectModifier(interaction: interaction, isActive: isActive))
            .background(
                ParticleView(particleSystem: manager.getParticleSystem())
                    .allowsHitTesting(false)
            )
            .environmentObject(manager)
    }
}

struct InteractionEffectModifier: ViewModifier {
    let interaction: MicroInteractionType
    let isActive: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var hue: Double = 0
    @State private var phase: Double = 0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
            .hueRotation(.degrees(hue))
            .modifier(ShimmerModifier(isActive: isActive && interaction == .shimmer, phase: phase))
            .modifier(GlowModifier(isActive: isActive && interaction == .glow, intensity: sin(phase) * 0.5 + 0.5))
            .modifier(RippleModifier(isActive: isActive && interaction == .ripple, phase: phase))
            .onAppear {
                if isActive {
                    triggerInteraction()
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    triggerInteraction()
                } else {
                    resetToDefault()
                }
            }
    }
    
    private func triggerInteraction() {
        switch interaction {
        case .buttonTap:
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 0.95
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                scale = 1.0
            }
            
        case .buttonHover:
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.05
            }
            
        case .bounce:
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 10)) {
                scale = 1.2
            }
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 10).delay(0.3)) {
                scale = 1.0
            }
            
        case .shake:
            let shakeAnimation = Animation.easeInOut(duration: 0.1).repeatCount(5, autoreverses: true)
            withAnimation(shakeAnimation) {
                offset = CGSize(width: 10, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                offset = .zero
            }
            
        case .heartbeat:
            let heartbeatAnimation = Animation.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)
            withAnimation(heartbeatAnimation) {
                scale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                scale = 1.0
            }
            
        case .float:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                offset = CGSize(width: 0, height: -10)
            }
            
        case .breath:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scale = 1.05
                opacity = 0.8
            }
            
        case .shimmer, .glow, .ripple:
            withAnimation(.linear(duration: interaction.duration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
            
        case .success:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.1
                hue = 120 // Green tint
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                scale = 1.0
                hue = 0
            }
            
        case .error:
            let errorAnimation = Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)
            withAnimation(errorAnimation) {
                offset = CGSize(width: 5, height: 0)
                hue = 0 // Red tint
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = .zero
                    hue = 0
                }
            }
            
        case .magnetic:
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                scale = 1.05
            }
            
        default:
            break
        }
    }
    
    private func resetToDefault() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            scale = 1.0
            rotation = 0
            offset = .zero
            opacity = 1.0
            hue = 0
            phase = 0
        }
    }
}

// MARK: - Specialized Effect Modifiers
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    let phase: Double
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: 200 * sin(phase) - 100)
                        .blendMode(.overlay)
                )
                .clipped()
        } else {
            content
        }
    }
}

struct GlowModifier: ViewModifier {
    let isActive: Bool
    let intensity: Double
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .shadow(
                    color: .blue.opacity(0.3 * intensity),
                    radius: 10 * intensity,
                    x: 0,
                    y: 0
                )
                .shadow(
                    color: .white.opacity(0.2 * intensity),
                    radius: 20 * intensity,
                    x: 0,
                    y: 0
                )
        } else {
            content
        }
    }
}

struct RippleModifier: ViewModifier {
    let isActive: Bool
    let phase: Double
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    Circle()
                        .stroke(
                            Color.blue.opacity(1 - phase / (2 * .pi)),
                            lineWidth: 2
                        )
                        .scaleEffect(1 + phase / (2 * .pi))
                        .opacity(1 - phase / (2 * .pi))
                )
        } else {
            content
        }
    }
}

// MARK: - Gesture-Based Micro Interactions
public struct MagneticModifier: ViewModifier {
    @State private var dragOffset = CGSize.zero
    @State private var isNearby = false
    @EnvironmentObject private var manager: MicroInteractionManager
    
    let magneticStrength: CGFloat
    let attractionRadius: CGFloat
    
    public init(magneticStrength: CGFloat = 20, attractionRadius: CGFloat = 50) {
        self.magneticStrength = magneticStrength
        self.attractionRadius = attractionRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .offset(dragOffset)
            .scaleEffect(isNearby ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNearby)
            .gesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        let distance = sqrt(pow(value.location.x, 2) + pow(value.location.y, 2))
                        
                        if distance < attractionRadius {
                            isNearby = true
                            manager.trigger(.magnetic)
                            
                            let attraction = magneticStrength * (1 - distance / attractionRadius)
                            dragOffset = CGSize(
                                width: value.location.x * attraction / attractionRadius,
                                height: value.location.y * attraction / attractionRadius
                            )
                        } else {
                            isNearby = false
                            dragOffset = .zero
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            dragOffset = .zero
                            isNearby = false
                        }
                    }
            )
    }
}

// MARK: - Interactive Particle Effects
public struct InteractiveParticleModifier: ViewModifier {
    @State private var particleSystem = ParticleSystem()
    @State private var emitter: ParticleEmitter?
    
    let particleConfig: EmitterConfig
    let triggerOnHover: Bool
    
    public init(particleConfig: EmitterConfig, triggerOnHover: Bool = true) {
        self.particleConfig = particleConfig
        self.triggerOnHover = triggerOnHover
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ParticleView(particleSystem: particleSystem)
                    .allowsHitTesting(false)
            )
            .onHover { isHovering in
                if triggerOnHover {
                    if isHovering {
                        startParticleEmission()
                    } else {
                        stopParticleEmission()
                    }
                }
            }
            .onTapGesture { location in
                particleSystem.burst(
                    at: location,
                    with: BurstConfig(
                        particleCount: 10,
                        colors: particleConfig.colors,
                        shapes: particleConfig.shapes
                    )
                )
            }
    }
    
    private func startParticleEmission() {
        let newEmitter = ParticleEmitter(position: CGPoint(x: 50, y: 50), config: particleConfig)
        emitter = newEmitter
        particleSystem.addEmitter(newEmitter)
    }
    
    private func stopParticleEmission() {
        if let emitter = emitter {
            particleSystem.removeEmitter(emitter)
        }
        emitter = nil
    }
}

// MARK: - View Extensions
public extension View {
    func microInteraction(
        _ interaction: MicroInteractionType,
        isActive: Bool = false
    ) -> some View {
        modifier(MicroInteractionModifier(interaction: interaction, isActive: isActive))
    }
    
    func magnetic(
        strength: CGFloat = 20,
        radius: CGFloat = 50
    ) -> some View {
        modifier(MagneticModifier(magneticStrength: strength, attractionRadius: radius))
    }
    
    func interactiveParticles(
        config: EmitterConfig = EmitterConfig(),
        triggerOnHover: Bool = true
    ) -> some View {
        modifier(InteractiveParticleModifier(particleConfig: config, triggerOnHover: triggerOnHover))
    }
    
    func onSuccess(action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            action()
        }
        .microInteraction(.success, isActive: true)
    }
    
    func onError(action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            action()
        }
        .microInteraction(.error, isActive: true)
    }
}

// MARK: - Preset Configurations
public extension EmitterConfig {
    static let sparkles = EmitterConfig(
        emissionRate: 20,
        spawnRadius: 5,
        speedRange: 30...80,
        lifetimeRange: 0.8...1.5,
        colors: [.white, .yellow, .cyan],
        shapes: [.sparkle, .star]
    )
    
    static let fireflies = EmitterConfig(
        emissionRate: 5,
        spawnRadius: 20,
        angleRange: 0...(2 * .pi),
        speedRange: 10...30,
        lifetimeRange: 3.0...5.0,
        sizeRange: 2...4,
        gravity: CGPoint(x: 0, y: -10),
        colors: [.yellow.opacity(0.8), .green.opacity(0.6)],
        shapes: [.circle]
    )
    
    static let snow = EmitterConfig(
        emissionRate: 50,
        spawnRadius: 0,
        angleRange: (.pi * 0.4)...(.pi * 0.6),
        speedRange: 20...50,
        lifetimeRange: 5.0...8.0,
        sizeRange: 2...6,
        rotationSpeedRange: -30...30,
        gravity: CGPoint(x: 0, y: 50),
        colors: [.white, .blue.opacity(0.8)],
        shapes: [.circle, .star]
    )
    
    static let magic = EmitterConfig(
        emissionRate: 15,
        spawnRadius: 10,
        speedRange: 40...120,
        lifetimeRange: 1.5...3.0,
        colors: [.purple, .pink, .blue, .cyan],
        shapes: [.star, .sparkle, .diamond]
    )
}