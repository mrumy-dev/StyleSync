import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    let gradient: LinearGradient
    let minOpacity: Double
    let maxOpacity: Double
    let duration: Double
    let angle: Double
    let isActive: Bool

    @State private var startPoint: UnitPoint
    @State private var endPoint: UnitPoint
    @State private var isAnimating = false

    init(
        gradient: LinearGradient? = nil,
        minOpacity: Double = 0.3,
        maxOpacity: Double = 1.0,
        duration: Double = 1.5,
        angle: Double = 45,
        isActive: Bool = true
    ) {
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.duration = duration
        self.angle = angle
        self.isActive = isActive

        // Create default gradient if none provided
        self.gradient = gradient ?? LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.6),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        // Calculate start and end points based on angle
        let radians = angle * .pi / 180
        let startX = 0.5 + cos(radians + .pi) * 0.5
        let startY = 0.5 + sin(radians + .pi) * 0.5
        let endX = 0.5 + cos(radians) * 0.5
        let endY = 0.5 + sin(radians) * 0.5

        self.startPoint = UnitPoint(x: startX, y: startY)
        self.endPoint = UnitPoint(x: endX, y: endY)
    }

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? maxOpacity : minOpacity)
            .overlay(
                Rectangle()
                    .fill(gradient)
                    .opacity(isActive && isAnimating ? 0.7 : 0)
                    .animation(
                        isActive ? .easeInOut(duration: duration).repeatForever(autoreverses: false) : .default,
                        value: isAnimating
                    )
            )
            .onAppear {
                if isActive {
                    isAnimating = true
                }
            }
            .onChange(of: isActive) { active in
                isAnimating = active
            }
    }
}

// MARK: - Advanced Shimmer Effects

struct PulseShimmerModifier: ViewModifier {
    let color: Color
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    let isActive: Bool

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    init(
        color: Color = .white,
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        duration: Double = 2.0,
        isActive: Bool = true
    ) {
        self.color = color
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
        self.isActive = isActive
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                if isActive {
                    startAnimation()
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    startAnimation()
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            scale = maxScale
        }

        withAnimation(.easeInOut(duration: duration * 0.8).repeatForever(autoreverses: true)) {
            opacity = 0.6
        }
    }
}

struct WaveShimmerModifier: ViewModifier {
    let amplitude: CGFloat
    let frequency: Double
    let speed: Double
    let isActive: Bool

    @State private var phase: Double = 0

    init(
        amplitude: CGFloat = 10,
        frequency: Double = 2,
        speed: Double = 1.5,
        isActive: Bool = true
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.speed = speed
        self.isActive = isActive
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    WaveShape(amplitude: amplitude, frequency: frequency, phase: phase)
                        .fill(LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing))
                )
                .opacity(isActive ? 1 : 0)
            )
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                        phase = 2 * .pi
                    }
                }
            }
    }
}

struct WaveShape: Shape {
    let amplitude: CGFloat
    let frequency: Double
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2

        for x in stride(from: 0, to: width, by: 1) {
            let y = midHeight + amplitude * sin(frequency * x / width * 2 * .pi + phase)
            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - Skeleton Loading Shimmer

struct SkeletonShimmerModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isActive: Bool

    @State private var shimmerOffset: CGFloat = -1

    init(cornerRadius: CGFloat = 8, isActive: Bool = true) {
        self.cornerRadius = cornerRadius
        self.isActive = isActive
    }

    func body(content: Content) -> some View {
        content
            .redacted(reason: isActive ? .placeholder : [])
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset * UIScreen.main.bounds.width)
                    .opacity(isActive ? 1 : 0)
            )
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = 1
                    }
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = 1
                    }
                } else {
                    shimmerOffset = -1
                }
            }
    }
}

// MARK: - Breathing Shimmer

struct BreathingShimmerModifier: ViewModifier {
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    let isActive: Bool

    @State private var scale: CGFloat = 1.0
    @State private var brightness: Double = 0

    init(
        minScale: CGFloat = 0.98,
        maxScale: CGFloat = 1.02,
        duration: Double = 3.0,
        isActive: Bool = true
    ) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
        self.isActive = isActive
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .brightness(brightness)
            .onAppear {
                if isActive {
                    startBreathing()
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    startBreathing()
                } else {
                    withAnimation(.easeOut(duration: 0.5)) {
                        scale = 1.0
                        brightness = 0
                    }
                }
            }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            scale = maxScale
            brightness = 0.1
        }
    }
}

// MARK: - Shimmer Extensions

extension View {
    func shimmer(
        gradient: LinearGradient? = nil,
        minOpacity: Double = 0.3,
        maxOpacity: Double = 1.0,
        duration: Double = 1.5,
        angle: Double = 45,
        isActive: Bool = true
    ) -> some View {
        modifier(ShimmerModifier(
            gradient: gradient,
            minOpacity: minOpacity,
            maxOpacity: maxOpacity,
            duration: duration,
            angle: angle,
            isActive: isActive
        ))
    }

    func pulseShimmer(
        color: Color = .white,
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        duration: Double = 2.0,
        isActive: Bool = true
    ) -> some View {
        modifier(PulseShimmerModifier(
            color: color,
            minScale: minScale,
            maxScale: maxScale,
            duration: duration,
            isActive: isActive
        ))
    }

    func waveShimmer(
        amplitude: CGFloat = 10,
        frequency: Double = 2,
        speed: Double = 1.5,
        isActive: Bool = true
    ) -> some View {
        modifier(WaveShimmerModifier(
            amplitude: amplitude,
            frequency: frequency,
            speed: speed,
            isActive: isActive
        ))
    }

    func skeletonShimmer(cornerRadius: CGFloat = 8, isActive: Bool = true) -> some View {
        modifier(SkeletonShimmerModifier(cornerRadius: cornerRadius, isActive: isActive))
    }

    func breathingShimmer(
        minScale: CGFloat = 0.98,
        maxScale: CGFloat = 1.02,
        duration: Double = 3.0,
        isActive: Bool = true
    ) -> some View {
        modifier(BreathingShimmerModifier(
            minScale: minScale,
            maxScale: maxScale,
            duration: duration,
            isActive: isActive
        ))
    }
}

// MARK: - Shimmer Loading Cards

struct ShimmerLoadingCard: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 100, cornerRadius: CGFloat = 12) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
            .skeletonShimmer(cornerRadius: cornerRadius)
    }
}

struct ShimmerText: View {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat = 150, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
            .skeletonShimmer(cornerRadius: height / 2)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("Shimmer Effects")
                .font(.largeTitle.weight(.bold))

            VStack(spacing: 20) {
                Text("Basic Shimmer")
                    .font(.title2.weight(.semibold))

                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.surface)
                    .frame(height: 60)
                    .shimmer()

                Text("Pulse Shimmer")
                    .font(.title2.weight(.semibold))

                Circle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 80, height: 80)
                    .pulseShimmer()

                Text("Skeleton Loading")
                    .font(.title2.weight(.semibold))

                VStack(spacing: 16) {
                    ShimmerLoadingCard(height: 200)

                    HStack {
                        ShimmerText(width: 100)
                        Spacer()
                        ShimmerText(width: 60)
                    }

                    ShimmerText(width: 200)
                }

                Text("Breathing Effect")
                    .font(.title2.weight(.semibold))

                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.primary.opacity(0.8))
                    .frame(height: 100)
                    .breathingShimmer()
            }
        }
        .padding()
    }
}