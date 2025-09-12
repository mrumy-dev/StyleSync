import SwiftUI
import Combine

// MARK: - Particle System
public class ParticleSystem: ObservableObject {
    @Published public var particles: [Particle] = []
    
    private var timer: Timer?
    private var emitters: [ParticleEmitter] = []
    private let maxParticles: Int
    
    public init(maxParticles: Int = 500) {
        self.maxParticles = maxParticles
        startUpdate()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startUpdate() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateParticles()
        }
    }
    
    public func addEmitter(_ emitter: ParticleEmitter) {
        emitters.append(emitter)
    }
    
    public func removeEmitter(_ emitter: ParticleEmitter) {
        emitters.removeAll { $0.id == emitter.id }
    }
    
    public func removeAllEmitters() {
        emitters.removeAll()
    }
    
    private func updateParticles() {
        let deltaTime = 1.0/60.0
        
        // Update existing particles
        particles = particles.compactMap { particle in
            var updatedParticle = particle
            updatedParticle.update(deltaTime: deltaTime)
            return updatedParticle.isAlive ? updatedParticle : nil
        }
        
        // Emit new particles
        for emitter in emitters {
            if emitter.isActive {
                let newParticles = emitter.emit()
                particles.append(contentsOf: newParticles)
            }
        }
        
        // Limit particle count
        if particles.count > maxParticles {
            particles = Array(particles.suffix(maxParticles))
        }
    }
    
    public func burst(at position: CGPoint, with config: BurstConfig) {
        let burst = BurstEmitter(position: position, config: config)
        let newParticles = burst.emit()
        particles.append(contentsOf: newParticles)
    }
    
    public func clear() {
        particles.removeAll()
    }
}

// MARK: - Particle
public struct Particle: Identifiable {
    public let id = UUID()
    public var position: CGPoint
    public var velocity: CGPoint
    public var acceleration: CGPoint
    public var life: Double
    public var maxLife: Double
    public var size: CGFloat
    public var color: Color
    public var alpha: Double
    public var rotation: Double
    public var rotationSpeed: Double
    public var scale: Double
    public var shape: ParticleShape
    
    public var isAlive: Bool {
        life > 0
    }
    
    public var normalizedLife: Double {
        life / maxLife
    }
    
    public mutating func update(deltaTime: Double) {
        // Update physics
        velocity.x += acceleration.x * deltaTime
        velocity.y += acceleration.y * deltaTime
        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime
        
        // Update rotation
        rotation += rotationSpeed * deltaTime
        
        // Update life
        life -= deltaTime
        
        // Update visual properties based on life
        alpha = normalizedLife
        scale = 0.5 + normalizedLife * 0.5
    }
}

public enum ParticleShape: CaseIterable {
    case circle
    case square
    case triangle
    case star
    case diamond
    case heart
    case leaf
    case sparkle
    case custom(String)
    
    @ViewBuilder
    public func view(size: CGFloat, color: Color, alpha: Double, rotation: Double, scale: Double) -> some View {
        Group {
            switch self {
            case .circle:
                Circle()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    
            case .square:
                Rectangle()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .triangle:
                TriangleShape()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .star:
                StarShape()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .diamond:
                DiamondShape()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .heart:
                HeartShape()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .leaf:
                LeafShape()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .sparkle:
                SparkleShape()
                    .fill(color.opacity(alpha))
                    .frame(width: size * scale, height: size * scale)
                    .rotationEffect(.degrees(rotation))
                    
            case .custom(let systemName):
                Image(systemName: systemName)
                    .foregroundColor(color.opacity(alpha))
                    .font(.system(size: size * scale))
                    .rotationEffect(.degrees(rotation))
            }
        }
    }
}

// MARK: - Particle Emitters
public class ParticleEmitter: ObservableObject, Identifiable {
    public let id = UUID()
    public var position: CGPoint
    public var isActive: Bool = true
    public let config: EmitterConfig
    
    private var lastEmitTime: Date = Date()
    
    public init(position: CGPoint, config: EmitterConfig) {
        self.position = position
        self.config = config
    }
    
    public func emit() -> [Particle] {
        let now = Date()
        let timeSinceLastEmit = now.timeIntervalSince(lastEmitTime)
        let particlesToEmit = Int(timeSinceLastEmit * config.emissionRate)
        
        if particlesToEmit > 0 {
            lastEmitTime = now
            return createParticles(count: particlesToEmit)
        }
        
        return []
    }
    
    private func createParticles(count: Int) -> [Particle] {
        return (0..<count).map { _ in createParticle() }
    }
    
    private func createParticle() -> Particle {
        let angle = Double.random(in: config.angleRange)
        let speed = Double.random(in: config.speedRange)
        let velocity = CGPoint(
            x: cos(angle) * speed,
            y: sin(angle) * speed
        )
        
        return Particle(
            position: position + CGPoint(
                x: Double.random(in: -config.spawnRadius...config.spawnRadius),
                y: Double.random(in: -config.spawnRadius...config.spawnRadius)
            ),
            velocity: velocity,
            acceleration: config.gravity,
            life: Double.random(in: config.lifetimeRange),
            maxLife: config.lifetimeRange.upperBound,
            size: CGFloat.random(in: config.sizeRange),
            color: config.colors.randomElement() ?? .white,
            alpha: 1.0,
            rotation: Double.random(in: 0...(2 * .pi)),
            rotationSpeed: Double.random(in: config.rotationSpeedRange),
            scale: 1.0,
            shape: config.shapes.randomElement() ?? .circle
        )
    }
}

public struct EmitterConfig {
    public let emissionRate: Double // particles per second
    public let spawnRadius: Double
    public let angleRange: ClosedRange<Double> // in radians
    public let speedRange: ClosedRange<Double>
    public let lifetimeRange: ClosedRange<Double>
    public let sizeRange: ClosedRange<CGFloat>
    public let rotationSpeedRange: ClosedRange<Double>
    public let gravity: CGPoint
    public let colors: [Color]
    public let shapes: [ParticleShape]
    
    public init(
        emissionRate: Double = 30,
        spawnRadius: Double = 10,
        angleRange: ClosedRange<Double> = 0...(2 * .pi),
        speedRange: ClosedRange<Double> = 50...150,
        lifetimeRange: ClosedRange<Double> = 1.0...3.0,
        sizeRange: ClosedRange<CGFloat> = 4...12,
        rotationSpeedRange: ClosedRange<Double> = -180...180,
        gravity: CGPoint = CGPoint(x: 0, y: 100),
        colors: [Color] = [.white, .blue, .purple],
        shapes: [ParticleShape] = [.circle]
    ) {
        self.emissionRate = emissionRate
        self.spawnRadius = spawnRadius
        self.angleRange = angleRange
        self.speedRange = speedRange
        self.lifetimeRange = lifetimeRange
        self.sizeRange = sizeRange
        self.rotationSpeedRange = rotationSpeedRange
        self.gravity = gravity
        self.colors = colors
        self.shapes = shapes
    }
}

// MARK: - Burst Emitter
public class BurstEmitter {
    public let position: CGPoint
    public let config: BurstConfig
    
    public init(position: CGPoint, config: BurstConfig) {
        self.position = position
        self.config = config
    }
    
    public func emit() -> [Particle] {
        return createParticles(count: config.particleCount)
    }
    
    private func createParticles(count: Int) -> [Particle] {
        return (0..<count).map { index in
            let normalizedIndex = Double(index) / Double(count)
            let angle = config.startAngle + (config.spreadAngle * normalizedIndex)
            let speed = Double.random(in: config.speedRange)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed
            )
            
            return Particle(
                position: position,
                velocity: velocity,
                acceleration: config.gravity,
                life: Double.random(in: config.lifetimeRange),
                maxLife: config.lifetimeRange.upperBound,
                size: CGFloat.random(in: config.sizeRange),
                color: config.colors.randomElement() ?? .white,
                alpha: 1.0,
                rotation: angle,
                rotationSpeed: Double.random(in: config.rotationSpeedRange),
                scale: 1.0,
                shape: config.shapes.randomElement() ?? .circle
            )
        }
    }
}

public struct BurstConfig {
    public let particleCount: Int
    public let startAngle: Double
    public let spreadAngle: Double
    public let speedRange: ClosedRange<Double>
    public let lifetimeRange: ClosedRange<Double>
    public let sizeRange: ClosedRange<CGFloat>
    public let rotationSpeedRange: ClosedRange<Double>
    public let gravity: CGPoint
    public let colors: [Color]
    public let shapes: [ParticleShape]
    
    public init(
        particleCount: Int = 20,
        startAngle: Double = 0,
        spreadAngle: Double = 2 * .pi,
        speedRange: ClosedRange<Double> = 100...200,
        lifetimeRange: ClosedRange<Double> = 1.0...2.0,
        sizeRange: ClosedRange<CGFloat> = 6...16,
        rotationSpeedRange: ClosedRange<Double> = -360...360,
        gravity: CGPoint = CGPoint(x: 0, y: 200),
        colors: [Color] = [.yellow, .orange, .red],
        shapes: [ParticleShape] = [.star, .circle]
    ) {
        self.particleCount = particleCount
        self.startAngle = startAngle
        self.spreadAngle = spreadAngle
        self.speedRange = speedRange
        self.lifetimeRange = lifetimeRange
        self.sizeRange = sizeRange
        self.rotationSpeedRange = rotationSpeedRange
        self.gravity = gravity
        self.colors = colors
        self.shapes = shapes
    }
}

// MARK: - Particle View
public struct ParticleView: View {
    @ObservedObject private var particleSystem: ParticleSystem
    
    public init(particleSystem: ParticleSystem) {
        self.particleSystem = particleSystem
    }
    
    public var body: some View {
        Canvas { context, size in
            for particle in particleSystem.particles {
                let position = particle.position
                
                // Ensure particle is within bounds
                guard position.x >= 0 && position.x <= size.width &&
                      position.y >= 0 && position.y <= size.height else {
                    continue
                }
                
                // Create particle view
                let particleView = particle.shape.view(
                    size: particle.size,
                    color: particle.color,
                    alpha: particle.alpha,
                    rotation: particle.rotation,
                    scale: particle.scale
                )
                
                context.translateBy(x: position.x, y: position.y)
                context.draw(particleView, at: .zero)
                context.translateBy(x: -position.x, y: -position.y)
            }
        }
    }
}

// MARK: - Particle Shapes
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5
        
        for i in 0..<points * 2 {
            let angle = Double(i) * .pi / Double(points)
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle - .pi/2)) * radius
            let y = center.y + CGFloat(sin(angle - .pi/2)) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.25))
        path.addCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.25),
            control1: CGPoint(x: width * 0.5, y: height * 0.125),
            control2: CGPoint(x: width * 0.1, y: height * 0.125)
        )
        path.addArc(
            center: CGPoint(x: width * 0.1, y: height * 0.25),
            radius: width * 0.1,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: width * 0.4, y: height * 0.25),
            radius: width * 0.1,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.75),
            control1: CGPoint(x: width * 0.4, y: height * 0.375),
            control2: CGPoint(x: width * 0.5, y: height * 0.625)
        )
        path.closeSubpath()
        
        return path
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        
        return path
    }
}

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let length = i.isMultiple(of: 2) ? radius : radius * 0.3
            let endX = center.x + CGFloat(cos(angle)) * length
            let endY = center.y + CGFloat(sin(angle)) * length
            
            path.move(to: center)
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        
        return path
    }
}

// MARK: - Extensions
extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}