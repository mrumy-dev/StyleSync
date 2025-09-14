import SwiftUI

// MARK: - Magnetic Button Style

struct MagneticButtonStyle: ButtonStyle {
    let magneticRadius: CGFloat
    let springResponse: Double
    let springDamping: Double

    init(
        magneticRadius: CGFloat = 30,
        springResponse: Double = 0.4,
        springDamping: Double = 0.8
    ) {
        self.magneticRadius = magneticRadius
        self.springResponse = springResponse
        self.springDamping = springDamping
    }

    func makeBody(configuration: Configuration) -> some View {
        MagneticButtonContent(
            configuration: configuration,
            magneticRadius: magneticRadius,
            springResponse: springResponse,
            springDamping: springDamping
        )
    }
}

private struct MagneticButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let magneticRadius: CGFloat
    let springResponse: Double
    let springDamping: Double

    @State private var offset: CGSize = .zero
    @State private var isHovering = false
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var shadowOffset: CGSize = .zero

    var body: some View {
        configuration.label
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: offset.height, y: -offset.width, z: 0)
            )
            .offset(offset)
            .shadow(
                color: DesignSystem.Colors.shadow.opacity(0.2),
                radius: 8,
                x: shadowOffset.width,
                y: shadowOffset.height + 2
            )
            .animation(
                .interactiveSpring(response: springResponse, dampingFraction: springDamping),
                value: offset
            )
            .animation(
                .interactiveSpring(response: springResponse, dampingFraction: springDamping),
                value: scale
            )
            .animation(
                .interactiveSpring(response: springResponse * 1.2, dampingFraction: springDamping),
                value: rotation
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))

                        if distance <= magneticRadius {
                            let magneticStrength = 1.0 - (distance / magneticRadius)
                            offset = CGSize(
                                width: value.translation.x * magneticStrength * 0.3,
                                height: value.translation.y * magneticStrength * 0.3
                            )
                            scale = 1.0 + magneticStrength * 0.05
                            rotation = Double(value.translation.x * magneticStrength * 0.2)
                            shadowOffset = CGSize(
                                width: -offset.width * 0.5,
                                height: -offset.height * 0.5
                            )

                            if !isHovering {
                                isHovering = true
                                HapticManager.HapticType.light.trigger()
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.interactiveSpring(response: springResponse, dampingFraction: springDamping)) {
                            offset = .zero
                            scale = configuration.isPressed ? 0.95 : 1.0
                            rotation = 0
                            shadowOffset = .zero
                            isHovering = false
                        }

                        if isHovering {
                            HapticManager.HapticType.medium.trigger()
                            SoundManager.SoundType.click.play(volume: 0.4)
                        }
                    }
            )
    }
}

// MARK: - Floating Magnetic Button

struct FloatingMagneticButton<Label: View>: View {
    let action: () -> Void
    let label: Label

    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var lastDragPosition: CGSize = .zero

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(FloatingMagneticButtonStyle())
        .offset(offset)
        .animation(
            .interactiveSpring(response: 0.6, dampingFraction: 0.8),
            value: offset
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    offset = CGSize(
                        width: lastDragPosition.width + value.translation.x,
                        height: lastDragPosition.height + value.translation.y
                    )
                }
                .onEnded { value in
                    isDragging = false
                    lastDragPosition = offset

                    // Snap to edges
                    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                        snapToEdges()
                    }
                }
        )
    }

    private func snapToEdges() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let buttonSize: CGFloat = 60
        let margin: CGFloat = 20

        // Snap to closest edge
        if offset.x < screenWidth / 2 {
            offset.x = -screenWidth / 2 + buttonSize / 2 + margin
        } else {
            offset.x = screenWidth / 2 - buttonSize / 2 - margin
        }

        // Keep within vertical bounds
        let maxY = screenHeight / 2 - buttonSize / 2 - margin
        offset.y = max(-maxY, min(maxY, offset.y))
    }
}

struct FloatingMagneticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(
                .interactiveSpring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Magnetic Grid Button

struct MagneticGridButton<Content: View>: View {
    let content: Content
    let action: () -> Void
    @State private var magneticOffset: CGSize = .zero
    @State private var neighbors: [CGPoint] = []

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(MagneticGridButtonStyle(offset: $magneticOffset))
        .onAppear {
            setupMagneticField()
        }
    }

    private func setupMagneticField() {
        // Setup magnetic field interactions with neighboring buttons
        neighbors = [
            CGPoint(x: -100, y: 0),   // Left
            CGPoint(x: 100, y: 0),    // Right
            CGPoint(x: 0, y: -100),   // Top
            CGPoint(x: 0, y: 100)     // Bottom
        ]
    }
}

struct MagneticGridButtonStyle: ButtonStyle {
    @Binding var offset: CGSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(offset)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .interactiveSpring(response: 0.4, dampingFraction: 0.8),
                value: configuration.isPressed
            )
    }
}

// MARK: - Elastic Magnetic Button

struct ElasticMagneticButton<Label: View>: View {
    let action: () -> Void
    let label: Label
    let elasticStrength: CGFloat

    @State private var dragOffset: CGSize = .zero
    @State private var elasticOffset: CGSize = .zero
    @State private var isStretched = false

    init(
        elasticStrength: CGFloat = 50,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.elasticStrength = elasticStrength
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(ElasticButtonStyle())
        .offset(elasticOffset)
        .scaleEffect(isStretched ? 1.1 : 1.0)
        .animation(
            .interactiveSpring(response: 0.5, dampingFraction: 0.6),
            value: elasticOffset
        )
        .animation(
            .interactiveSpring(response: 0.4, dampingFraction: 0.7),
            value: isStretched
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))
                    let elasticFactor = min(1.0, distance / elasticStrength)

                    elasticOffset = CGSize(
                        width: value.translation.x * (1 - elasticFactor * 0.7),
                        height: value.translation.y * (1 - elasticFactor * 0.7)
                    )

                    isStretched = distance > 10

                    if distance > 5 && !isStretched {
                        HapticManager.HapticType.light.trigger()
                    }
                }
                .onEnded { value in
                    let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))

                    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7)) {
                        elasticOffset = .zero
                        isStretched = false
                    }

                    if distance > elasticStrength {
                        // Elastic snap back with haptic feedback
                        HapticManager.HapticType.medium.trigger()
                        SoundManager.SoundType.pop.play(volume: 0.6)

                        // Trigger action with delay for elastic effect
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            action()
                        }
                    }
                }
        )
    }
}

struct ElasticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Magnetic Field Modifier

struct MagneticField: ViewModifier {
    let strength: Double
    let radius: CGFloat
    @State private var fieldOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(fieldOffset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let distance = sqrt(pow(value.location.x, 2) + pow(value.location.y, 2))
                        if distance <= radius {
                            let magneticPull = (1.0 - distance / radius) * strength
                            fieldOffset = CGSize(
                                width: value.location.x * magneticPull * 0.1,
                                height: value.location.y * magneticPull * 0.1
                            )
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8)) {
                            fieldOffset = .zero
                        }
                    }
            )
    }
}

extension View {
    func magneticField(strength: Double = 1.0, radius: CGFloat = 50) -> some View {
        modifier(MagneticField(strength: strength, radius: radius))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 40) {
            Text("Magnetic Buttons")
                .font(.largeTitle.weight(.bold))

            Button("Magnetic Button") {}
                .buttonStyle(MagneticButtonStyle())
                .padding()
                .background(DesignSystem.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            ElasticMagneticButton(action: {}) {
                Text("Elastic Button")
                    .padding()
                    .background(DesignSystem.Colors.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 20) {
                ForEach(0..<3) { index in
                    MagneticGridButton(action: {}) {
                        Circle()
                            .fill(DesignSystem.Colors.accent.gradient)
                            .frame(width: 60, height: 60)
                    }
                }
            }
        }
    }
}