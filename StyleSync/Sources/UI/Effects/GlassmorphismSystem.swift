import SwiftUI

// MARK: - Glassmorphism Effect System
public struct GlassmorphismModifier: ViewModifier {
    let intensity: GlassIntensity
    let tint: Color
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: Color
    let shadowRadius: CGFloat
    
    public init(
        intensity: GlassIntensity = .medium,
        tint: Color = .white,
        cornerRadius: CGFloat = 16,
        borderWidth: CGFloat = 1,
        borderColor: Color = .white.opacity(0.2),
        shadowRadius: CGFloat = 20
    ) {
        self.intensity = intensity
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.shadowRadius = shadowRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                GlassmorphismBackground(
                    intensity: intensity,
                    tint: tint,
                    cornerRadius: cornerRadius,
                    borderWidth: borderWidth,
                    borderColor: borderColor
                )
            )
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 10)
    }
}

public enum GlassIntensity: CaseIterable {
    case subtle
    case light
    case medium
    case strong
    case intense
    
    public var blurRadius: CGFloat {
        switch self {
        case .subtle: return 8
        case .light: return 15
        case .medium: return 25
        case .strong: return 35
        case .intense: return 50
        }
    }
    
    public var opacity: Double {
        switch self {
        case .subtle: return 0.05
        case .light: return 0.1
        case .medium: return 0.15
        case .strong: return 0.2
        case .intense: return 0.25
        }
    }
    
    public var borderOpacity: Double {
        switch self {
        case .subtle: return 0.1
        case .light: return 0.15
        case .medium: return 0.2
        case .strong: return 0.25
        case .intense: return 0.3
        }
    }
}

struct GlassmorphismBackground: View {
    let intensity: GlassIntensity
    let tint: Color
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: Color
    
    var body: some View {
        ZStack {
            // Base blur effect
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // Tint overlay
            tint.opacity(intensity.opacity)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .blendMode(.overlay)
            
            // Gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .blendMode(.overlay)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            borderColor.opacity(intensity.borderOpacity),
                            borderColor.opacity(intensity.borderOpacity * 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: borderWidth
                )
        )
    }
}

// MARK: - Advanced Glassmorphism Variants
public struct FrostedGlassModifier: ViewModifier {
    let frost: FrostLevel
    let temperature: GlassTemperature
    
    public init(frost: FrostLevel = .medium, temperature: GlassTemperature = .cool) {
        self.frost = frost
        self.temperature = temperature
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                FrostedGlassBackground(frost: frost, temperature: temperature)
            )
    }
}

public enum FrostLevel: CaseIterable {
    case light, medium, heavy, arctic
    
    public var noiseIntensity: Double {
        switch self {
        case .light: return 0.02
        case .medium: return 0.04
        case .heavy: return 0.06
        case .arctic: return 0.08
        }
    }
    
    public var blurRadius: CGFloat {
        switch self {
        case .light: return 20
        case .medium: return 30
        case .heavy: return 40
        case .arctic: return 55
        }
    }
}

public enum GlassTemperature {
    case warm, neutral, cool, icy
    
    public var tintColor: Color {
        switch self {
        case .warm: return Color.orange.opacity(0.1)
        case .neutral: return Color.clear
        case .cool: return Color.blue.opacity(0.05)
        case .icy: return Color.cyan.opacity(0.1)
        }
    }
}

struct FrostedGlassBackground: View {
    let frost: FrostLevel
    let temperature: GlassTemperature
    
    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
            
            // Frost texture overlay
            FrostTextureView(intensity: frost.noiseIntensity)
                .blendMode(.overlay)
            
            // Temperature tint
            temperature.tintColor
                .blendMode(.overlay)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Liquid Glass Effects
public struct LiquidGlassModifier: ViewModifier {
    @State private var phase: Double = 0
    let viscosity: LiquidViscosity
    let flowSpeed: Double
    
    public init(viscosity: LiquidViscosity = .medium, flowSpeed: Double = 1.0) {
        self.viscosity = viscosity
        self.flowSpeed = flowSpeed
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassBackground(phase: phase, viscosity: viscosity)
            )
            .onAppear {
                withAnimation(.linear(duration: 3.0 / flowSpeed).repeatForever(autoreverses: false)) {
                    phase = 2 * .pi
                }
            }
    }
}

public enum LiquidViscosity {
    case water, honey, syrup, molasses
    
    public var flowMultiplier: Double {
        switch self {
        case .water: return 2.0
        case .honey: return 1.0
        case .syrup: return 0.5
        case .molasses: return 0.2
        }
    }
}

struct LiquidGlassBackground: View {
    let phase: Double
    let viscosity: LiquidViscosity
    
    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemThinMaterial)
            
            // Liquid flow gradient
            RadialGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.clear,
                    Color.blue.opacity(0.1)
                ],
                center: UnitPoint(
                    x: 0.5 + 0.3 * sin(phase * viscosity.flowMultiplier),
                    y: 0.5 + 0.2 * cos(phase * viscosity.flowMultiplier * 1.3)
                ),
                startRadius: 0,
                endRadius: 200
            )
            .blendMode(.overlay)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Prismatic Glass Effects
public struct PrismaticGlassModifier: ViewModifier {
    @State private var rotation: Double = 0
    let refractionIntensity: Double
    let spectrumShift: Bool
    
    public init(refractionIntensity: Double = 1.0, spectrumShift: Bool = true) {
        self.refractionIntensity = refractionIntensity
        self.spectrumShift = spectrumShift
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                PrismaticGlassBackground(
                    rotation: rotation,
                    refractionIntensity: refractionIntensity,
                    spectrumShift: spectrumShift
                )
            )
            .onAppear {
                if spectrumShift {
                    withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            }
    }
}

struct PrismaticGlassBackground: View {
    let rotation: Double
    let refractionIntensity: Double
    let spectrumShift: Bool
    
    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemThinMaterial)
            
            if spectrumShift {
                AngularGradient(
                    colors: [
                        .red, .orange, .yellow, .green, .blue, .purple, .red
                    ].map { $0.opacity(0.1 * refractionIntensity) },
                    center: .center,
                    angle: .degrees(rotation)
                )
                .blendMode(.screen)
            }
            
            // Light refraction lines
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.3 * refractionIntensity),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .rotationEffect(.degrees(30 + Double(index) * 60))
                    .offset(
                        x: 50 * sin(rotation * .pi / 180 + Double(index) * .pi / 3),
                        y: 50 * cos(rotation * .pi / 180 + Double(index) * .pi / 3)
                    )
                    .blendMode(.screen)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Support Views
struct VisualEffectBlur: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

struct FrostTextureView: View {
    let intensity: Double
    @State private var noisePhase: Double = 0
    
    var body: some View {
        Canvas { context, size in
            for _ in 0..<Int(intensity * 10000) {
                let x = Double.random(in: 0...Double(size.width))
                let y = Double.random(in: 0...Double(size.height))
                let opacity = Double.random(in: 0...intensity)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                noisePhase += 0.1
            }
        }
    }
}

// MARK: - View Extensions
public extension View {
    func glassmorphism(
        intensity: GlassIntensity = .medium,
        tint: Color = .white,
        cornerRadius: CGFloat = 16,
        borderWidth: CGFloat = 1,
        borderColor: Color = .white.opacity(0.2),
        shadowRadius: CGFloat = 20
    ) -> some View {
        modifier(GlassmorphismModifier(
            intensity: intensity,
            tint: tint,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadowRadius: shadowRadius
        ))
    }
    
    func frostedGlass(frost: FrostLevel = .medium, temperature: GlassTemperature = .cool) -> some View {
        modifier(FrostedGlassModifier(frost: frost, temperature: temperature))
    }
    
    func liquidGlass(viscosity: LiquidViscosity = .medium, flowSpeed: Double = 1.0) -> some View {
        modifier(LiquidGlassModifier(viscosity: viscosity, flowSpeed: flowSpeed))
    }
    
    func prismaticGlass(refractionIntensity: Double = 1.0, spectrumShift: Bool = true) -> some View {
        modifier(PrismaticGlassModifier(refractionIntensity: refractionIntensity, spectrumShift: spectrumShift))
    }
}