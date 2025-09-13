import SwiftUI
import Combine

// MARK: - Hero Animation System
public class HeroAnimationSystem: ObservableObject {
    @Published public var activeAnimations: Set<String> = []
    @Published public var currentCelebration: CelebrationType? = nil

    private var animationTimers: [String: Timer] = []
    private var particleSystem = ParticleSystem()
    private let hapticEngine = HapticFeedbackSystem.shared

    public static let shared = HeroAnimationSystem()

    private init() {}

    public func playHeroAnimation(_ type: HeroAnimationType) {
        activeAnimations.insert(type.id)

        // Trigger haptic feedback
        hapticEngine.impact(type.hapticStyle)

        // Trigger celebration if applicable
        if let celebration = type.celebration {
            currentCelebration = celebration
        }

        // Auto-cleanup after duration
        let timer = Timer.scheduledTimer(withTimeInterval: type.duration, repeats: false) { [weak self] _ in
            self?.activeAnimations.remove(type.id)
            self?.animationTimers.removeValue(forKey: type.id)

            if type.celebration != nil {
                self?.currentCelebration = nil
            }
        }

        animationTimers[type.id] = timer
    }

    public func isPlaying(_ type: HeroAnimationType) -> Bool {
        activeAnimations.contains(type.id)
    }

    public func stopAnimation(_ type: HeroAnimationType) {
        activeAnimations.remove(type.id)
        animationTimers[type.id]?.invalidate()
        animationTimers.removeValue(forKey: type.id)

        if type.celebration != nil {
            currentCelebration = nil
        }
    }

    public func stopAllAnimations() {
        activeAnimations.removeAll()
        animationTimers.values.forEach { $0.invalidate() }
        animationTimers.removeAll()
        currentCelebration = nil
    }
}

// MARK: - Hero Animation Types
public enum HeroAnimationType: CaseIterable {
    // App Launch Animations
    case appLaunch3DLogo
    case logoReveal
    case brandingSplash

    // Onboarding Animations
    case onboardingParallax
    case welcomeSequence
    case featureIntroduction
    case tutorialHighlight

    // Success Celebrations
    case achievementUnlock
    case levelUp
    case milestoneReached
    case perfectScore
    case firstTimeMagic

    // Outfit & Style Animations
    case outfitReveal
    case styleTransformation
    case wardrobeUnlock
    case fashionShow
    case colorHarmony

    // Matching & Discovery
    case matchFound
    case perfectMatch
    case styleDiscovery
    case trendAlert
    case inspirationStrike

    // Purchase & Shopping
    case purchaseSuccess
    case addedToCart
    case wishlistSaved
    case dealFound
    case priceDropAlert

    // Social Interactions
    case followGained
    case postLiked
    case commentReceived
    case shareSuccess
    case communityJoined

    public var id: String {
        switch self {
        case .appLaunch3DLogo: return "appLaunch3DLogo"
        case .logoReveal: return "logoReveal"
        case .brandingSplash: return "brandingSplash"
        case .onboardingParallax: return "onboardingParallax"
        case .welcomeSequence: return "welcomeSequence"
        case .featureIntroduction: return "featureIntroduction"
        case .tutorialHighlight: return "tutorialHighlight"
        case .achievementUnlock: return "achievementUnlock"
        case .levelUp: return "levelUp"
        case .milestoneReached: return "milestoneReached"
        case .perfectScore: return "perfectScore"
        case .firstTimeMagic: return "firstTimeMagic"
        case .outfitReveal: return "outfitReveal"
        case .styleTransformation: return "styleTransformation"
        case .wardrobeUnlock: return "wardrobeUnlock"
        case .fashionShow: return "fashionShow"
        case .colorHarmony: return "colorHarmony"
        case .matchFound: return "matchFound"
        case .perfectMatch: return "perfectMatch"
        case .styleDiscovery: return "styleDiscovery"
        case .trendAlert: return "trendAlert"
        case .inspirationStrike: return "inspirationStrike"
        case .purchaseSuccess: return "purchaseSuccess"
        case .addedToCart: return "addedToCart"
        case .wishlistSaved: return "wishlistSaved"
        case .dealFound: return "dealFound"
        case .priceDropAlert: return "priceDropAlert"
        case .followGained: return "followGained"
        case .postLiked: return "postLiked"
        case .commentReceived: return "commentReceived"
        case .shareSuccess: return "shareSuccess"
        case .communityJoined: return "communityJoined"
        }
    }

    public var duration: Double {
        switch self {
        case .appLaunch3DLogo: return 3.0
        case .logoReveal: return 2.5
        case .brandingSplash: return 2.0
        case .onboardingParallax: return 4.0
        case .welcomeSequence: return 3.5
        case .featureIntroduction: return 2.8
        case .tutorialHighlight: return 1.5
        case .achievementUnlock: return 3.0
        case .levelUp: return 4.0
        case .milestoneReached: return 2.5
        case .perfectScore: return 3.5
        case .firstTimeMagic: return 4.5
        case .outfitReveal: return 2.0
        case .styleTransformation: return 3.0
        case .wardrobeUnlock: return 2.5
        case .fashionShow: return 5.0
        case .colorHarmony: return 1.8
        case .matchFound: return 2.0
        case .perfectMatch: return 3.0
        case .styleDiscovery: return 2.2
        case .trendAlert: return 1.5
        case .inspirationStrike: return 2.8
        case .purchaseSuccess: return 2.0
        case .addedToCart: return 1.2
        case .wishlistSaved: return 1.0
        case .dealFound: return 1.8
        case .priceDropAlert: return 1.5
        case .followGained: return 1.5
        case .postLiked: return 0.8
        case .commentReceived: return 1.2
        case .shareSuccess: return 1.5
        case .communityJoined: return 2.5
        }
    }

    public var hapticStyle: HapticStyle {
        switch self {
        case .appLaunch3DLogo, .logoReveal, .brandingSplash: return .none
        case .achievementUnlock, .levelUp, .perfectScore, .firstTimeMagic: return .success
        case .matchFound, .perfectMatch, .purchaseSuccess: return .success
        case .outfitReveal, .styleTransformation: return .medium
        case .addedToCart, .wishlistSaved, .followGained: return .light
        case .trendAlert, .priceDropAlert, .inspirationStrike: return .notification
        default: return .light
        }
    }

    public var celebration: CelebrationType? {
        switch self {
        case .achievementUnlock: return .fireworks
        case .levelUp: return .confetti
        case .perfectScore, .perfectMatch: return .sparkles
        case .firstTimeMagic: return .magic
        case .purchaseSuccess: return .hearts
        case .fashionShow: return .glamour
        case .communityJoined: return .welcome
        default: return nil
        }
    }
}

// MARK: - Celebration Types
public enum CelebrationType: CaseIterable {
    case confetti
    case fireworks
    case sparkles
    case hearts
    case stars
    case magic
    case glamour
    case welcome
    case achievement
    case success

    public var particleBurst: BurstConfig {
        switch self {
        case .confetti:
            return BurstConfig(
                particleCount: 50,
                speedRange: 100...300,
                colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
                shapes: [.square, .triangle, .circle, .heart],
                gravity: CGPoint(x: 0, y: 150)
            )

        case .fireworks:
            return BurstConfig(
                particleCount: 30,
                speedRange: 150...400,
                colors: [.yellow, .orange, .red, .purple, .blue, .white],
                shapes: [.star, .sparkle, .diamond],
                gravity: CGPoint(x: 0, y: 80)
            )

        case .sparkles:
            return BurstConfig(
                particleCount: 25,
                speedRange: 80...200,
                colors: [.white, .yellow, .cyan, .pink],
                shapes: [.sparkle, .star],
                gravity: CGPoint(x: 0, y: 30)
            )

        case .hearts:
            return BurstConfig(
                particleCount: 20,
                speedRange: 50...150,
                colors: [.pink, .red, .purple],
                shapes: [.heart],
                gravity: CGPoint(x: 0, y: -50)
            )

        case .stars:
            return BurstConfig(
                particleCount: 15,
                speedRange: 60...180,
                colors: [.yellow, .white, .orange],
                shapes: [.star],
                gravity: CGPoint(x: 0, y: 40)
            )

        case .magic:
            return BurstConfig(
                particleCount: 35,
                speedRange: 120...250,
                colors: [.purple, .pink, .cyan, .indigo],
                shapes: [.star, .sparkle, .diamond],
                gravity: CGPoint(x: 0, y: 20)
            )

        case .glamour:
            return BurstConfig(
                particleCount: 40,
                speedRange: 90...220,
                colors: [.gold, .silver, .rose, .platinum],
                shapes: [.diamond, .sparkle, .star],
                gravity: CGPoint(x: 0, y: 60)
            )

        case .welcome:
            return BurstConfig(
                particleCount: 30,
                speedRange: 70...180,
                colors: [.blue, .green, .cyan, .mint],
                shapes: [.circle, .star],
                gravity: CGPoint(x: 0, y: 45)
            )

        case .achievement:
            return BurstConfig(
                particleCount: 25,
                speedRange: 100...250,
                colors: [.orange, .yellow, .gold],
                shapes: [.star, .trophy],
                gravity: CGPoint(x: 0, y: 70)
            )

        case .success:
            return BurstConfig(
                particleCount: 20,
                speedRange: 80...200,
                colors: [.green, .mint, .lime],
                shapes: [.checkmark, .star],
                gravity: CGPoint(x: 0, y: 50)
            )
        }
    }
}

// MARK: - 3D Logo Animation
public struct Logo3DView: View {
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var rotationZ: Double = 0
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var glowIntensity: Double = 0

    let isAnimating: Bool

    public init(isAnimating: Bool = true) {
        self.isAnimating = isAnimating
    }

    public var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.3 * glowIntensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Main logo
            Text("S")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 5)
                .rotation3D(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
                .rotation3D(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
                .rotation3D(.degrees(rotationZ), axis: (x: 0, y: 0, z: 1))
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        // Initial entrance
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }

        // Glow build-up
        withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
            glowIntensity = 1.0
        }

        // 3D rotation sequence
        withAnimation(.easeInOut(duration: 2.0).delay(1.0)) {
            rotationY = 360
        }

        withAnimation(.easeInOut(duration: 1.5).delay(2.0)) {
            rotationX = 360
        }

        withAnimation(.easeInOut(duration: 1.0).delay(2.5)) {
            rotationZ = 360
        }

        // Final settle
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(3.0)) {
            rotationX = 0
            rotationY = 0
            rotationZ = 0
            glowIntensity = 0.3
        }
    }
}

// MARK: - Onboarding Parallax View
public struct OnboardingParallaxView: View {
    @State private var backgroundOffset: CGFloat = 0
    @State private var midgroundOffset: CGFloat = 0
    @State private var foregroundOffset: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.8

    let isAnimating: Bool
    let title: String
    let subtitle: String

    public init(isAnimating: Bool = true, title: String, subtitle: String) {
        self.isAnimating = isAnimating
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer (slowest)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: backgroundOffset * 0.2)

                // Midground layer (medium speed)
                HStack(spacing: 20) {
                    ForEach(0..<5) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 60, height: 60)
                    }
                }
                .offset(x: midgroundOffset * 0.5)

                // Foreground layer (fastest)
                VStack(spacing: 20) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .scaleEffect(textScale)
                        .opacity(textOpacity)

                    Text(subtitle)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .scaleEffect(textScale)
                        .opacity(textOpacity)
                }
                .offset(x: foregroundOffset * 0.8)
            }
        }
        .onAppear {
            if isAnimating {
                startParallaxAnimation()
            }
        }
    }

    private func startParallaxAnimation() {
        // Parallax movement
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            backgroundOffset = 50
            midgroundOffset = 30
            foregroundOffset = 20
        }

        // Text entrance
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.5)) {
            textOpacity = 1.0
            textScale = 1.0
        }
    }
}

// MARK: - Achievement Unlock Animation
public struct AchievementUnlockView: View {
    @State private var badgeScale: CGFloat = 0
    @State private var badgeRotation: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var rayRotation: Double = 0
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0

    let achievement: String
    let isAnimating: Bool

    public init(achievement: String, isAnimating: Bool = true) {
        self.achievement = achievement
        self.isAnimating = isAnimating
    }

    public var body: some View {
        ZStack {
            // Radiating rays
            ForEach(0..<8) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 4)
                    .offset(x: 40)
                    .rotationEffect(.degrees(Double(index * 45) + rayRotation))
                    .opacity(glowOpacity)
            }

            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.yellow.opacity(0.6), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .opacity(glowOpacity)

            // Achievement badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "star.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .scaleEffect(badgeScale)
            .rotationEffect(.degrees(badgeRotation))

            // Achievement text
            VStack(spacing: 8) {
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)

                Text(achievement)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: 100 + textOffset)
            .opacity(textOpacity)
        }
        .onAppear {
            if isAnimating {
                startAchievementAnimation()
            }
        }
    }

    private func startAchievementAnimation() {
        // Badge entrance with spring
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
            badgeScale = 1.2
        }

        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15).delay(0.2)) {
            badgeScale = 1.0
        }

        // Glow and rays appear
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            glowOpacity = 1.0
        }

        // Continuous ray rotation
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false).delay(0.3)) {
            rayRotation = 360
        }

        // Text slides up
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5)) {
            textOffset = 0
            textOpacity = 1.0
        }

        // Badge celebration wiggle
        withAnimation(.easeInOut(duration: 0.2).repeatCount(3, autoreverses: true).delay(1.0)) {
            badgeRotation = 5
        }
    }
}

// MARK: - Outfit Reveal Animation
public struct OutfitRevealView: View {
    @State private var revealProgress: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0
    @State private var sparklePhase: Double = 0

    let outfitImage: String
    let isAnimating: Bool

    public init(outfitImage: String, isAnimating: Bool = true) {
        self.outfitImage = outfitImage
        self.isAnimating = isAnimating
    }

    public var body: some View {
        ZStack {
            // Outfit image
            Image(outfitImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .scaleEffect(scale)
                .opacity(opacity)
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: revealProgress),
                                    .init(color: .black, location: min(revealProgress + 0.1, 1))
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    // Shimmer effect
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(45))
                        .offset(x: shimmerOffset)
                        .blendMode(.overlay)
                )
                .overlay(
                    // Sparkle particles
                    ForEach(0..<10) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .offset(
                                x: sin(sparklePhase + Double(index) * 0.6) * 100,
                                y: cos(sparklePhase + Double(index) * 0.8) * 80
                            )
                            .opacity(sin(sparklePhase + Double(index)) * 0.5 + 0.5)
                    }
                )
        }
        .onAppear {
            if isAnimating {
                startRevealAnimation()
            }
        }
    }

    private func startRevealAnimation() {
        // Initial setup
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            opacity = 1.0
            scale = 1.0
        }

        // Progressive reveal
        withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
            revealProgress = 1.0
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.8).delay(0.8)) {
            shimmerOffset = 200
        }

        // Sparkle animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false).delay(1.0)) {
            sparklePhase = 2 * .pi
        }
    }
}

// MARK: - View Extensions
public extension View {
    func heroAnimation(_ type: HeroAnimationType) -> some View {
        self.onAppear {
            HeroAnimationSystem.shared.playHeroAnimation(type)
        }
    }

    func celebration(_ type: CelebrationType, at position: CGPoint = CGPoint(x: 200, y: 400)) -> some View {
        self.background(
            CelebrationOverlay(type: type, position: position)
                .allowsHitTesting(false)
        )
    }

    func appLaunchAnimation() -> some View {
        self.overlay(
            Logo3DView(isAnimating: true)
                .allowsHitTesting(false),
            alignment: .center
        )
    }

    func onboardingParallax(title: String, subtitle: String) -> some View {
        self.background(
            OnboardingParallaxView(title: title, subtitle: subtitle)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Celebration Overlay
struct CelebrationOverlay: View {
    let type: CelebrationType
    let position: CGPoint
    @State private var particleSystem = ParticleSystem()

    var body: some View {
        ParticleView(particleSystem: particleSystem)
            .onAppear {
                particleSystem.burst(at: position, with: type.particleBurst)
            }
    }
}

// MARK: - Custom Color Extensions
extension Color {
    static let gold = Color(red: 1.0, green: 0.843, blue: 0.0)
    static let silver = Color(red: 0.753, green: 0.753, blue: 0.753)
    static let rose = Color(red: 1.0, green: 0.753, blue: 0.796)
    static let platinum = Color(red: 0.898, green: 0.898, blue: 0.898)
    static let lime = Color(red: 0.196, green: 0.804, blue: 0.196)
}

// MARK: - Custom Particle Shapes
extension ParticleShape {
    static let heart = ParticleShape.custom("heart.fill")
    static let trophy = ParticleShape.custom("trophy.fill")
    static let checkmark = ParticleShape.custom("checkmark.circle.fill")
}