import SwiftUI
import Combine

// MARK: - Advanced Page Transition System
public class PageTransitionManager: ObservableObject {
    @Published public var currentTransition: PixarTransition = .none
    @Published public var isTransitioning: Bool = false
    @Published public var transitionProgress: CGFloat = 0

    private var transitionTimer: Timer?
    private let hapticEngine = HapticFeedbackSystem.shared

    public static let shared = PageTransitionManager()

    private init() {}

    public func performTransition(
        _ transition: PixarTransition,
        duration: Double? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard !isTransitioning else { return }

        isTransitioning = true
        currentTransition = transition
        transitionProgress = 0

        // Trigger haptic feedback
        hapticEngine.impact(.light)

        let transitionDuration = duration ?? transition.duration

        // Animate progress
        withAnimation(transition.animation) {
            transitionProgress = 1.0
        }

        // Complete transition
        transitionTimer = Timer.scheduledTimer(withTimeInterval: transitionDuration, repeats: false) { [weak self] _ in
            self?.isTransitioning = false
            self?.currentTransition = .none
            self?.transitionProgress = 0
            completion?()
        }
    }

    public func cancelTransition() {
        transitionTimer?.invalidate()
        isTransitioning = false
        currentTransition = .none
        transitionProgress = 0
    }
}

// MARK: - Pixar Transition Types
public enum PixarTransition: CaseIterable {
    case none

    // Shared Element Transitions
    case sharedElementMorph(elementID: String)
    case sharedElementZoom(elementID: String)
    case sharedElementFlow(elementID: String)

    // Morphing Transitions
    case liquidMorph
    case elasticMorph
    case bubbleMorph
    case crystallineMorph
    case organicMorph

    // 3D Transitions
    case cubeFlip(direction: CubeDirection)
    case cylinderRotation(axis: RotationAxis)
    case sphereWarp
    case prismShatter
    case origamiFold

    // Carousel Effects
    case carouselHorizontal
    case carouselVertical
    case carouselDepth
    case infiniteCarousel
    case magneticCarousel

    // Zoom Transitions
    case zoomBlur
    case zoomParticles
    case zoomRipple
    case zoomSpiral
    case zoomPortal

    // Slide Variations
    case slidePhysics(direction: SlideDirection, physics: PhysicsProperties)
    case slideLiquid(direction: SlideDirection)
    case slideElastic(direction: SlideDirection)
    case slideMagnetic(direction: SlideDirection)

    // Spring & Physics
    case springBounce(intensity: SpringIntensity)
    case jelloBounce
    case rubberBand
    case pendulumSwing

    // Liquid Effects
    case liquidWave
    case liquidDrop
    case liquidSplash
    case liquidMelt
    case liquidVortex

    public enum CubeDirection {
        case up, down, left, right, forward, backward
    }

    public enum RotationAxis {
        case horizontal, vertical, diagonal
    }

    public enum SlideDirection {
        case up, down, left, right
    }

    public enum SpringIntensity {
        case gentle, normal, bouncy, extreme
    }

    public enum PhysicsProperties {
        case light(mass: CGFloat = 0.5)
        case normal(mass: CGFloat = 1.0)
        case heavy(mass: CGFloat = 2.0)
        case custom(mass: CGFloat, friction: CGFloat, tension: CGFloat)
    }

    public var duration: Double {
        switch self {
        case .none: return 0
        case .sharedElementMorph, .sharedElementZoom, .sharedElementFlow: return 0.8
        case .liquidMorph, .elasticMorph, .bubbleMorph: return 1.2
        case .crystallineMorph, .organicMorph: return 1.0
        case .cubeFlip, .cylinderRotation, .sphereWarp: return 0.9
        case .prismShatter: return 1.5
        case .origamiFold: return 1.1
        case .carouselHorizontal, .carouselVertical: return 0.7
        case .carouselDepth, .infiniteCarousel: return 1.0
        case .magneticCarousel: return 0.8
        case .zoomBlur, .zoomRipple: return 0.6
        case .zoomParticles: return 1.0
        case .zoomSpiral, .zoomPortal: return 0.9
        case .slidePhysics: return 0.8
        case .slideLiquid: return 1.2
        case .slideElastic: return 1.0
        case .slideMagnetic: return 0.6
        case .springBounce: return 0.9
        case .jelloBounce, .rubberBand: return 1.1
        case .pendulumSwing: return 1.3
        case .liquidWave, .liquidDrop: return 1.0
        case .liquidSplash: return 0.8
        case .liquidMelt: return 1.4
        case .liquidVortex: return 1.2
        }
    }

    public var animation: Animation {
        switch self {
        case .none: return .linear(duration: 0)
        case .sharedElementMorph: return .spring(response: 0.7, dampingFraction: 0.8)
        case .sharedElementZoom: return .spring(response: 0.5, dampingFraction: 0.7)
        case .sharedElementFlow: return .interpolatingSpring(stiffness: 200, damping: 20)
        case .liquidMorph: return .timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration)
        case .elasticMorph: return .interpolatingSpring(stiffness: 150, damping: 12)
        case .bubbleMorph: return .interpolatingSpring(stiffness: 300, damping: 15)
        case .crystallineMorph: return .timingCurve(0.68, -0.55, 0.265, 1.55, duration: duration)
        case .organicMorph: return .spring(response: 0.8, dampingFraction: 0.6)
        case .cubeFlip: return .timingCurve(0.25, 0.1, 0.25, 1.0, duration: duration)
        case .cylinderRotation: return .easeInOut(duration: duration)
        case .sphereWarp: return .spring(response: 0.6, dampingFraction: 0.8)
        case .prismShatter: return .timingCurve(0.55, 0.085, 0.68, 0.53, duration: duration)
        case .origamiFold: return .timingCurve(0.645, 0.045, 0.355, 1.0, duration: duration)
        case .carouselHorizontal, .carouselVertical: return .easeInOut(duration: duration)
        case .carouselDepth: return .timingCurve(0.4, 0.0, 0.2, 1.0, duration: duration)
        case .infiniteCarousel: return .linear(duration: duration)
        case .magneticCarousel: return .interpolatingSpring(stiffness: 250, damping: 18)
        case .zoomBlur, .zoomRipple: return .easeOut(duration: duration)
        case .zoomParticles: return .spring(response: 0.7, dampingFraction: 0.8)
        case .zoomSpiral: return .timingCurve(0.175, 0.885, 0.32, 1.275, duration: duration)
        case .zoomPortal: return .timingCurve(0.86, 0, 0.07, 1, duration: duration)
        case .slidePhysics: return .interpolatingSpring(stiffness: 200, damping: 20)
        case .slideLiquid: return .timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration)
        case .slideElastic: return .interpolatingSpring(stiffness: 180, damping: 14)
        case .slideMagnetic: return .interpolatingSpring(stiffness: 300, damping: 25)
        case .springBounce(.gentle): return .interpolatingSpring(stiffness: 100, damping: 15)
        case .springBounce(.normal): return .interpolatingSpring(stiffness: 200, damping: 20)
        case .springBounce(.bouncy): return .interpolatingSpring(stiffness: 300, damping: 15)
        case .springBounce(.extreme): return .interpolatingSpring(stiffness: 400, damping: 10)
        case .jelloBounce: return .interpolatingSpring(stiffness: 250, damping: 8)
        case .rubberBand: return .interpolatingSpring(stiffness: 150, damping: 6)
        case .pendulumSwing: return .timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration)
        case .liquidWave: return .timingCurve(0.4, 0.0, 0.6, 1.0, duration: duration)
        case .liquidDrop: return .timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration)
        case .liquidSplash: return .interpolatingSpring(stiffness: 180, damping: 12)
        case .liquidMelt: return .timingCurve(0.23, 1, 0.32, 1, duration: duration)
        case .liquidVortex: return .timingCurve(0.55, 0.055, 0.675, 0.19, duration: duration)
        }
    }
}

// MARK: - Shared Element Transition Coordinator
public class SharedElementCoordinator: ObservableObject {
    @Published public var sharedElements: [String: SharedElementData] = [:]

    public static let shared = SharedElementCoordinator()

    private init() {}

    public func registerElement(
        id: String,
        frame: CGRect,
        view: AnyView,
        namespace: Namespace.ID
    ) {
        sharedElements[id] = SharedElementData(
            id: id,
            frame: frame,
            view: view,
            namespace: namespace
        )
    }

    public func unregisterElement(id: String) {
        sharedElements.removeValue(forKey: id)
    }

    public func getElement(id: String) -> SharedElementData? {
        return sharedElements[id]
    }
}

public struct SharedElementData {
    let id: String
    let frame: CGRect
    let view: AnyView
    let namespace: Namespace.ID
}

// MARK: - Advanced Page Transition View
public struct PixarPageTransition<Content: View>: View {
    let content: Content
    let transition: PixarTransition
    let isPresented: Bool

    @StateObject private var transitionManager = PageTransitionManager.shared
    @State private var morphProgress: CGFloat = 0
    @State private var rotationAngle: Double = 0
    @State private var scaleEffect: CGFloat = 1.0
    @State private var offsetPosition: CGSize = .zero
    @State private var blurRadius: CGFloat = 0
    @State private var particleSystem = ParticleSystem()

    public init(
        transition: PixarTransition,
        isPresented: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.transition = transition
        self.isPresented = isPresented
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // Background particle effects for certain transitions
            if needsParticleBackground {
                ParticleView(particleSystem: particleSystem)
                    .allowsHitTesting(false)
            }

            // Main content with transition effects
            content
                .modifier(TransitionEffectModifier(
                    transition: transition,
                    progress: transitionManager.transitionProgress,
                    isPresented: isPresented
                ))
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                transitionManager.performTransition(transition)
                triggerParticleEffects()
            }
        }
    }

    private var needsParticleBackground: Bool {
        switch transition {
        case .zoomParticles, .prismShatter, .liquidSplash:
            return true
        default:
            return false
        }
    }

    private func triggerParticleEffects() {
        switch transition {
        case .zoomParticles:
            particleSystem.burst(
                at: CGPoint(x: 200, y: 400),
                with: BurstConfig(
                    particleCount: 30,
                    speedRange: 100...300,
                    colors: [.blue, .cyan, .purple],
                    shapes: [.circle, .star]
                )
            )
        case .liquidSplash:
            particleSystem.burst(
                at: CGPoint(x: 200, y: 300),
                with: BurstConfig(
                    particleCount: 25,
                    speedRange: 80...200,
                    colors: [.blue.opacity(0.7), .cyan.opacity(0.5)],
                    shapes: [.circle]
                )
            )
        default:
            break
        }
    }
}

// MARK: - Transition Effect Modifier
struct TransitionEffectModifier: ViewModifier {
    let transition: PixarTransition
    let progress: CGFloat
    let isPresented: Bool

    func body(content: Content) -> some View {
        switch transition {
        case .none:
            content

        case .liquidMorph:
            content
                .clipShape(LiquidMorphShape(progress: progress))
                .scaleEffect(0.95 + 0.05 * progress)

        case .cubeFlip(let direction):
            content
                .rotation3D(
                    .degrees(getCubeRotation(direction: direction, progress: progress)),
                    axis: getCubeAxis(direction: direction),
                    perspective: 0.5
                )

        case .elasticMorph:
            content
                .scaleEffect(
                    x: 1.0 + sin(progress * .pi) * 0.2,
                    y: 1.0 + cos(progress * .pi) * 0.1
                )

        case .bubbleMorph:
            content
                .clipShape(BubbleMorphShape(progress: progress))
                .scaleEffect(0.8 + 0.2 * progress)

        case .zoomBlur:
            content
                .scaleEffect(1.0 + progress * 2.0)
                .blur(radius: progress * 20)
                .opacity(1.0 - progress * 0.8)

        case .slidePhysics(let direction, _):
            content
                .offset(getSlideOffset(direction: direction, progress: progress))
                .scaleEffect(1.0 - progress * 0.1)

        case .springBounce(let intensity):
            content
                .scaleEffect(getBounceScale(intensity: intensity, progress: progress))
                .rotation3D(
                    .degrees(progress * 10),
                    axis: (x: 1, y: 1, z: 0),
                    perspective: 0.3
                )

        case .liquidWave:
            content
                .clipShape(LiquidWaveShape(progress: progress))

        case .crystallineMorph:
            content
                .clipShape(CrystallineMorphShape(progress: progress))
                .shadow(
                    color: .blue.opacity(0.3 * progress),
                    radius: 10 * progress
                )

        case .origamiFold:
            content
                .clipShape(OrigamiFoldShape(progress: progress))
                .rotation3D(
                    .degrees(progress * 45),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.8
                )

        case .liquidVortex:
            content
                .clipShape(VortexShape(progress: progress))
                .rotationEffect(.degrees(progress * 360))

        default:
            content
                .opacity(isPresented ? 1.0 : 0.0)
                .scaleEffect(isPresented ? 1.0 : 0.95)
        }
    }

    private func getCubeRotation(direction: PixarTransition.CubeDirection, progress: CGFloat) -> Double {
        let angle = Double(progress * 90)
        switch direction {
        case .up, .down: return direction == .up ? -angle : angle
        case .left, .right: return direction == .left ? -angle : angle
        case .forward, .backward: return direction == .forward ? angle : -angle
        }
    }

    private func getCubeAxis(direction: PixarTransition.CubeDirection) -> (x: Double, y: Double, z: Double) {
        switch direction {
        case .up, .down: return (1, 0, 0)
        case .left, .right: return (0, 1, 0)
        case .forward, .backward: return (0, 0, 1)
        }
    }

    private func getSlideOffset(direction: PixarTransition.SlideDirection, progress: CGFloat) -> CGSize {
        let distance: CGFloat = 400 * progress
        switch direction {
        case .up: return CGSize(width: 0, height: -distance)
        case .down: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }

    private func getBounceScale(intensity: PixarTransition.SpringIntensity, progress: CGFloat) -> CGFloat {
        let bounceAmount: CGFloat
        switch intensity {
        case .gentle: bounceAmount = 0.1
        case .normal: bounceAmount = 0.15
        case .bouncy: bounceAmount = 0.25
        case .extreme: bounceAmount = 0.4
        }

        return 1.0 + sin(progress * .pi * 2) * bounceAmount * (1 - progress)
    }
}

// MARK: - Custom Transition Shapes
struct LiquidMorphShape: Shape {
    let progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight = rect.height * 0.1 * sin(progress * .pi)
        let controlPointOffset = rect.width * 0.2 * progress

        path.move(to: CGPoint(x: 0, y: waveHeight))

        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: waveHeight),
            control: CGPoint(x: rect.width * 0.5 + controlPointOffset, y: waveHeight - 20)
        )

        path.addLine(to: CGPoint(x: rect.width, y: rect.height - waveHeight))

        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - waveHeight),
            control: CGPoint(x: rect.width * 0.5 - controlPointOffset, y: rect.height - waveHeight + 20)
        )

        path.closeSubpath()
        return path
    }
}

struct BubbleMorphShape: Shape {
    let progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bubbleRadius = min(rect.width, rect.height) * 0.5 * progress

        let center = CGPoint(x: rect.midX, y: rect.midY)

        path.addEllipse(in: CGRect(
            x: center.x - bubbleRadius,
            y: center.y - bubbleRadius,
            width: bubbleRadius * 2,
            height: bubbleRadius * 2
        ))

        return path
    }
}

struct LiquidWaveShape: Shape {
    let progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveLength = rect.width
        let amplitude = 20 * sin(progress * .pi)
        let phase = progress * .pi * 2

        path.move(to: CGPoint(x: 0, y: rect.midY))

        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / waveLength
            let sine = sin(relativeX * .pi * 4 + phase) * amplitude
            let y = rect.midY + sine
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

struct CrystallineMorphShape: Shape {
    let progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sides = 6
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.4 * progress
        let angleStep = 2 * CGFloat.pi / CGFloat(sides)

        for i in 0...sides {
            let angle = angleStep * CGFloat(i) + progress * .pi
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            let point = CGPoint(x: x, y: y)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

struct OrigamiFoldShape: Shape {
    let progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let foldLine = rect.width * progress

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: foldLine, y: 0))
        path.addLine(to: CGPoint(x: foldLine * 0.8, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

struct VortexShape: Shape {
    let progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) * 0.5
        let turns: CGFloat = 3

        let points = 100
        for i in 0...points {
            let t = CGFloat(i) / CGFloat(points)
            let angle = t * turns * 2 * .pi + progress * .pi * 2
            let radius = maxRadius * (1 - t) * progress
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - View Extensions
public extension View {
    func pixarTransition(
        _ transition: PixarTransition,
        isPresented: Bool
    ) -> some View {
        PixarPageTransition(transition: transition, isPresented: isPresented) {
            self
        }
    }

    func sharedElement(
        id: String,
        namespace: Namespace.ID
    ) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
            .onAppear {
                // Register with coordinator for advanced shared element tracking
            }
    }

    func liquidTransition(isPresented: Bool) -> some View {
        pixarTransition(.liquidMorph, isPresented: isPresented)
    }

    func cubeTransition(
        direction: PixarTransition.CubeDirection,
        isPresented: Bool
    ) -> some View {
        pixarTransition(.cubeFlip(direction: direction), isPresented: isPresented)
    }

    func springTransition(
        intensity: PixarTransition.SpringIntensity = .normal,
        isPresented: Bool
    ) -> some View {
        pixarTransition(.springBounce(intensity: intensity), isPresented: isPresented)
    }
}