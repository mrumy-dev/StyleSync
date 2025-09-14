import SwiftUI

// MARK: - Spring Loaded View

struct SpringLoadedView<Content: View>: View {
    let content: Content
    let springResponse: Double
    let springDamping: Double
    let pressedScale: CGFloat
    let pressedOpacity: Double
    let onPress: (() -> Void)?
    let onRelease: (() -> Void)?

    @State private var isPressed = false
    @GestureState private var isPressing = false

    init(
        springResponse: Double = 0.4,
        springDamping: Double = 0.8,
        pressedScale: CGFloat = 0.95,
        pressedOpacity: Double = 0.8,
        onPress: (() -> Void)? = nil,
        onRelease: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.springResponse = springResponse
        self.springDamping = springDamping
        self.pressedScale = pressedScale
        self.pressedOpacity = pressedOpacity
        self.onPress = onPress
        self.onRelease = onRelease
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1.0)
            .opacity(isPressed ? pressedOpacity : 1.0)
            .animation(
                .interactiveSpring(response: springResponse, dampingFraction: springDamping),
                value: isPressed
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressing) { _, state, _ in
                        state = true
                    }
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress?()
                            HapticManager.HapticType.light.trigger()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease?()
                    }
            )
            .onChange(of: isPressing) { pressing in
                if !pressing && isPressed {
                    isPressed = false
                    onRelease?()
                }
            }
    }
}

// MARK: - Bounce Spring View

struct BounceSpringView<Content: View>: View {
    let content: Content
    let bounceScale: CGFloat
    let bounceIntensity: Double

    @State private var scale: CGFloat = 1.0
    @State private var isAnimating = false

    init(
        bounceScale: CGFloat = 1.2,
        bounceIntensity: Double = 0.6,
        @ViewBuilder content: () -> Content
    ) {
        self.bounceScale = bounceScale
        self.bounceIntensity = bounceIntensity
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(scale)
            .onTapGesture {
                triggerBounce()
            }
    }

    private func triggerBounce() {
        guard !isAnimating else { return }

        isAnimating = true
        HapticManager.HapticType.medium.trigger()
        SoundManager.SoundType.pop.play(volume: 0.5)

        withAnimation(.spring(response: 0.3, dampingFraction: bounceIntensity)) {
            scale = bounceScale
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                isAnimating = false
            }
        }
    }
}

// MARK: - Elastic Spring Container

struct ElasticSpringContainer<Content: View>: View {
    let content: Content
    let elasticResponse: Double
    let elasticDamping: Double

    @State private var dragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    init(
        elasticResponse: Double = 0.6,
        elasticDamping: Double = 0.8,
        @ViewBuilder content: () -> Content
    ) {
        self.elasticResponse = elasticResponse
        self.elasticDamping = elasticDamping
        self.content = content()
    }

    var body: some View {
        content
            .offset(dragOffset)
            .scaleEffect(scale)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Elastic resistance - harder to drag further
                        let resistance: CGFloat = 0.3
                        dragOffset = CGSize(
                            width: value.translation.x * resistance,
                            height: value.translation.y * resistance
                        )

                        // Scale based on drag distance
                        let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))
                        scale = 1.0 + min(distance / 500, 0.1)
                    }
                    .onEnded { value in
                        // Snap back with spring animation
                        withAnimation(.interactiveSpring(response: elasticResponse, dampingFraction: elasticDamping)) {
                            dragOffset = .zero
                            scale = 1.0
                        }

                        // Trigger haptic based on drag intensity
                        let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))
                        if distance > 50 {
                            HapticManager.HapticType.medium.trigger()
                        } else if distance > 20 {
                            HapticManager.HapticType.light.trigger()
                        }
                    }
            )
    }
}

// MARK: - Rubber Band Effect

struct RubberBandView<Content: View>: View {
    let content: Content
    let maxStretch: CGFloat
    let snapBack: Bool

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    init(
        maxStretch: CGFloat = 100,
        snapBack: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.maxStretch = maxStretch
        self.snapBack = snapBack
        self.content = content()
    }

    var body: some View {
        content
            .offset(offset)
            .scaleEffect(x: scale, y: 1.0 / scale) // Stretch horizontally, compress vertically
            .rotationEffect(.degrees(rotation))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let distance = min(sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2)), maxStretch)
                        let progress = distance / maxStretch

                        // Rubber band offset with diminishing returns
                        let elasticFactor = 1.0 - pow(progress, 2) * 0.7
                        offset = CGSize(
                            width: value.translation.x * elasticFactor,
                            height: value.translation.y * elasticFactor
                        )

                        // Stretch and rotate effects
                        scale = 1.0 + progress * 0.3
                        rotation = Double(value.translation.x * 0.1)

                        // Haptic feedback at stretch threshold
                        if distance > maxStretch * 0.8 {
                            HapticManager.HapticType.rigid.trigger()
                        }
                    }
                    .onEnded { _ in
                        if snapBack {
                            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.6)) {
                                offset = .zero
                                scale = 1.0
                                rotation = 0
                            }
                        }

                        HapticManager.HapticType.success.trigger()
                    }
            )
    }
}

// MARK: - Spring Loaded Button

struct SpringLoadedButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    let springIntensity: Double
    let hapticFeedback: HapticManager.HapticType

    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    @State private var brightness: Double = 0

    init(
        springIntensity: Double = 0.7,
        hapticFeedback: HapticManager.HapticType = .medium,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.springIntensity = springIntensity
        self.hapticFeedback = hapticFeedback
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: {
            triggerPress()
            action()
        }) {
            label
        }
        .buttonStyle(SpringLoadedButtonStyle(
            intensity: springIntensity,
            haptic: hapticFeedback
        ))
    }

    private func triggerPress() {
        hapticFeedback.trigger()
        SoundManager.SoundType.click.play(volume: 0.4)

        withAnimation(.spring(response: 0.3, dampingFraction: springIntensity)) {
            scale = 1.1
            brightness = 0.1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: springIntensity)) {
                scale = 1.0
                brightness = 0
            }
        }
    }
}

struct SpringLoadedButtonStyle: ButtonStyle {
    let intensity: Double
    let haptic: HapticManager.HapticType

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: intensity), value: configuration.isPressed)
    }
}

// MARK: - Jelly Effect

struct JellyEffectView<Content: View>: View {
    let content: Content
    let jellyIntensity: CGFloat

    @State private var jellyScale: CGSize = CGSize(width: 1, height: 1)
    @State private var isAnimating = false

    init(jellyIntensity: CGFloat = 0.2, @ViewBuilder content: () -> Content) {
        self.jellyIntensity = jellyIntensity
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(x: jellyScale.width, y: jellyScale.height)
            .onTapGesture {
                triggerJelly()
            }
    }

    private func triggerJelly() {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            jellyScale = CGSize(width: 1 + jellyIntensity, height: 1 - jellyIntensity * 0.5)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                jellyScale = CGSize(width: 1 - jellyIntensity * 0.5, height: 1 + jellyIntensity)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                jellyScale = CGSize(width: 1, height: 1)
                isAnimating = false
            }
        }

        HapticManager.HapticType.light.trigger()
    }
}

// MARK: - Interactive Spring Modifier

struct InteractiveSpringModifier: ViewModifier {
    let response: Double
    let damping: Double
    let onInteraction: (() -> Void)?

    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    init(response: Double = 0.4, damping: Double = 0.8, onInteraction: (() -> Void)? = nil) {
        self.response = response
        self.damping = damping
        self.onInteraction = onInteraction
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onTapGesture {
                onInteraction?()
                triggerSpring()
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onChanged { _ in
                        withAnimation(.spring(response: response, dampingFraction: damping)) {
                            scale = 1.05
                            rotation = Double.random(in: -5...5)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: response, dampingFraction: damping)) {
                            scale = 1.0
                            rotation = 0
                        }
                    }
            )
    }

    private func triggerSpring() {
        withAnimation(.spring(response: response, dampingFraction: damping)) {
            scale = 1.1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: response, dampingFraction: damping)) {
                scale = 1.0
            }
        }

        HapticManager.HapticType.light.trigger()
    }
}

extension View {
    func springLoaded(
        response: Double = 0.4,
        damping: Double = 0.8,
        pressedScale: CGFloat = 0.95,
        pressedOpacity: Double = 0.8,
        onPress: (() -> Void)? = nil,
        onRelease: (() -> Void)? = nil
    ) -> some View {
        SpringLoadedView(
            springResponse: response,
            springDamping: damping,
            pressedScale: pressedScale,
            pressedOpacity: pressedOpacity,
            onPress: onPress,
            onRelease: onRelease
        ) { self }
    }

    func elasticContainer(response: Double = 0.6, damping: Double = 0.8) -> some View {
        ElasticSpringContainer(elasticResponse: response, elasticDamping: damping) { self }
    }

    func jellyEffect(intensity: CGFloat = 0.2) -> some View {
        JellyEffectView(jellyIntensity: intensity) { self }
    }

    func interactiveSpring(response: Double = 0.4, damping: Double = 0.8, onInteraction: (() -> Void)? = nil) -> some View {
        modifier(InteractiveSpringModifier(response: response, damping: damping, onInteraction: onInteraction))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            Text("Spring Loaded Components")
                .font(.largeTitle.weight(.bold))

            VStack(spacing: 30) {
                SpringLoadedView(
                    onPress: { print("Pressed") },
                    onRelease: { print("Released") }
                ) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.accent.gradient)
                        .frame(height: 80)
                        .overlay(
                            Text("Spring Loaded")
                                .font(.headline)
                                .foregroundStyle(.white)
                        )
                }

                BounceSpringView {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("Bounce")
                                .font(.headline)
                                .foregroundStyle(.white)
                        )
                }

                ElasticSpringContainer {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surface)
                        .frame(height: 60)
                        .overlay(
                            Text("Drag Me - Elastic")
                                .font(.headline)
                        )
                }

                RubberBandView {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 100)
                        .overlay(
                            Text("Rubber Band")
                                .font(.headline)
                                .foregroundStyle(.white)
                        )
                }

                Text("Jelly Button")
                    .padding()
                    .background(DesignSystem.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .jellyEffect()

                Text("Interactive Spring")
                    .padding()
                    .background(DesignSystem.Colors.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .interactiveSpring()
            }
        }
        .padding()
    }
}