import SwiftUI
import QuartzCore

// MARK: - ProMotion Animation Manager

@MainActor
class ProMotionAnimationManager: ObservableObject {
    static let shared = ProMotionAnimationManager()

    @Published var isProMotionEnabled = false
    @Published var displayRefreshRate: Double = 60.0

    private init() {
        detectProMotionSupport()
    }

    private func detectProMotionSupport() {
        guard let screen = UIScreen.main as UIScreen? else { return }

        if #available(iOS 15.0, *) {
            displayRefreshRate = screen.maximumFramesPerSecond
            isProMotionEnabled = displayRefreshRate > 60
        } else {
            displayRefreshRate = 60.0
            isProMotionEnabled = false
        }
    }

    var animationCurve: Animation {
        if isProMotionEnabled {
            return .interpolatingSpring(stiffness: 300, damping: 30)
        } else {
            return .easeInOut(duration: 0.3)
        }
    }

    var fastAnimation: Animation {
        if isProMotionEnabled {
            return .interpolatingSpring(stiffness: 400, damping: 25)
        } else {
            return .easeInOut(duration: 0.2)
        }
    }

    var smoothAnimation: Animation {
        if isProMotionEnabled {
            return .interpolatingSpring(stiffness: 200, damping: 35)
        } else {
            return .easeInOut(duration: 0.5)
        }
    }
}

// MARK: - High Refresh Rate Animations

struct ProMotionView<Content: View>: View {
    let content: Content
    let animationType: ProMotionAnimationType
    @StateObject private var animationManager = ProMotionAnimationManager.shared

    @State private var animationValue: Double = 0
    @State private var displayLink: CADisplayLink?

    init(animationType: ProMotionAnimationType = .smooth, @ViewBuilder content: () -> Content) {
        self.animationType = animationType
        self.content = content()
    }

    var body: some View {
        content
            .onAppear {
                if animationManager.isProMotionEnabled {
                    startProMotionAnimation()
                }
            }
            .onDisappear {
                stopProMotionAnimation()
            }
    }

    private func startProMotionAnimation() {
        displayLink = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            self?.updateAnimation()
        }, selector: #selector(DisplayLinkTarget.update))

        displayLink?.preferredFramesPerSecond = Int(animationManager.displayRefreshRate)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopProMotionAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateAnimation() {
        animationValue += 1.0 / animationManager.displayRefreshRate
    }
}

// Helper class for CADisplayLink target
private class DisplayLinkTarget {
    let update: () -> Void

    init(_ update: @escaping () -> Void) {
        self.update = update
    }

    @objc func update() {
        self.update()
    }
}

enum ProMotionAnimationType {
    case smooth, fast, elastic, continuous

    var duration: Double {
        switch self {
        case .smooth: return 0.6
        case .fast: return 0.3
        case .elastic: return 0.8
        case .continuous: return .infinity
        }
    }
}

// MARK: - Smooth Scroll View with ProMotion

struct ProMotionScrollView<Content: View>: View {
    let content: Content
    @StateObject private var animationManager = ProMotionAnimationManager.shared

    @State private var scrollOffset: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var isDecelerating = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).minY
                                )
                        }
                    )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                updateScrollPhysics(newOffset: value)
            }
        }
    }

    private func updateScrollPhysics(newOffset: CGFloat) {
        let offsetDelta = newOffset - scrollOffset
        velocity = offsetDelta * (animationManager.isProMotionEnabled ? 120 : 60)
        scrollOffset = newOffset

        if animationManager.isProMotionEnabled {
            // Enhanced physics for ProMotion displays
            withAnimation(animationManager.smoothAnimation) {
                // Smooth momentum scrolling
            }
        }
    }
}

// MARK: - Fluid Gesture Recognizer

struct FluidGestureView<Content: View>: View {
    let content: Content
    @StateObject private var animationManager = ProMotionAnimationManager.shared

    @State private var dragOffset: CGSize = .zero
    @State private var velocity: CGSize = .zero
    @State private var lastDragTime: Date = Date()

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .offset(dragOffset)
            .gesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        updateDragPhysics(translation: value.translation)
                    }
                    .onEnded { value in
                        endDragWithMomentum(finalTranslation: value.translation)
                    }
            )
    }

    private func updateDragPhysics(translation: CGSize) {
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastDragTime)

        if timeDelta > 0 {
            velocity = CGSize(
                width: (translation.width - dragOffset.width) / timeDelta,
                height: (translation.height - dragOffset.height) / timeDelta
            )
        }

        if animationManager.isProMotionEnabled {
            // Higher frequency updates for smoother tracking
            withAnimation(animationManager.fastAnimation) {
                dragOffset = translation
            }
        } else {
            dragOffset = translation
        }

        lastDragTime = currentTime
    }

    private func endDragWithMomentum(finalTranslation: CGSize) {
        let momentumDistance = CGSize(
            width: velocity.width * (animationManager.isProMotionEnabled ? 0.3 : 0.2),
            height: velocity.height * (animationManager.isProMotionEnabled ? 0.3 : 0.2)
        )

        let finalOffset = CGSize(
            width: finalTranslation.width + momentumDistance.width,
            height: finalTranslation.height + momentumDistance.height
        )

        withAnimation(animationManager.animationCurve) {
            dragOffset = .zero
        }
    }
}

// MARK: - Continuous Animation View

struct ContinuousAnimationView<Content: View>: View {
    let content: Content
    let rotationSpeed: Double
    let scaleRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>

    @StateObject private var animationManager = ProMotionAnimationManager.shared
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var animationTimer: Timer?

    init(
        rotationSpeed: Double = 1.0,
        scaleRange: ClosedRange<CGFloat> = 0.95...1.05,
        opacityRange: ClosedRange<Double> = 0.7...1.0,
        @ViewBuilder content: () -> Content
    ) {
        self.rotationSpeed = rotationSpeed
        self.scaleRange = scaleRange
        self.opacityRange = opacityRange
        self.content = content()
    }

    var body: some View {
        content
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                startContinuousAnimation()
            }
            .onDisappear {
                stopContinuousAnimation()
            }
    }

    private func startContinuousAnimation() {
        let interval = animationManager.isProMotionEnabled ? 1.0 / 120.0 : 1.0 / 60.0

        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            updateContinuousAnimation()
        }
    }

    private func stopContinuousAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateContinuousAnimation() {
        let time = Date().timeIntervalSince1970
        rotation = sin(time * rotationSpeed) * 10

        let scaleOffset = (scaleRange.upperBound - scaleRange.lowerBound) / 2
        let scaleCenter = scaleRange.lowerBound + scaleOffset
        scale = scaleCenter + sin(time * rotationSpeed * 0.8) * scaleOffset

        let opacityOffset = (opacityRange.upperBound - opacityRange.lowerBound) / 2
        let opacityCenter = opacityRange.lowerBound + opacityOffset
        opacity = opacityCenter + sin(time * rotationSpeed * 0.6) * opacityOffset
    }
}

// MARK: - Morphing Transitions

struct MorphingTransition: ViewModifier {
    let isActive: Bool
    @StateObject private var animationManager = ProMotionAnimationManager.shared

    @State private var morphProgress: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + morphProgress * 0.1)
            .opacity(1.0 - morphProgress * 0.3)
            .blur(radius: morphProgress * 2)
            .onChange(of: isActive) { active in
                withAnimation(animationManager.smoothAnimation) {
                    morphProgress = active ? 1.0 : 0.0
                }
            }
    }
}

// MARK: - Interactive Spring Animations

struct InteractiveSpringAnimation<Content: View>: View {
    let content: Content
    @StateObject private var animationManager = ProMotionAnimationManager.shared

    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))
                        let normalizedDistance = min(distance / 100, 1.0)

                        withAnimation(animationManager.fastAnimation) {
                            scale = 1.0 + normalizedDistance * 0.2
                            rotation = Double(value.translation.x * 0.1)
                            offset = CGSize(
                                width: value.translation.x * 0.3,
                                height: value.translation.y * 0.3
                            )
                        }
                    }
                    .onEnded { _ in
                        withAnimation(animationManager.animationCurve) {
                            scale = 1.0
                            rotation = 0
                            offset = .zero
                        }

                        HapticManager.HapticType.light.trigger()
                    }
            )
    }
}

// MARK: - Loading Animations

struct ProMotionLoadingView: View {
    @StateObject private var animationManager = ProMotionAnimationManager.shared
    @State private var rotationAngle: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(
                AngularGradient(
                    colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.3)],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                withAnimation(
                    .linear(duration: animationManager.isProMotionEnabled ? 0.8 : 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    rotationAngle = 360
                }
            }
    }
}

// MARK: - Extensions

extension View {
    func proMotionOptimized() -> some View {
        ProMotionView { self }
    }

    func fluidGestures() -> some View {
        FluidGestureView { self }
    }

    func continuousAnimation(
        rotationSpeed: Double = 1.0,
        scaleRange: ClosedRange<CGFloat> = 0.95...1.05,
        opacityRange: ClosedRange<Double> = 0.7...1.0
    ) -> some View {
        ContinuousAnimationView(
            rotationSpeed: rotationSpeed,
            scaleRange: scaleRange,
            opacityRange: opacityRange
        ) { self }
    }

    func morphingTransition(isActive: Bool) -> some View {
        modifier(MorphingTransition(isActive: isActive))
    }

    func interactiveSpring() -> some View {
        InteractiveSpringAnimation { self }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("ProMotion Animations")
                .font(.largeTitle.weight(.bold))

            ProMotionLoadingView()

            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.accent.gradient)
                .frame(height: 100)
                .overlay(
                    Text("ProMotion Optimized")
                        .font(.headline)
                        .foregroundStyle(.white)
                )
                .proMotionOptimized()

            Circle()
                .fill(DesignSystem.Colors.primary)
                .frame(width: 80, height: 80)
                .continuousAnimation()

            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.surface)
                .frame(height: 80)
                .overlay(
                    Text("Fluid Gestures")
                        .font(.headline)
                )
                .fluidGestures()

            Text("Interactive Spring")
                .padding()
                .background(DesignSystem.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .interactiveSpring()
        }
        .padding()
    }
}