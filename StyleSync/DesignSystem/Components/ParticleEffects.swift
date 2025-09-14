import SwiftUI

// MARK: - Particle Effect System

struct ParticleEffect: View {
    let particleCount: Int
    let colors: [Color]
    let duration: Double
    let isActive: Bool
    
    @State private var particles: [Particle] = []
    
    init(
        particleCount: Int = 50,
        colors: [Color] = [.yellow, .orange, .red, .pink],
        duration: Double = 2.0,
        isActive: Bool = true
    ) {
        self.particleCount = particleCount
        self.colors = colors
        self.duration = duration
        self.isActive = isActive
    }
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onAppear {
            if isActive {
                generateParticles()
                animateParticles()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                generateParticles()
                animateParticles()
            }
        }
    }
    
    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(x: 200, y: 200),
                velocity: CGPoint(
                    x: Double.random(in: -100...100),
                    y: Double.random(in: -100...100)
                ),
                color: colors.randomElement() ?? .yellow,
                size: Double.random(in: 4...12),
                opacity: 1.0,
                scale: 1.0
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: duration)) {
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                particles[i].opacity = 0
                particles[i].scale = 0.5
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            particles.removeAll()
        }
    }
}

struct Particle {
    let id = UUID()
    var position: CGPoint
    let velocity: CGPoint
    let color: Color
    let size: Double
    var opacity: Double
    var scale: Double
}

// MARK: - Celebration Effects

struct CelebrationEffect: View {
    let type: CelebrationType
    let isActive: Bool
    
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var explosionScale: CGFloat = 0
    
    enum CelebrationType {
        case confetti, fireworks, hearts, stars
        
        var particleCount: Int {
            switch self {
            case .confetti: return 80
            case .fireworks: return 60
            case .hearts: return 20
            case .stars: return 40
            }
        }
        
        var colors: [Color] {
            switch self {
            case .confetti: return [.red, .blue, .green, .yellow, .purple, .pink]
            case .fireworks: return [.red, .orange, .yellow, .white]
            case .hearts: return [.red, .pink, .purple]
            case .stars: return [.yellow, .white, .cyan]
            }
        }
        
        var shapes: [String] {
            switch self {
            case .confetti: return ["rectangle.fill", "circle.fill", "triangle.fill"]
            case .fireworks: return ["sparkle", "star.fill", "circle.fill"]
            case .hearts: return ["heart.fill", "heart"]
            case .stars: return ["star.fill", "sparkle"]
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiParticles, id: \.id) { particle in
                    Image(systemName: particle.shape)
                        .foregroundStyle(particle.color)
                        .font(.system(size: particle.size))
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .scaleEffect(particle.scale)
                        .rotationEffect(.degrees(particle.rotation))
                }
            }
            .onAppear {
                if isActive {
                    triggerCelebration(in: geometry.frame(in: .local))
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    triggerCelebration(in: geometry.frame(in: .local))
                }
            }
        }
    }
    
    private func triggerCelebration(in frame: CGRect) {
        generateConfetti(in: frame)
        animateConfetti()
        
        HapticManager.HapticType.success.trigger()
        SoundManager.SoundType.success.play(volume: 0.8)
    }
    
    private func generateConfetti(in frame: CGRect) {
        confettiParticles = (0..<type.particleCount).map { _ in
            ConfettiParticle(
                position: CGPoint(
                    x: frame.midX + Double.random(in: -50...50),
                    y: frame.midY
                ),
                velocity: CGPoint(
                    x: Double.random(in: -200...200),
                    y: Double.random(in: -300...-100)
                ),
                color: type.colors.randomElement() ?? .yellow,
                size: Double.random(in: 12...24),
                shape: type.shapes.randomElement() ?? "circle.fill",
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -360...360),
                opacity: 1.0,
                scale: 1.0
            )
        }
    }
    
    private func animateConfetti() {
        let gravity: CGFloat = 500
        let duration: Double = 3.0
        
        withAnimation(.linear(duration: duration)) {
            for i in confettiParticles.indices {
                confettiParticles[i].position.x += confettiParticles[i].velocity.x * duration
                confettiParticles[i].position.y += confettiParticles[i].velocity.y * duration + gravity * duration * duration / 2
                confettiParticles[i].rotation += confettiParticles[i].rotationSpeed * duration
                confettiParticles[i].opacity = 0
                confettiParticles[i].scale = 0.3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            confettiParticles.removeAll()
        }
    }
}

struct ConfettiParticle {
    let id = UUID()
    var position: CGPoint
    let velocity: CGPoint
    let color: Color
    let size: Double
    let shape: String
    var rotation: Double
    let rotationSpeed: Double
    var opacity: Double
    var scale: Double
}

// MARK: - Magic Sparkle Effect

struct MagicSparkleEffect: View {
    let isActive: Bool
    @State private var sparkles: [Sparkle] = []
    
    var body: some View {
        ZStack {
            ForEach(sparkles, id: \.id) { sparkle in
                Image(systemName: "sparkle")
                    .foregroundStyle(sparkle.color.opacity(sparkle.opacity))
                    .font(.system(size: sparkle.size))
                    .position(sparkle.position)
                    .scaleEffect(sparkle.scale)
                    .rotationEffect(.degrees(sparkle.rotation))
            }
        }
        .onAppear {
            if isActive {
                generateSparkles()
                animateSparkles()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                generateSparkles()
                animateSparkles()
            }
        }
    }
    
    private func generateSparkles() {
        sparkles = (0..<20).map { _ in
            Sparkle(
                position: CGPoint(
                    x: Double.random(in: 0...400),
                    y: Double.random(in: 0...400)
                ),
                color: [Color.yellow, Color.white, Color.cyan].randomElement() ?? .yellow,
                size: Double.random(in: 8...16),
                scale: 0,
                rotation: 0,
                opacity: 0
            )
        }
    }
    
    private func animateSparkles() {
        for (index, _) in sparkles.enumerated() {
            let delay = Double(index) * 0.1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    sparkles[index].scale = 1.0
                    sparkles[index].opacity = 1.0
                    sparkles[index].rotation = 360
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        sparkles[index].scale = 0
                        sparkles[index].opacity = 0
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            sparkles.removeAll()
        }
    }
}

struct Sparkle {
    let id = UUID()
    let position: CGPoint
    let color: Color
    let size: Double
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
}

// MARK: - Extensions

extension View {
    func celebrationEffect(type: CelebrationEffect.CelebrationType, isActive: Bool) -> some View {
        overlay(
            CelebrationEffect(type: type, isActive: isActive)
        )
    }
    
    func magicSparkles(isActive: Bool) -> some View {
        overlay(
            MagicSparkleEffect(isActive: isActive)
        )
    }
    
    func particleExplosion(
        particleCount: Int = 50,
        colors: [Color] = [.yellow, .orange, .red],
        isActive: Bool
    ) -> some View {
        overlay(
            ParticleEffect(
                particleCount: particleCount,
                colors: colors,
                isActive: isActive
            )
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 40) {
            Text("Particle Effects")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            
            Button("Confetti!") {}
                .padding()
                .background(DesignSystem.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .celebrationEffect(type: .confetti, isActive: true)
            
            Button("Sparkles!") {}
                .padding()
                .background(DesignSystem.Colors.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .magicSparkles(isActive: true)
            
            Circle()
                .fill(DesignSystem.Colors.accent.gradient)
                .frame(width: 100, height: 100)
                .particleExplosion(isActive: true)
        }
    }
}