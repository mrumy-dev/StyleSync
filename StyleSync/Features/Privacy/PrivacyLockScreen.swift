import SwiftUI
import LocalAuthentication

struct PrivacyLockScreen: View {
    @StateObject private var securityVault = SecurityVault.shared
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var authenticationAttempts = 0

    var body: some View {
        ZStack {
            // Dynamic background
            BackgroundGradient()

            VStack(spacing: 0) {
                Spacer()

                // Logo and Title
                VStack(spacing: 24) {
                    LogoAnimationView(isAnimating: $isAnimating)

                    VStack(spacing: 8) {
                        Text("StyleSync")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)

                        Text("Your style, secured")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                // Authentication Section
                VStack(spacing: 32) {
                    // Biometric Animation
                    BiometricAuthenticationView(
                        biometricType: securityVault.biometricType,
                        authState: securityVault.authenticationState,
                        pulseScale: $pulseScale,
                        glowOpacity: $glowOpacity
                    ) {
                        authenticateUser()
                    }

                    // Status Message
                    AuthenticationStatusView(
                        authState: securityVault.authenticationState,
                        errorMessage: errorMessage,
                        showingError: showingError
                    )

                    // Alternative Authentication
                    if securityVault.biometricType != .none {
                        AlternativeAuthButton {
                            authenticateWithPasscode()
                        }
                    }
                }
                .padding(.bottom, 60)
            }
            .padding()

            // Panic Mode Overlay
            if securityVault.authenticationState == .panicMode {
                PanicModeOverlay()
            }

            // Processing Overlay
            if securityVault.authenticationState == .authenticating {
                AuthenticatingOverlay()
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: securityVault.authenticationState) { state in
            handleAuthenticationStateChange(state)
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            isAnimating = true
            glowOpacity = 0.8
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }

    private func authenticateUser() {
        Task {
            do {
                try await securityVault.authenticateUser()
            } catch {
                handleAuthenticationError(error)
            }
        }
    }

    private func authenticateWithPasscode() {
        // Trigger passcode authentication
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enter passcode to unlock StyleSync") { success, error in
            DispatchQueue.main.async {
                if success {
                    securityVault.isUnlocked = true
                    securityVault.authenticationState = .unlocked
                } else if let error = error {
                    handleAuthenticationError(error)
                }
            }
        }
    }

    private func handleAuthenticationStateChange(_ state: SecurityVault.AuthenticationState) {
        switch state {
        case .failed(let error):
            handleAuthenticationError(error)
        case .unlocked:
            HapticManager.HapticType.success.trigger()
            SoundManager.SoundType.success.play(volume: 0.7)
        case .panicMode:
            HapticManager.HapticType.error.trigger()
            SoundManager.SoundType.error.play(volume: 1.0)
        default:
            break
        }
    }

    private func handleAuthenticationError(_ error: Error) {
        authenticationAttempts += 1
        errorMessage = error.localizedDescription
        showingError = true

        withAnimation(.easeInOut(duration: 0.3)) {
            // Shake animation for error
        }

        HapticManager.HapticType.error.trigger()
        SoundManager.SoundType.error.play(volume: 0.6)

        // Clear error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showingError = false
            errorMessage = ""
        }

        // Implement security delay after multiple failed attempts
        if authenticationAttempts >= 3 {
            implementSecurityDelay()
        }
    }

    private func implementSecurityDelay() {
        // Exponential backoff for security
        let delay = min(pow(2.0, Double(authenticationAttempts - 3)), 30.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            authenticationAttempts = max(0, authenticationAttempts - 1)
        }
    }
}

// MARK: - Background Components

struct BackgroundGradient: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.2, green: 0.1, blue: 0.3),
                Color(red: 0.1, green: 0.2, blue: 0.4)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
        .overlay(
            // Animated particles
            ParticleField()
                .opacity(0.3)
        )
    }
}

struct ParticleField: View {
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var scale: CGFloat
        var opacity: Double
    }

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let rect = CGRect(
                    x: particle.position.x - particle.scale / 2,
                    y: particle.position.y - particle.scale / 2,
                    width: particle.scale,
                    height: particle.scale
                )

                context.opacity = particle.opacity
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .onAppear {
            generateParticles()
            animateParticles()
        }
    }

    private func generateParticles() {
        particles = (0..<50).map { _ in
            Particle(
                position: CGPoint(
                    x: Double.random(in: 0...UIScreen.main.bounds.width),
                    y: Double.random(in: 0...UIScreen.main.bounds.height)
                ),
                velocity: CGPoint(
                    x: Double.random(in: -1...1),
                    y: Double.random(in: -2...0)
                ),
                scale: Double.random(in: 1...3),
                opacity: Double.random(in: 0.1...0.5)
            )
        }
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y

                // Reset particle if it goes off screen
                if particles[i].position.y < -10 {
                    particles[i].position.y = UIScreen.main.bounds.height + 10
                    particles[i].position.x = Double.random(in: 0...UIScreen.main.bounds.width)
                }
            }
        }
    }
}

// MARK: - Logo Animation

struct LogoAnimationView: View {
    @Binding var isAnimating: Bool
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .cyan.opacity(0.6), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(rotation))

            // Inner logo
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .cyan.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }
}

// MARK: - Biometric Authentication View

struct BiometricAuthenticationView: View {
    let biometricType: SecurityVault.BiometricType
    let authState: SecurityVault.AuthenticationState
    @Binding var pulseScale: CGFloat
    @Binding var glowOpacity: Double
    let onAuthenticate: () -> Void

    var body: some View {
        Button(action: onAuthenticate) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [biometricColor.opacity(glowOpacity), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                // Main button
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .strokeBorder(biometricColor, lineWidth: 2)
                    )

                // Icon
                Image(systemName: biometricType.icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(biometricColor)
            }
        }
        .disabled(authState == .authenticating)
        .scaleEffect(authState == .authenticating ? 0.95 : 1.0)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: authState)
    }

    private var biometricColor: Color {
        switch authState {
        case .failed:
            return .red
        case .unlocked:
            return .green
        case .panicMode:
            return .red
        default:
            return .cyan
        }
    }
}

// MARK: - Authentication Status View

struct AuthenticationStatusView: View {
    let authState: SecurityVault.AuthenticationState
    let errorMessage: String
    let showingError: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(statusTitle)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)

            Text(statusSubtitle)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            if showingError {
                Text(errorMessage)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingError)
    }

    private var statusTitle: String {
        switch authState {
        case .locked:
            return "Unlock StyleSync"
        case .authenticating:
            return "Authenticating..."
        case .unlocked:
            return "Welcome Back!"
        case .failed:
            return "Authentication Failed"
        case .panicMode:
            return "Security Alert"
        }
    }

    private var statusSubtitle: String {
        switch authState {
        case .locked:
            return "Use \(SecurityVault.shared.biometricType.displayName) or passcode"
        case .authenticating:
            return "Please wait..."
        case .unlocked:
            return "Access granted"
        case .failed:
            return "Please try again"
        case .panicMode:
            return "Enhanced security mode active"
        }
    }

    private var statusColor: Color {
        switch authState {
        case .locked, .authenticating:
            return .white
        case .unlocked:
            return .green
        case .failed, .panicMode:
            return .red
        }
    }
}

// MARK: - Alternative Authentication

struct AlternativeAuthButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 16, weight: .medium))

                Text("Use Passcode")
                    .font(DesignSystem.Typography.bodyMedium)
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Overlays

struct PanicModeOverlay: View {
    @State private var alertOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.red.opacity(0.3)
                .ignoresSafeArea()
                .opacity(alertOpacity)

            GlassCardView {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)

                    VStack(spacing: 8) {
                        Text("Security Alert")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Panic mode activated. Enhanced security measures are in effect.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Dismiss") {
                        // This would be handled by the security vault
                    }
                    .buttonStyle(PremiumButtonStyle(.accent))
                }
                .padding(24)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                alertOpacity = 0.8
            }
        }
    }
}

struct AuthenticatingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            GlassCardView {
                VStack(spacing: 16) {
                    ProMotionLoadingView()

                    Text("Authenticating...")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(24)
            }
        }
    }
}

#Preview {
    PrivacyLockScreen()
}