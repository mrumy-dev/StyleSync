import SwiftUI
import Combine

// MARK: - Advanced Loading Animation System
public class LoadingAnimationManager: ObservableObject {
    @Published public var activeLoadingStates: Set<String> = []
    @Published public var loadingProgress: [String: Double] = [:]

    private var progressTimers: [String: Timer] = [:]
    private var particleSystem = ParticleSystem()

    public static let shared = LoadingAnimationManager()

    private init() {}

    public func startLoading(
        id: String,
        type: PixarLoadingType,
        simulateProgress: Bool = true
    ) {
        activeLoadingStates.insert(id)
        loadingProgress[id] = 0.0

        if simulateProgress {
            simulateLoadingProgress(for: id, type: type)
        }
    }

    public func updateProgress(id: String, progress: Double) {
        loadingProgress[id] = min(max(progress, 0.0), 1.0)
    }

    public func completeLoading(id: String) {
        loadingProgress[id] = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.activeLoadingStates.remove(id)
            self.loadingProgress.removeValue(forKey: id)
            self.progressTimers[id]?.invalidate()
            self.progressTimers.removeValue(forKey: id)
        }
    }

    private func simulateLoadingProgress(for id: String, type: PixarLoadingType) {
        progressTimers[id]?.invalidate()

        let totalDuration = type.estimatedDuration
        let updateInterval = 0.1
        let progressIncrement = updateInterval / totalDuration

        progressTimers[id] = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self,
                  let currentProgress = self.loadingProgress[id] else {
                timer.invalidate()
                return
            }

            let newProgress = currentProgress + progressIncrement
            if newProgress >= 1.0 {
                self.completeLoading(id: id)
            } else {
                self.loadingProgress[id] = newProgress
            }
        }
    }

    public func isLoading(id: String) -> Bool {
        activeLoadingStates.contains(id)
    }

    public func getProgress(id: String) -> Double {
        loadingProgress[id] ?? 0.0
    }
}

// MARK: - Pixar Loading Types
public enum PixarLoadingType: CaseIterable {
    // Skeleton Screens
    case skeletonText
    case skeletonCard
    case skeletonList
    case skeletonProfile
    case skeletonFeed
    case skeletonShimmer

    // Progressive Loading
    case progressiveImage
    case progressiveContent
    case progressiveList
    case progressiveFade

    // Shimmer Effects
    case shimmerWave
    case shimmerGradient
    case shimmerPulse
    case shimmerSparkle
    case shimmerLiquid

    // Pulse Animations
    case pulseCircle
    case pulseRing
    case pulseWave
    case pulseBreathe
    case pulseHeart

    // Wave Effects
    case waveRipple
    case waveLiquid
    case waveParticle
    case waveElastic
    case waveMagnetic

    // Particle Systems
    case particleOrbit
    case particleSwirl
    case particleFloat
    case particleTrail
    case particleBurst

    // Logo Animations
    case logoMorph
    case logoSpin
    case logoBreath
    case logoPulse
    case logoLiquid

    // Progress Rings
    case ringProgress
    case ringGlow
    case ringParticle
    case ringElastic
    case ringLiquid

    public var estimatedDuration: Double {
        switch self {
        case .skeletonText, .skeletonCard, .skeletonList: return 2.0
        case .skeletonProfile, .skeletonFeed: return 3.0
        case .skeletonShimmer: return 1.5
        case .progressiveImage, .progressiveContent: return 2.5
        case .progressiveList, .progressiveFade: return 3.0
        case .shimmerWave, .shimmerGradient: return 1.5
        case .shimmerPulse, .shimmerSparkle: return 2.0
        case .shimmerLiquid: return 2.5
        case .pulseCircle, .pulseRing, .pulseWave: return 1.0
        case .pulseBreathe, .pulseHeart: return 2.0
        case .waveRipple, .waveLiquid: return 1.5
        case .waveParticle, .waveElastic: return 2.0
        case .waveMagnetic: return 1.2
        case .particleOrbit, .particleSwirl: return 3.0
        case .particleFloat, .particleTrail: return 2.5
        case .particleBurst: return 1.0
        case .logoMorph, .logoSpin: return 2.0
        case .logoBreath, .logoPulse: return 1.5
        case .logoLiquid: return 2.5
        case .ringProgress, .ringGlow: return 2.0
        case .ringParticle, .ringElastic: return 2.5
        case .ringLiquid: return 3.0
        }
    }

    public var repeats: Bool {
        switch self {
        case .skeletonShimmer, .shimmerWave, .shimmerGradient, .shimmerPulse, .shimmerSparkle, .shimmerLiquid: return true
        case .pulseCircle, .pulseRing, .pulseWave, .pulseBreathe, .pulseHeart: return true
        case .waveRipple, .waveLiquid, .waveParticle, .waveElastic, .waveMagnetic: return true
        case .particleOrbit, .particleSwirl, .particleFloat, .particleTrail: return true
        case .logoMorph, .logoSpin, .logoBreath, .logoPulse, .logoLiquid: return true
        default: return false
        }
    }
}

// MARK: - Skeleton Loading Views
public struct SkeletonView: View {
    let type: SkeletonType
    let animated: Bool

    @State private var shimmerOffset: CGFloat = -200
    @State private var pulseOpacity: Double = 0.3

    public init(type: SkeletonType, animated: Bool = true) {
        self.type = type
        self.animated = animated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: type.spacing) {
            ForEach(0..<type.elementCount, id: \.self) { index in
                SkeletonElement(
                    width: type.elementWidth(for: index),
                    height: type.elementHeight,
                    shimmerOffset: shimmerOffset,
                    pulseOpacity: pulseOpacity
                )
            }
        }
        .onAppear {
            if animated {
                startShimmerAnimation()
                startPulseAnimation()
            }
        }
    }

    private func startShimmerAnimation() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 200
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.6
        }
    }
}

public enum SkeletonType {
    case text(lines: Int)
    case card
    case profile
    case list(items: Int)
    case feed

    var elementCount: Int {
        switch self {
        case .text(let lines): return lines
        case .card: return 3
        case .profile: return 4
        case .list(let items): return items
        case .feed: return 5
        }
    }

    var spacing: CGFloat {
        switch self {
        case .text: return 8
        case .card: return 12
        case .profile: return 10
        case .list: return 8
        case .feed: return 16
        }
    }

    var elementHeight: CGFloat {
        switch self {
        case .text: return 16
        case .card: return 20
        case .profile: return 18
        case .list: return 14
        case .feed: return 24
        }
    }

    func elementWidth(for index: Int) -> CGFloat {
        switch self {
        case .text:
            return index == elementCount - 1 ? 0.7 : 1.0
        case .card:
            return index == 0 ? 0.8 : (index == 1 ? 1.0 : 0.6)
        case .profile:
            return index == 0 ? 0.4 : (index == 1 ? 0.6 : 0.8)
        case .list:
            return index % 3 == 0 ? 0.9 : (index % 3 == 1 ? 0.7 : 0.8)
        case .feed:
            return index == 0 ? 0.3 : 0.85
        }
    }
}

struct SkeletonElement: View {
    let width: CGFloat
    let height: CGFloat
    let shimmerOffset: CGFloat
    let pulseOpacity: Double

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: geometry.size.width * width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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
                        .offset(x: shimmerOffset)
                        .clipped()
                )
                .opacity(pulseOpacity)
        }
        .frame(height: height)
    }
}

// MARK: - Advanced Shimmer Effects
public struct AdvancedShimmerView: View {
    let type: ShimmerType
    let content: AnyView?

    @State private var shimmerPhase: CGFloat = 0
    @State private var particlePhase: Double = 0

    public init<Content: View>(
        type: ShimmerType,
        @ViewBuilder content: () -> Content
    ) {
        self.type = type
        self.content = AnyView(content())
    }

    public init(type: ShimmerType) {
        self.type = type
        self.content = nil
    }

    public var body: some View {
        ZStack {
            // Base content or placeholder
            if let content = content {
                content
                    .redacted(reason: .placeholder)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 100)
            }

            // Shimmer overlay
            shimmerOverlay
        }
        .onAppear {
            startShimmerAnimation()
        }
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        switch type {
        case .wave:
            waveShimmer
        case .gradient:
            gradientShimmer
        case .pulse:
            pulseShimmer
        case .sparkle:
            sparkleShimmer
        case .liquid:
            liquidShimmer
        }
    }

    private var waveShimmer: some View {
        WaveShimmerShape(phase: shimmerPhase)
            .fill(
                LinearGradient(
                    colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blendMode(.overlay)
            .clipped()
    }

    private var gradientShimmer: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.4), location: shimmerPhase),
                        .init(color: .clear, location: min(shimmerPhase + 0.3, 1))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.overlay)
    }

    private var pulseShimmer: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .opacity(0.5 + 0.5 * sin(shimmerPhase * 2 * .pi))
            .blendMode(.overlay)
    }

    private var sparkleShimmer: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: 100 * sin(particlePhase + Double(index) * 0.8),
                        y: 80 * cos(particlePhase + Double(index) * 1.2)
                    )
                    .opacity(0.3 + 0.7 * sin(particlePhase + Double(index)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                particlePhase = 2 * .pi
            }
        }
    }

    private var liquidShimmer: some View {
        LiquidShimmerShape(phase: shimmerPhase)
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.6), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 50
                )
            )
            .blendMode(.overlay)
            .clipped()
    }

    private func startShimmerAnimation() {
        withAnimation(.linear(duration: type.duration).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.0
        }
    }
}

public enum ShimmerType {
    case wave
    case gradient
    case pulse
    case sparkle
    case liquid

    var duration: Double {
        switch self {
        case .wave: return 1.5
        case .gradient: return 2.0
        case .pulse: return 1.0
        case .sparkle: return 3.0
        case .liquid: return 2.5
        }
    }
}

// MARK: - Shimmer Shapes
struct WaveShimmerShape: Shape {
    let phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveLength = rect.width * 0.3
        let amplitude = 10.0
        let offset = rect.width * phase

        path.move(to: CGPoint(x: -waveLength + offset, y: 0))

        for x in stride(from: -waveLength, through: waveLength, by: 2) {
            let relativeX = x / waveLength
            let sine = sin(relativeX * .pi * 2) * amplitude
            let y = rect.midY + sine
            path.addLine(to: CGPoint(x: x + offset, y: y))
        }

        path.addLine(to: CGPoint(x: waveLength + offset, y: rect.height))
        path.addLine(to: CGPoint(x: -waveLength + offset, y: rect.height))
        path.closeSubpath()

        return path
    }
}

struct LiquidShimmerShape: Shape {
    let phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(
            x: rect.width * phase,
            y: rect.midY + 20 * sin(phase * .pi * 2)
        )
        let radius = 30 + 20 * sin(phase * .pi * 3)

        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        return path
    }
}

// MARK: - Progressive Loading Views
public struct ProgressiveLoadingView<Content: View>: View {
    let content: Content
    let loadingType: ProgressiveType
    let progress: Double

    @State private var maskOffset: CGFloat = 0
    @State private var blurRadius: CGFloat = 20

    public init(
        progress: Double,
        type: ProgressiveType = .fade,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.loadingType = type
        self.progress = progress
    }

    public var body: some View {
        ZStack {
            // Loading placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    AdvancedShimmerView(type: .wave)
                )

            // Progressive content reveal
            content
                .opacity(progressiveOpacity)
                .blur(radius: progressiveBlur)
                .mask(progressiveMask)
        }
        .onChange(of: progress) { newProgress in
            updateProgressiveState(progress: newProgress)
        }
    }

    private var progressiveOpacity: Double {
        switch loadingType {
        case .fade: return progress
        case .slideUp, .slideDown, .slideLeft, .slideRight: return progress > 0.1 ? 1.0 : 0.0
        case .blur: return 1.0
        case .reveal: return progress > 0.05 ? 1.0 : 0.0
        }
    }

    private var progressiveBlur: CGFloat {
        switch loadingType {
        case .blur: return CGFloat(20 * (1 - progress))
        default: return 0
        }
    }

    @ViewBuilder
    private var progressiveMask: some View {
        switch loadingType {
        case .fade, .blur:
            Rectangle()
        case .slideUp:
            Rectangle()
                .offset(y: CGFloat(100 * (1 - progress)))
        case .slideDown:
            Rectangle()
                .offset(y: CGFloat(-100 * (1 - progress)))
        case .slideLeft:
            Rectangle()
                .offset(x: CGFloat(-100 * (1 - progress)))
        case .slideRight:
            Rectangle()
                .offset(x: CGFloat(100 * (1 - progress)))
        case .reveal:
            Circle()
                .scale(CGFloat(progress * 2))
        }
    }

    private func updateProgressiveState(progress: Double) {
        let clampedProgress = max(0, min(1, progress))

        withAnimation(.easeOut(duration: 0.3)) {
            maskOffset = CGFloat(clampedProgress)
            blurRadius = CGFloat(20 * (1 - clampedProgress))
        }
    }
}

public enum ProgressiveType {
    case fade
    case slideUp
    case slideDown
    case slideLeft
    case slideRight
    case blur
    case reveal
}

// MARK: - Advanced Progress Rings
public struct PixarProgressRing: View {
    let progress: Double
    let style: ProgressRingStyle
    let size: CGFloat

    @State private var animatedProgress: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var particlePhase: Double = 0

    public init(
        progress: Double,
        style: ProgressRingStyle = .standard,
        size: CGFloat = 100
    ) {
        self.progress = progress
        self.style = style
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(style.backgroundColor, lineWidth: style.lineWidth)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(animatedProgress))
                .stroke(
                    style.progressGradient,
                    style: StrokeStyle(
                        lineWidth: style.lineWidth,
                        lineCap: style.lineCap
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Glow effect
            if style.hasGlow {
                Circle()
                    .trim(from: 0, to: CGFloat(animatedProgress))
                    .stroke(style.glowColor, lineWidth: style.lineWidth * 2)
                    .frame(width: size, height: size)
                    .blur(radius: 4)
                    .opacity(glowIntensity)
                    .rotationEffect(.degrees(-90))
            }

            // Particle trail
            if style.hasParticles {
                ForEach(0..<style.particleCount, id: \.self) { index in
                    Circle()
                        .fill(style.particleColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -size/2 + style.lineWidth/2)
                        .rotationEffect(.degrees(Double(animatedProgress) * 360 + Double(index) * 10))
                        .opacity(0.7)
                }
            }

            // Center content
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(style.textColor)

                if style.showLabel {
                    Text("Loading")
                        .font(.caption)
                        .foregroundColor(style.textColor.opacity(0.7))
                }
            }
        }
        .onChange(of: progress) { newProgress in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newProgress
            }

            if style.hasGlow {
                withAnimation(.easeInOut(duration: 0.3)) {
                    glowIntensity = newProgress > 0 ? 0.6 : 0
                }
            }
        }
        .onAppear {
            if style.hasParticles {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    particlePhase = 2 * .pi
                }
            }
        }
    }
}

public enum ProgressRingStyle {
    case standard
    case neon
    case gradient
    case particle

    var backgroundColor: Color {
        switch self {
        case .standard: return Color.gray.opacity(0.2)
        case .neon: return Color.black.opacity(0.3)
        case .gradient: return Color.purple.opacity(0.2)
        case .particle: return Color.blue.opacity(0.1)
        }
    }

    var progressGradient: LinearGradient {
        switch self {
        case .standard:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .neon:
            return LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
        case .gradient:
            return LinearGradient(colors: [.orange, .red, .purple], startPoint: .leading, endPoint: .trailing)
        case .particle:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .standard: return 8
        case .neon: return 6
        case .gradient: return 10
        case .particle: return 8
        }
    }

    var lineCap: CGLineCap {
        switch self {
        case .standard, .gradient: return .round
        case .neon: return .butt
        case .particle: return .round
        }
    }

    var hasGlow: Bool {
        switch self {
        case .neon, .gradient: return true
        default: return false
        }
    }

    var hasParticles: Bool {
        switch self {
        case .particle: return true
        default: return false
        }
    }

    var particleCount: Int {
        return 5
    }

    var glowColor: Color {
        switch self {
        case .neon: return .purple.opacity(0.6)
        case .gradient: return .orange.opacity(0.4)
        default: return .clear
        }
    }

    var particleColor: Color {
        return .white.opacity(0.8)
    }

    var textColor: Color {
        switch self {
        case .neon: return .white
        default: return .primary
        }
    }

    var showLabel: Bool {
        return true
    }
}

// MARK: - View Extensions
public extension View {
    func skeletonLoader(
        _ type: SkeletonType,
        isLoading: Bool
    ) -> some View {
        Group {
            if isLoading {
                SkeletonView(type: type)
            } else {
                self
            }
        }
    }

    func shimmerEffect(
        _ type: ShimmerType = .wave,
        isActive: Bool = true
    ) -> some View {
        overlay(
            Group {
                if isActive {
                    AdvancedShimmerView(type: type)
                        .allowsHitTesting(false)
                }
            }
        )
    }

    func progressiveLoading(
        progress: Double,
        type: ProgressiveType = .fade
    ) -> some View {
        ProgressiveLoadingView(progress: progress, type: type) {
            self
        }
    }

    func loadingState(
        _ type: PixarLoadingType,
        isLoading: Bool,
        progress: Double = 0
    ) -> some View {
        Group {
            if isLoading {
                switch type {
                case .skeletonText:
                    SkeletonView(type: .text(lines: 3))
                case .skeletonCard:
                    SkeletonView(type: .card)
                case .skeletonProfile:
                    SkeletonView(type: .profile)
                case .shimmerWave:
                    AdvancedShimmerView(type: .wave) { self }
                case .progressiveImage:
                    progressiveLoading(progress: progress, type: .reveal)
                case .ringProgress:
                    PixarProgressRing(progress: progress)
                default:
                    AdvancedShimmerView(type: .wave) { self }
                }
            } else {
                self
            }
        }
    }
}