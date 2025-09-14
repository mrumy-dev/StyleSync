import SwiftUI

struct AccessibilityEnhancedView: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits

    init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

struct CustomAlert: View {
    let title: String
    let message: String
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(ProMotionAnimations.quickBounce) {
                        isPresented = false
                    }
                }

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        primaryButton.action()
                        isPresented = false
                    }) {
                        Text(primaryButton.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(primaryButton.style.backgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let secondary = secondaryButton {
                        Button(action: {
                            secondary.action()
                            isPresented = false
                        }) {
                            Text(secondary.title)
                                .fontWeight(.medium)
                                .foregroundColor(secondary.style.textColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(secondary.style.backgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0)
        }
        .animation(ProMotionAnimations.gentleSpring, value: isPresented)
    }
}

struct AlertButton {
    let title: String
    let style: AlertButtonStyle
    let action: () -> Void
}

enum AlertButtonStyle {
    case primary
    case secondary
    case destructive

    var backgroundColor: Color {
        switch self {
        case .primary: return .blue
        case .secondary: return .gray.opacity(0.1)
        case .destructive: return .red
        }
    }

    var textColor: Color {
        switch self {
        case .primary, .destructive: return .white
        case .secondary: return .primary
        }
    }
}

struct AchievementAnimation: View {
    @State private var isPresented = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    @State private var sparkleOpacity: Double = 0

    let achievement: Achievement
    @Binding var showAchievement: Bool

    var body: some View {
        ZStack {
            if showAchievement {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [achievement.color.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(scale)

                        Image(systemName: achievement.icon)
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(achievement.color)
                            .rotationEffect(.degrees(rotation))
                            .scaleEffect(scale)

                        ForEach(0..<8, id: \.self) { index in
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .opacity(sparkleOpacity)
                                .offset(
                                    x: cos(Double(index) * .pi / 4) * 80,
                                    y: sin(Double(index) * .pi / 4) * 80
                                )
                                .animation(
                                    .easeOut(duration: 0.6)
                                        .delay(Double(index) * 0.1),
                                    value: sparkleOpacity
                                )
                        }
                    }

                    VStack(spacing: 12) {
                        Text("Achievement Unlocked!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(achievement.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(achievement.color)

                        Text(achievement.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal)
                    }
                    .scaleEffect(scale)

                    Button("Continue") {
                        dismissAchievement()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .scaleEffect(scale)
                }
            }
        }
        .onAppear {
            if showAchievement {
                presentAchievement()
            }
        }
        .onChange(of: showAchievement) { newValue in
            if newValue {
                presentAchievement()
            }
        }
    }

    private func presentAchievement() {
        withAnimation(ProMotionAnimations.quickBounce.delay(0.3)) {
            scale = 1.0
        }

        withAnimation(.linear(duration: 2).delay(0.5)) {
            rotation = 360
        }

        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            sparkleOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if showAchievement {
                dismissAchievement()
            }
        }
    }

    private func dismissAchievement() {
        withAnimation(ProMotionAnimations.gentleSpring) {
            scale = 0.5
            sparkleOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showAchievement = false
        }
    }
}

struct Achievement {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct LaunchScreenAnimation: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = 0
    @State private var textOpacity: Double = 0
    @State private var backgroundGradient: [Color] = [.blue.opacity(0.1), .purple.opacity(0.1)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 80, weight: .ultraLight))
                        .foregroundColor(.blue)
                        .scaleEffect(logoScale)
                        .rotationEffect(.degrees(logoRotation))

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                }

                VStack(spacing: 8) {
                    Text("StyleSync")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .opacity(textOpacity)

                    Text("Your AI Style Assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        withAnimation(ProMotionAnimations.gentleSpring.delay(0.2)) {
            logoScale = 1.0
        }

        withAnimation(.linear(duration: 3).delay(0.5)) {
            logoRotation = 360
        }

        withAnimation(ProMotionAnimations.silk.delay(0.8)) {
            textOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 2).delay(1.0)) {
            backgroundGradient = [.blue.opacity(0.3), .purple.opacity(0.3)]
        }
    }
}

struct OnboardingIllustration: View {
    let step: OnboardingStep
    @State private var animationOffset: CGFloat = 0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                step.color.opacity(0.1),
                                step.color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)

                VStack(spacing: 16) {
                    Image(systemName: step.icon)
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(step.color)
                        .offset(y: animationOffset)
                        .scaleEffect(scale)

                    illustrationElements(for: step)
                }
            }

            VStack(spacing: 12) {
                Text(step.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            withAnimation(ProMotionAnimations.gentleSpring.delay(0.2)) {
                scale = 1.0
            }

            withAnimation(
                .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                    .delay(0.5)
            ) {
                animationOffset = -8
            }
        }
    }

    @ViewBuilder
    private func illustrationElements(for step: OnboardingStep) -> some View {
        switch step.type {
        case .welcome:
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(step.color.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(scale)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: scale
                        )
                }
            }

        case .wardrobe:
            HStack(spacing: 6) {
                Image(systemName: "tshirt")
                    .foregroundColor(step.color.opacity(0.6))
                Image(systemName: "rectangle")
                    .foregroundColor(step.color.opacity(0.4))
                Image(systemName: "shoe")
                    .foregroundColor(step.color.opacity(0.6))
            }
            .font(.title3)

        case .ai:
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(step.color.opacity(0.4))
                        .frame(width: 3, height: CGFloat.random(in: 8...16))
                        .scaleEffect(scale)
                        .animation(
                            .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: scale
                        )
                }
            }

        case .personalization:
            Circle()
                .stroke(step.color.opacity(0.3), lineWidth: 3)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .fill(step.color)
                        .frame(width: 8, height: 8)
                        .offset(y: -16)
                        .rotationEffect(.degrees(animationOffset * 10))
                )
        }
    }
}

enum OnboardingStepType {
    case welcome
    case wardrobe
    case ai
    case personalization
}

struct OnboardingStep {
    let type: OnboardingStepType
    let title: String
    let description: String
    let icon: String
    let color: Color
}

extension View {
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(AccessibilityEnhancedView(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        ))
    }
}

struct PremiumPolishShowcase: View {
    @State private var showAlert = false
    @State private var showAchievement = false
    @State private var selectedDemo = 0

    private let sampleAchievement = Achievement(
        id: "first_outfit",
        title: "Style Pioneer",
        description: "You've created your first outfit! Your style journey begins now.",
        icon: "star.fill",
        color: .yellow
    )

    var body: some View {
        VStack(spacing: 20) {
            Picker("Demo", selection: $selectedDemo) {
                Text("Alerts").tag(0)
                Text("Achievements").tag(1)
                Text("Launch Screen").tag(2)
                Text("Onboarding").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())

            ScrollView {
                Group {
                    switch selectedDemo {
                    case 0:
                        Button("Show Custom Alert") {
                            showAlert = true
                        }
                        .buttonStyle(.borderedProminent)

                    case 1:
                        Button("Unlock Achievement") {
                            showAchievement = true
                        }
                        .buttonStyle(.borderedProminent)

                    case 2:
                        LaunchScreenAnimation()
                            .frame(height: 400)

                    case 3:
                        OnboardingIllustration(
                            step: OnboardingStep(
                                type: .welcome,
                                title: "Welcome to StyleSync",
                                description: "Your personal AI stylist is ready to help you discover amazing outfits.",
                                icon: "sparkles",
                                color: .blue
                            )
                        )

                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .overlay(
            Group {
                if showAlert {
                    CustomAlert(
                        title: "Upgrade to Premium",
                        message: "Unlock unlimited style recommendations and exclusive features.",
                        primaryButton: AlertButton(
                            title: "Upgrade Now",
                            style: .primary,
                            action: {}
                        ),
                        secondaryButton: AlertButton(
                            title: "Maybe Later",
                            style: .secondary,
                            action: {}
                        ),
                        isPresented: $showAlert
                    )
                }

                if showAchievement {
                    AchievementAnimation(
                        achievement: sampleAchievement,
                        showAchievement: $showAchievement
                    )
                }
            }
        )
    }
}