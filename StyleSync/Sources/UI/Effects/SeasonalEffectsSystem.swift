import SwiftUI
import Combine

// MARK: - Seasonal Effects System
public class SeasonalEffectsManager: ObservableObject {
    @Published public var currentSeason: Season = .getCurrentSeason()
    @Published public var activeEffects: Set<String> = []
    @Published public var weatherCondition: WeatherCondition = .clear
    @Published public var isHolidayTheme: Bool = false
    @Published public var currentHoliday: Holiday?

    private var effectTimers: [String: Timer] = []
    private var particleSystem = ParticleSystem()
    private var ambientSounds: [Season: String] = [:]

    public static let shared = SeasonalEffectsManager()

    private init() {
        setupSeasonalTracking()
    }

    public func activateSeasonalEffect(_ effect: SeasonalEffect) {
        let id = effect.id
        activeEffects.insert(id)

        // Configure particle system for effect
        configureParticleSystem(for: effect)

        // Auto-deactivate after duration if not persistent
        if !effect.isPersistent {
            effectTimers[id] = Timer.scheduledTimer(withTimeInterval: effect.duration, repeats: false) { [weak self] _ in
                self?.deactivateEffect(id)
            }
        }
    }

    public func deactivateEffect(_ id: String) {
        activeEffects.remove(id)
        effectTimers[id]?.invalidate()
        effectTimers.removeValue(forKey: id)
    }

    public func updateWeather(_ condition: WeatherCondition) {
        weatherCondition = condition
        activateWeatherEffects()
    }

    public func setHolidayTheme(_ holiday: Holiday?) {
        currentHoliday = holiday
        isHolidayTheme = holiday != nil
        if let holiday = holiday {
            activateHolidayEffects(holiday)
        }
    }

    private func setupSeasonalTracking() {
        // Check season periodically
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            let newSeason = Season.getCurrentSeason()
            if self?.currentSeason != newSeason {
                self?.currentSeason = newSeason
                self?.activateSeasonalEffects(newSeason)
            }
        }
    }

    private func configureParticleSystem(for effect: SeasonalEffect) {
        switch effect {
        case .snowfall(let intensity):
            particleSystem.addEmitter(createSnowEmitter(intensity: intensity))
        case .fallingLeaves(let colors):
            particleSystem.addEmitter(createLeavesEmitter(colors: colors))
        case .flowerPetals(let colors):
            particleSystem.addEmitter(createPetalsEmitter(colors: colors))
        case .sunRays:
            particleSystem.addEmitter(createSunRaysEmitter())
        case .rain(let intensity):
            particleSystem.addEmitter(createRainEmitter(intensity: intensity))
        case .fireworks:
            particleSystem.addEmitter(createFireworksEmitter())
        default:
            break
        }
    }

    private func activateSeasonalEffects(_ season: Season) {
        // Activate appropriate effects for season
        switch season {
        case .winter:
            activateSeasonalEffect(.snowfall(intensity: .medium))
            activateSeasonalEffect(.frostEffect)
        case .spring:
            activateSeasonalEffect(.flowerPetals(colors: [.pink, .white, .yellow]))
            activateSeasonalEffect(.freshGreenery)
        case .summer:
            activateSeasonalEffect(.sunRays)
            activateSeasonalEffect(.summerWarmth)
        case .autumn:
            activateSeasonalEffect(.fallingLeaves(colors: [.orange, .red, .yellow, .brown]))
            activateSeasonalEffect(.autumnColors)
        }
    }

    private func activateWeatherEffects() {
        // Clear existing weather effects
        let weatherEffectIds = ["rain", "snow", "storm", "fog"]
        weatherEffectIds.forEach { deactivateEffect($0) }

        // Activate current weather effect
        switch weatherCondition {
        case .rain:
            activateSeasonalEffect(.rain(intensity: .medium))
        case .snow:
            activateSeasonalEffect(.snowfall(intensity: .heavy))
        case .storm:
            activateSeasonalEffect(.storm)
        case .fog:
            activateSeasonalEffect(.fog)
        case .clear, .cloudy:
            break
        }
    }

    private func activateHolidayEffects(_ holiday: Holiday) {
        switch holiday {
        case .christmas:
            activateSeasonalEffect(.snowfall(intensity: .light))
            activateSeasonalEffect(.christmasLights)
        case .newYear:
            activateSeasonalEffect(.fireworks)
            activateSeasonalEffect(.confetti)
        case .halloween:
            activateSeasonalEffect(.spookyFog)
            activateSeasonalEffect(.fallingLeaves(colors: [.orange, .black]))
        case .valentine:
            activateSeasonalEffect(.floatingHearts)
        case .easter:
            activateSeasonalEffect(.flowerPetals(colors: [.pink, .purple, .yellow]))
        }
    }
}

// MARK: - Season Enum
public enum Season: CaseIterable {
    case spring, summer, autumn, winter

    public static func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .winter
        }
    }

    public var colors: [Color] {
        switch self {
        case .spring: return [.green, .mint, .pink, .yellow]
        case .summer: return [.yellow, .orange, .blue, .cyan]
        case .autumn: return [.orange, .red, .brown, .yellow]
        case .winter: return [.white, .blue, .gray, .cyan]
        }
    }

    public var primaryColor: Color {
        switch self {
        case .spring: return .green
        case .summer: return .yellow
        case .autumn: return .orange
        case .winter: return .blue
        }
    }
}

// MARK: - Weather Conditions
public enum WeatherCondition: CaseIterable {
    case clear, cloudy, rain, snow, storm, fog

    public var particleConfig: EmitterConfig? {
        switch self {
        case .rain:
            return EmitterConfig(
                emissionRate: 100,
                angleRange: (.pi * 0.4)...(.pi * 0.6),
                speedRange: 200...400,
                lifetimeRange: 2.0...4.0,
                sizeRange: 1...3,
                gravity: CGPoint(x: 20, y: 300),
                colors: [.blue.opacity(0.7), .cyan.opacity(0.5)],
                shapes: [.circle]
            )
        case .snow:
            return EmitterConfig(
                emissionRate: 50,
                angleRange: (.pi * 0.4)...(.pi * 0.6),
                speedRange: 30...80,
                lifetimeRange: 5.0...8.0,
                sizeRange: 2...8,
                rotationSpeedRange: -30...30,
                gravity: CGPoint(x: 10, y: 50),
                colors: [.white, .blue.opacity(0.3)],
                shapes: [.circle, .star]
            )
        default:
            return nil
        }
    }
}

// MARK: - Holidays
public enum Holiday: CaseIterable {
    case christmas, newYear, halloween, valentine, easter

    public var colors: [Color] {
        switch self {
        case .christmas: return [.red, .green, .gold, .silver]
        case .newYear: return [.gold, .silver, .purple, .blue]
        case .halloween: return [.orange, .black, .purple]
        case .valentine: return [.pink, .red, .purple]
        case .easter: return [.pink, .yellow, .green, .purple]
        }
    }
}

// MARK: - Seasonal Effects
public enum SeasonalEffect: CaseIterable {
    // Winter Effects
    case snowfall(intensity: ParticleIntensity)
    case frostEffect
    case icicles
    case christmasLights

    // Spring Effects
    case flowerPetals(colors: [Color])
    case freshGreenery
    case butterflies
    case beesBuzzing

    // Summer Effects
    case sunRays
    case summerWarmth
    case fireflies
    case summerBreeze

    // Autumn Effects
    case fallingLeaves(colors: [Color])
    case autumnColors
    case windGusts
    case harvestMoon

    // Weather Effects
    case rain(intensity: ParticleIntensity)
    case storm
    case fog
    case rainbow

    // Holiday Effects
    case fireworks
    case confetti
    case spookyFog
    case floatingHearts

    public var id: String {
        switch self {
        case .snowfall: return "snowfall"
        case .frostEffect: return "frostEffect"
        case .icicles: return "icicles"
        case .christmasLights: return "christmasLights"
        case .flowerPetals: return "flowerPetals"
        case .freshGreenery: return "freshGreenery"
        case .butterflies: return "butterflies"
        case .beesBuzzing: return "beesBuzzing"
        case .sunRays: return "sunRays"
        case .summerWarmth: return "summerWarmth"
        case .fireflies: return "fireflies"
        case .summerBreeze: return "summerBreeze"
        case .fallingLeaves: return "fallingLeaves"
        case .autumnColors: return "autumnColors"
        case .windGusts: return "windGusts"
        case .harvestMoon: return "harvestMoon"
        case .rain: return "rain"
        case .storm: return "storm"
        case .fog: return "fog"
        case .rainbow: return "rainbow"
        case .fireworks: return "fireworks"
        case .confetti: return "confetti"
        case .spookyFog: return "spookyFog"
        case .floatingHearts: return "floatingHearts"
        }
    }

    public var duration: Double {
        switch self {
        case .snowfall, .rain, .fallingLeaves, .flowerPetals: return .infinity
        case .fireworks: return 5.0
        case .confetti: return 3.0
        case .storm: return 10.0
        case .rainbow: return 8.0
        default: return .infinity
        }
    }

    public var isPersistent: Bool {
        switch self {
        case .snowfall, .rain, .fallingLeaves, .flowerPetals: return true
        case .frostEffect, .freshGreenery, .summerWarmth, .autumnColors: return true
        case .sunRays, .fog, .christmasLights: return true
        default: return false
        }
    }
}

public enum ParticleIntensity: CaseIterable {
    case light, medium, heavy

    public var emissionRate: Double {
        switch self {
        case .light: return 20
        case .medium: return 50
        case .heavy: return 100
        }
    }

    public var particleCount: Int {
        switch self {
        case .light: return 10
        case .medium: return 25
        case .heavy: return 50
        }
    }
}

// MARK: - Seasonal Effect Views
public struct SeasonalEffectOverlay: View {
    @StateObject private var effectsManager = SeasonalEffectsManager.shared
    let intensity: CGFloat

    public init(intensity: CGFloat = 1.0) {
        self.intensity = intensity
    }

    public var body: some View {
        ZStack {
            // Particle effects layer
            ParticleView(particleSystem: effectsManager.particleSystem)
                .allowsHitTesting(false)
                .opacity(intensity)

            // Ambient effects layer
            ambientEffectsLayer
                .allowsHitTesting(false)

            // Weather overlay
            weatherOverlay
                .allowsHitTesting(false)

            // Holiday decorations
            holidayDecorations
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var ambientEffectsLayer: some View {
        ZStack {
            // Seasonal color tinting
            Rectangle()
                .fill(effectsManager.currentSeason.primaryColor.opacity(0.05 * intensity))

            // Special ambient effects
            ForEach(Array(effectsManager.activeEffects), id: \.self) { effectId in
                ambientEffect(for: effectId)
            }
        }
    }

    @ViewBuilder
    private var weatherOverlay: some View {
        switch effectsManager.weatherCondition {
        case .fog:
            FogEffectView()
                .opacity(0.3 * intensity)
        case .storm:
            StormEffectView()
                .opacity(0.6 * intensity)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var holidayDecorations: some View {
        if let holiday = effectsManager.currentHoliday {
            holidayDecoration(for: holiday)
                .opacity(intensity)
        }
    }

    @ViewBuilder
    private func ambientEffect(for effectId: String) -> some View {
        switch effectId {
        case "sunRays":
            SunRaysView()
                .opacity(0.4 * intensity)
        case "frostEffect":
            FrostOverlayView()
                .opacity(0.2 * intensity)
        case "autumnColors":
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.1), .red.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case "summerWarmth":
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.yellow.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func holidayDecoration(for holiday: Holiday) -> some View {
        switch holiday {
        case .christmas:
            ChristmasLightsView()
        case .halloween:
            HalloweenDecorationView()
        case .valentine:
            FloatingHeartsView()
        default:
            EmptyView()
        }
    }
}

// MARK: - Specialized Effect Views
struct FogEffectView: View {
    @State private var fogOffset: CGFloat = -400
    @State private var fogOpacity: Double = 0.3

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.6), .gray.opacity(0.1), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 800, height: 100)
                    .offset(x: fogOffset + CGFloat(index * 200))
                    .blur(radius: 20 + CGFloat(index * 5))
                    .opacity(fogOpacity - Double(index) * 0.1)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                fogOffset = 400
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                fogOpacity = 0.6
            }
        }
    }
}

struct StormEffectView: View {
    @State private var flashOpacity: Double = 0
    @State private var thunderDelay: Double = 0

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .opacity(flashOpacity)
            .onAppear {
                simulateStorm()
            }
    }

    private func simulateStorm() {
        // Random lightning flashes
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 2...8), repeats: true) { _ in
            // Lightning flash
            withAnimation(.linear(duration: 0.1)) {
                flashOpacity = 0.8
            }
            withAnimation(.linear(duration: 0.3).delay(0.1)) {
                flashOpacity = 0
            }

            // Thunder (haptic feedback)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...2)) {
                HapticFeedbackSystem.shared.impact(.heavy)
            }
        }
    }
}

struct SunRaysView: View {
    @State private var rayRotation: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 200, height: 4)
                    .offset(x: 100)
                    .rotationEffect(.degrees(Double(index * 30) + rayRotation))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rayRotation = 360
            }
        }
    }
}

struct FrostOverlayView: View {
    @State private var frostPattern: Double = 0

    var body: some View {
        Canvas { context, size in
            // Draw frost patterns
            for _ in 0..<50 {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let length = Double.random(in: 10...30)
                let angle = Double.random(in: 0...(2 * .pi))

                let start = CGPoint(x: x, y: y)
                let end = CGPoint(
                    x: x + length * cos(angle + frostPattern),
                    y: y + length * sin(angle + frostPattern)
                )

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.6)),
                    lineWidth: 1
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                frostPattern = .pi / 4
            }
        }
    }
}

struct ChristmasLightsView: View {
    @State private var lightIntensity: Double = 0.5

    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.random(from: [.red, .green, .blue, .yellow]),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 15
                        )
                    )
                    .frame(width: 20, height: 20)
                    .opacity(0.3 + lightIntensity)
                    .blur(radius: 3)
                    .animation(
                        .easeInOut(duration: Double.random(in: 1...2))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: lightIntensity
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                lightIntensity = 1.0
            }
        }
    }
}

struct HalloweenDecorationView: View {
    @State private var ghostFloat: CGFloat = 0

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("👻")
                    .font(.title)
                    .offset(y: ghostFloat)
                    .opacity(0.7)
            }
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                ghostFloat = 20
            }
        }
    }
}

struct FloatingHeartsView: View {
    @State private var heartPositions: [CGPoint] = []

    var body: some View {
        ZStack {
            ForEach(heartPositions.indices, id: \.self) { index in
                Text("💖")
                    .font(.title2)
                    .position(heartPositions[index])
                    .opacity(0.6)
            }
        }
        .onAppear {
            generateHearts()
            animateHearts()
        }
    }

    private func generateHearts() {
        heartPositions = (0..<5).map { _ in
            CGPoint(
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: 100...600)
            )
        }
    }

    private func animateHearts() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            for index in heartPositions.indices {
                heartPositions[index].y -= 2
                heartPositions[index].x += sin(heartPositions[index].y * 0.01) * 2

                // Reset if off screen
                if heartPositions[index].y < -50 {
                    heartPositions[index] = CGPoint(
                        x: CGFloat.random(in: 50...350),
                        y: 700
                    )
                }
            }
        }
    }
}

// MARK: - Emitter Creation Methods
extension SeasonalEffectsManager {
    private func createSnowEmitter(intensity: ParticleIntensity) -> ParticleEmitter {
        let config = EmitterConfig(
            emissionRate: intensity.emissionRate,
            spawnRadius: 0,
            angleRange: (.pi * 0.4)...(.pi * 0.6),
            speedRange: 30...80,
            lifetimeRange: 5.0...8.0,
            sizeRange: 2...8,
            rotationSpeedRange: -30...30,
            gravity: CGPoint(x: 10, y: 50),
            colors: [.white, .blue.opacity(0.3)],
            shapes: [.circle, .star]
        )
        return ParticleEmitter(position: CGPoint(x: 200, y: -50), config: config)
    }

    private func createLeavesEmitter(colors: [Color]) -> ParticleEmitter {
        let config = EmitterConfig(
            emissionRate: 30,
            spawnRadius: 20,
            angleRange: (.pi * 0.3)...(.pi * 0.7),
            speedRange: 40...100,
            lifetimeRange: 6.0...10.0,
            sizeRange: 4...12,
            rotationSpeedRange: -60...60,
            gravity: CGPoint(x: 30, y: 80),
            colors: colors,
            shapes: [.circle, .triangle]
        )
        return ParticleEmitter(position: CGPoint(x: 200, y: -50), config: config)
    }

    private func createPetalsEmitter(colors: [Color]) -> ParticleEmitter {
        let config = EmitterConfig(
            emissionRate: 25,
            spawnRadius: 15,
            angleRange: (.pi * 0.2)...(.pi * 0.8),
            speedRange: 20...60,
            lifetimeRange: 8.0...12.0,
            sizeRange: 3...8,
            rotationSpeedRange: -45...45,
            gravity: CGPoint(x: -20, y: 30),
            colors: colors,
            shapes: [.circle, .heart]
        )
        return ParticleEmitter(position: CGPoint(x: 200, y: -50), config: config)
    }

    private func createSunRaysEmitter() -> ParticleEmitter {
        let config = EmitterConfig(
            emissionRate: 10,
            spawnRadius: 30,
            speedRange: 10...30,
            lifetimeRange: 4.0...6.0,
            sizeRange: 2...5,
            gravity: CGPoint(x: 0, y: -20),
            colors: [.yellow.opacity(0.8), .orange.opacity(0.6)],
            shapes: [.sparkle, .star]
        )
        return ParticleEmitter(position: CGPoint(x: 200, y: 100), config: config)
    }

    private func createRainEmitter(intensity: ParticleIntensity) -> ParticleEmitter {
        let config = EmitterConfig(
            emissionRate: intensity.emissionRate * 2,
            angleRange: (.pi * 0.4)...(.pi * 0.6),
            speedRange: 200...400,
            lifetimeRange: 2.0...4.0,
            sizeRange: 1...3,
            gravity: CGPoint(x: 20, y: 300),
            colors: [.blue.opacity(0.7), .cyan.opacity(0.5)],
            shapes: [.circle]
        )
        return ParticleEmitter(position: CGPoint(x: 200, y: -50), config: config)
    }

    private func createFireworksEmitter() -> ParticleEmitter {
        let config = EmitterConfig(
            emissionRate: 50,
            speedRange: 150...400,
            lifetimeRange: 2.0...4.0,
            sizeRange: 3...8,
            gravity: CGPoint(x: 0, y: 100),
            colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
            shapes: [.star, .sparkle, .diamond]
        )
        return ParticleEmitter(position: CGPoint(x: 200, y: 300), config: config)
    }
}

// MARK: - View Extensions
public extension View {
    func seasonalEffects(intensity: CGFloat = 1.0) -> some View {
        overlay(
            SeasonalEffectOverlay(intensity: intensity)
                .allowsHitTesting(false)
        )
    }

    func winterTheme() -> some View {
        onAppear {
            SeasonalEffectsManager.shared.currentSeason = .winter
            SeasonalEffectsManager.shared.activateSeasonalEffect(.snowfall(intensity: .medium))
        }
    }

    func springTheme() -> some View {
        onAppear {
            SeasonalEffectsManager.shared.currentSeason = .spring
            SeasonalEffectsManager.shared.activateSeasonalEffect(.flowerPetals(colors: [.pink, .white, .yellow]))
        }
    }

    func summerTheme() -> some View {
        onAppear {
            SeasonalEffectsManager.shared.currentSeason = .summer
            SeasonalEffectsManager.shared.activateSeasonalEffect(.sunRays)
        }
    }

    func autumnTheme() -> some View {
        onAppear {
            SeasonalEffectsManager.shared.currentSeason = .autumn
            SeasonalEffectsManager.shared.activateSeasonalEffect(.fallingLeaves(colors: [.orange, .red, .yellow]))
        }
    }

    func holidayTheme(_ holiday: Holiday) -> some View {
        onAppear {
            SeasonalEffectsManager.shared.setHolidayTheme(holiday)
        }
    }

    func weatherEffect(_ condition: WeatherCondition) -> some View {
        onAppear {
            SeasonalEffectsManager.shared.updateWeather(condition)
        }
    }
}

// MARK: - Color Extensions
extension Color {
    static func random(from colors: [Color]) -> Color {
        return colors.randomElement() ?? .primary
    }
}

// MARK: - Complete Todo
public extension View {
    /// Master modifier that applies all Pixar-quality animations and effects
    func pixarExperience(
        season: Season? = nil,
        weather: WeatherCondition = .clear,
        holiday: Holiday? = nil
    ) -> some View {
        self
            .seasonalEffects()
            .onAppear {
                if let season = season {
                    SeasonalEffectsManager.shared.currentSeason = season
                }
                SeasonalEffectsManager.shared.updateWeather(weather)
                if let holiday = holiday {
                    SeasonalEffectsManager.shared.setHolidayTheme(holiday)
                }
            }
    }
}