import SwiftUI

// MARK: - Motion Design Library
public struct MotionDesign {
    
    // MARK: - Spring Animations
    public enum SpringPreset {
        case gentle
        case smooth
        case snappy
        case bouncy
        case playful
        case dramatic
        case elastic
        case magnetic
        case liquid
        case sharp
        
        public var animation: Animation {
            switch self {
            case .gentle:
                return .spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.4)
            case .smooth:
                return .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
            case .snappy:
                return .spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.1)
            case .bouncy:
                return .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.3)
            case .playful:
                return .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3)
            case .dramatic:
                return .spring(response: 1.2, dampingFraction: 0.7, blendDuration: 0.8)
            case .elastic:
                return .spring(response: 0.7, dampingFraction: 0.3, blendDuration: 0.5)
            case .magnetic:
                return .spring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.05)
            case .liquid:
                return .spring(response: 1.0, dampingFraction: 0.8, blendDuration: 0.6)
            case .sharp:
                return .spring(response: 0.15, dampingFraction: 1.0, blendDuration: 0.05)
            }
        }
    }
    
    // MARK: - Transition Presets
    public enum TransitionPreset {
        case slide(direction: SlideDirection, distance: CGFloat = 50)
        case scale(from: CGFloat = 0.8, to: CGFloat = 1.0)
        case fade(opacity: Double = 0.0)
        case blur(radius: CGFloat = 10)
        case rotation(angle: Double = 90)
        case flip(axis: FlipAxis = .horizontal)
        case morph
        case liquid
        case elastic
        case magnetic
        
        public enum SlideDirection {
            case up, down, left, right, topLeading, topTrailing, bottomLeading, bottomTrailing
        }
        
        public enum FlipAxis {
            case horizontal, vertical
        }
        
        public func transition() -> AnyTransition {
            switch self {
            case .slide(let direction, let distance):
                let offset = offsetForDirection(direction, distance: distance)
                return .asymmetric(
                    insertion: .offset(offset).combined(with: .opacity),
                    removal: .offset(offset).combined(with: .opacity)
                )
                
            case .scale(let from, let to):
                return .asymmetric(
                    insertion: .scale(from).combined(with: .opacity),
                    removal: .scale(to).combined(with: .opacity)
                )
                
            case .fade(let opacity):
                return .opacity.combined(with: .scale(0.95))
                
            case .blur(let radius):
                return .modifier(
                    active: BlurTransitionModifier(blur: radius, opacity: 0),
                    identity: BlurTransitionModifier(blur: 0, opacity: 1)
                )
                
            case .rotation(let angle):
                return .asymmetric(
                    insertion: .rotation(.degrees(angle)).combined(with: .opacity),
                    removal: .rotation(.degrees(-angle)).combined(with: .opacity)
                )
                
            case .flip(let axis):
                let rotation: (Double, Double, Double) = axis == .horizontal ? (0, 1, 0) : (1, 0, 0)
                return .asymmetric(
                    insertion: .rotation3D(.degrees(90), axis: rotation).combined(with: .opacity),
                    removal: .rotation3D(.degrees(-90), axis: rotation).combined(with: .opacity)
                )
                
            case .morph:
                return .asymmetric(
                    insertion: .scale(0.3).combined(with: .rotation(.degrees(180))).combined(with: .opacity),
                    removal: .scale(1.3).combined(with: .rotation(.degrees(-180))).combined(with: .opacity)
                )
                
            case .liquid:
                return .modifier(
                    active: LiquidTransitionModifier(progress: 0),
                    identity: LiquidTransitionModifier(progress: 1)
                )
                
            case .elastic:
                return .asymmetric(
                    insertion: .scale(0.6).combined(with: .offset(y: 20)).combined(with: .opacity),
                    removal: .scale(1.2).combined(with: .offset(y: -20)).combined(with: .opacity)
                )
                
            case .magnetic:
                return .asymmetric(
                    insertion: .scale(0.9).combined(with: .blur(radius: 5)).combined(with: .opacity),
                    removal: .scale(1.1).combined(with: .blur(radius: 5)).combined(with: .opacity)
                )
            }
        }
        
        private func offsetForDirection(_ direction: SlideDirection, distance: CGFloat) -> CGSize {
            switch direction {
            case .up: return CGSize(width: 0, height: -distance)
            case .down: return CGSize(width: 0, height: distance)
            case .left: return CGSize(width: -distance, height: 0)
            case .right: return CGSize(width: distance, height: 0)
            case .topLeading: return CGSize(width: -distance, height: -distance)
            case .topTrailing: return CGSize(width: distance, height: -distance)
            case .bottomLeading: return CGSize(width: -distance, height: distance)
            case .bottomTrailing: return CGSize(width: distance, height: distance)
            }
        }
    }
    
    // MARK: - Page Transitions
    public enum PageTransition {
        case slide(direction: TransitionPreset.SlideDirection)
        case cube(direction: TransitionPreset.SlideDirection)
        case cover(direction: TransitionPreset.SlideDirection)
        case reveal(direction: TransitionPreset.SlideDirection)
        case flip(axis: TransitionPreset.FlipAxis)
        case fade
        case scale
        case rotate
        case liquid
        case parallax
        
        public func transition() -> AnyTransition {
            switch self {
            case .slide(let direction):
                return TransitionPreset.slide(direction: direction).transition()
            case .cube(let direction):
                return cubeTransition(direction: direction)
            case .cover(let direction):
                return coverTransition(direction: direction)
            case .reveal(let direction):
                return revealTransition(direction: direction)
            case .flip(let axis):
                return TransitionPreset.flip(axis: axis).transition()
            case .fade:
                return .opacity.combined(with: .scale(0.95))
            case .scale:
                return TransitionPreset.scale().transition()
            case .rotate:
                return TransitionPreset.rotation().transition()
            case .liquid:
                return TransitionPreset.liquid.transition()
            case .parallax:
                return parallaxTransition()
            }
        }
        
        private func cubeTransition(direction: TransitionPreset.SlideDirection) -> AnyTransition {
            let angle: Double = 90
            let axis: (x: Double, y: Double, z: Double)
            
            switch direction {
            case .left, .right:
                axis = (0, 1, 0)
            case .up, .down:
                axis = (1, 0, 0)
            default:
                axis = (1, 1, 0)
            }
            
            return .asymmetric(
                insertion: .rotation3D(.degrees(angle), axis: axis)
                    .combined(with: .offset(x: direction == .right ? 300 : direction == .left ? -300 : 0,
                                          y: direction == .down ? 300 : direction == .up ? -300 : 0)),
                removal: .rotation3D(.degrees(-angle), axis: axis)
                    .combined(with: .offset(x: direction == .left ? 300 : direction == .right ? -300 : 0,
                                          y: direction == .up ? 300 : direction == .down ? -300 : 0))
            )
        }
        
        private func coverTransition(direction: TransitionPreset.SlideDirection) -> AnyTransition {
            let offset = TransitionPreset.slide(direction: direction, distance: 300).offsetForDirection(direction, distance: 300)
            return .asymmetric(
                insertion: .offset(offset),
                removal: .scale(0.9).combined(with: .opacity.animation(.easeInOut(duration: 0.2)))
            )
        }
        
        private func revealTransition(direction: TransitionPreset.SlideDirection) -> AnyTransition {
            let offset = TransitionPreset.slide(direction: direction, distance: 300).offsetForDirection(direction, distance: 300)
            return .asymmetric(
                insertion: .scale(0.9).combined(with: .opacity.animation(.easeInOut(duration: 0.2))),
                removal: .offset(offset)
            )
        }
        
        private func parallaxTransition() -> AnyTransition {
            return .asymmetric(
                insertion: .offset(x: 100).combined(with: .scale(0.8)).combined(with: .opacity),
                removal: .offset(x: -100).combined(with: .scale(0.8)).combined(with: .opacity)
            )
        }
    }
    
    // MARK: - Loading Animations
    public enum LoadingAnimation {
        case pulse
        case bounce
        case rotate
        case scale
        case slide
        case wave
        case dots
        case spinner
        case progress
        case shimmer
        case breathe
        
        public var animation: Animation {
            switch self {
            case .pulse, .breathe:
                return .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
            case .bounce:
                return .interpolatingSpring(stiffness: 200, damping: 10).repeatForever(autoreverses: false)
            case .rotate, .spinner:
                return .linear(duration: 1.0).repeatForever(autoreverses: false)
            case .scale:
                return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
            case .slide, .wave:
                return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            case .dots:
                return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
            case .progress:
                return .linear(duration: 2.0).repeatForever(autoreverses: false)
            case .shimmer:
                return .linear(duration: 1.5).repeatForever(autoreverses: false)
            }
        }
    }
    
    // MARK: - Gesture Animations
    public enum GestureAnimation {
        case magnetic(strength: CGFloat = 20, radius: CGFloat = 50)
        case elastic(tension: CGFloat = 300, friction: CGFloat = 30)
        case liquid(viscosity: CGFloat = 0.8)
        case spring(response: Double = 0.4, damping: Double = 0.8)
        case rubber(intensity: CGFloat = 0.3)
        case physics(mass: CGFloat = 1.0, stiffness: CGFloat = 100, damping: CGFloat = 10)
        
        public func animation(for dragValue: DragGesture.Value) -> Animation {
            switch self {
            case .magnetic:
                return .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.2)
            case .elastic:
                return .interpolatingSpring(stiffness: 200, damping: 15)
            case .liquid(let viscosity):
                return .spring(response: 0.6 * viscosity, dampingFraction: 0.7, blendDuration: 0.3 * viscosity)
            case .spring(let response, let damping):
                return .spring(response: response, dampingFraction: damping, blendDuration: response * 0.5)
            case .rubber:
                return .interpolatingSpring(stiffness: 150, damping: 12)
            case .physics(let mass, let stiffness, let damping):
                return .interpolatingSpring(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: 0)
            }
        }
    }
}

// MARK: - Transition Modifier Implementations
struct BlurTransitionModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
    }
}

struct LiquidTransitionModifier: ViewModifier {
    let progress: CGFloat
    
    func body(content: Content) -> some View {
        content
            .clipShape(LiquidShape(progress: progress))
            .scaleEffect(0.8 + 0.2 * progress)
    }
}

struct LiquidShape: Shape {
    let progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight = rect.height * 0.1 * (1 - progress)
        let waveLength = rect.width
        
        path.move(to: CGPoint(x: 0, y: rect.height * (1 - progress)))
        
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / waveLength
            let sine = sin(relativeX * .pi * 2 + progress * .pi * 2) * waveHeight
            let y = rect.height * (1 - progress) + sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Motion Modifiers
public struct MotionModifier: ViewModifier {
    let motion: MotionType
    let isActive: Bool
    @State private var animationPhase: CGFloat = 0
    
    public init(motion: MotionType, isActive: Bool = true) {
        self.motion = motion
        self.isActive = isActive
    }
    
    public func body(content: Content) -> some View {
        content
            .modifier(motion.createModifier(phase: animationPhase, isActive: isActive))
            .onAppear {
                if isActive {
                    startMotion()
                }
            }
    }
    
    private func startMotion() {
        withAnimation(motion.animation) {
            animationPhase = 1.0
        }
    }
}

public enum MotionType {
    case float(amplitude: CGFloat = 10, speed: Double = 2.0)
    case rotate(speed: Double = 1.0)
    case pulse(scale: CGFloat = 1.1, speed: Double = 1.5)
    case bounce(height: CGFloat = 20, speed: Double = 0.8)
    case sway(angle: Double = 5, speed: Double = 2.0)
    case breathe(scale: CGFloat = 1.05, speed: Double = 2.0)
    case shimmer(speed: Double = 1.5)
    case wiggle(amplitude: CGFloat = 2, speed: Double = 4.0)
    
    public var animation: Animation {
        switch self {
        case .float(_, let speed):
            return .easeInOut(duration: speed).repeatForever(autoreverses: true)
        case .rotate(let speed):
            return .linear(duration: 1.0 / speed).repeatForever(autoreverses: false)
        case .pulse(_, let speed):
            return .easeInOut(duration: speed).repeatForever(autoreverses: true)
        case .bounce(_, let speed):
            return .interpolatingSpring(stiffness: 300, damping: 15)
                .repeatForever(autoreverses: false)
                .speed(speed)
        case .sway(_, let speed):
            return .easeInOut(duration: speed).repeatForever(autoreverses: true)
        case .breathe(_, let speed):
            return .easeInOut(duration: speed).repeatForever(autoreverses: true)
        case .shimmer(let speed):
            return .linear(duration: 1.0 / speed).repeatForever(autoreverses: false)
        case .wiggle(_, let speed):
            return .easeInOut(duration: 1.0 / speed).repeatForever(autoreverses: true)
        }
    }
    
    public func createModifier(phase: CGFloat, isActive: Bool) -> some ViewModifier {
        switch self {
        case .float(let amplitude, _):
            return AnyViewModifier(FloatModifier(amplitude: amplitude, phase: phase, isActive: isActive))
        case .rotate:
            return AnyViewModifier(RotateModifier(phase: phase, isActive: isActive))
        case .pulse(let scale, _):
            return AnyViewModifier(PulseModifier(scale: scale, phase: phase, isActive: isActive))
        case .bounce(let height, _):
            return AnyViewModifier(BounceModifier(height: height, phase: phase, isActive: isActive))
        case .sway(let angle, _):
            return AnyViewModifier(SwayModifier(angle: angle, phase: phase, isActive: isActive))
        case .breathe(let scale, _):
            return AnyViewModifier(BreatheModifier(scale: scale, phase: phase, isActive: isActive))
        case .shimmer:
            return AnyViewModifier(ShimmerMotionModifier(phase: phase, isActive: isActive))
        case .wiggle(let amplitude, _):
            return AnyViewModifier(WiggleModifier(amplitude: amplitude, phase: phase, isActive: isActive))
        }
    }
}

// MARK: - Motion Modifier Implementations
struct FloatModifier: ViewModifier {
    let amplitude: CGFloat
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.offset(y: -amplitude * sin(phase * 2 * .pi))
        } else {
            content
        }
    }
}

struct RotateModifier: ViewModifier {
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.rotationEffect(.degrees(Double(phase * 360)))
        } else {
            content
        }
    }
}

struct PulseModifier: ViewModifier {
    let scale: CGFloat
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.scaleEffect(1 + (scale - 1) * sin(phase * .pi))
        } else {
            content
        }
    }
}

struct BounceModifier: ViewModifier {
    let height: CGFloat
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.offset(y: -height * abs(sin(phase * .pi)))
        } else {
            content
        }
    }
}

struct SwayModifier: ViewModifier {
    let angle: Double
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.rotationEffect(.degrees(angle * sin(phase * 2 * .pi)))
        } else {
            content
        }
    }
}

struct BreatheModifier: ViewModifier {
    let scale: CGFloat
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .scaleEffect(1 + (scale - 1) * sin(phase * .pi))
                .opacity(0.8 + 0.2 * sin(phase * .pi))
        } else {
            content
        }
    }
}

struct ShimmerMotionModifier: ViewModifier {
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.4), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: -200 + 400 * phase)
                        .blendMode(.overlay)
                )
                .clipped()
        } else {
            content
        }
    }
}

struct WiggleModifier: ViewModifier {
    let amplitude: CGFloat
    let phase: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.offset(
                x: amplitude * sin(phase * 10 * .pi),
                y: amplitude * cos(phase * 8 * .pi) * 0.5
            )
        } else {
            content
        }
    }
}

// MARK: - View Extensions
public extension View {
    func motion(_ type: MotionType, isActive: Bool = true) -> some View {
        modifier(MotionModifier(motion: type, isActive: isActive))
    }
    
    func springTransition(_ preset: MotionDesign.SpringPreset = .smooth) -> some View {
        self.animation(preset.animation, value: UUID())
    }
    
    func pageTransition(_ transition: MotionDesign.PageTransition) -> some View {
        self.transition(transition.transition())
    }
    
    func loadingAnimation(_ type: MotionDesign.LoadingAnimation) -> some View {
        self.animation(type.animation.repeatForever(), value: UUID())
    }
    
    func parallaxScroll(offset: CGFloat, multiplier: CGFloat = 0.5) -> some View {
        self.offset(y: offset * multiplier)
    }
    
    func magneticEffect(strength: CGFloat = 20, radius: CGFloat = 50) -> some View {
        modifier(MagneticEffectModifier(strength: strength, radius: radius))
    }
}

// MARK: - Magnetic Effect Modifier
struct MagneticEffectModifier: ViewModifier {
    let strength: CGFloat
    let radius: CGFloat
    @State private var offset = CGSize.zero
    @State private var isAttracted = false
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .scaleEffect(isAttracted ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: offset)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAttracted)
            .onHover { hovering in
                // This would need proper gesture handling in a real implementation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isAttracted = hovering
                    offset = hovering ? CGSize(width: strength * 0.3, height: strength * 0.3) : .zero
                }
            }
    }
}