import SwiftUI
import UIKit

struct ProMotionAnimations {

    static let ultraSmooth = Animation.interpolatingSpring(
        mass: 0.5,
        stiffness: 300,
        damping: 30,
        initialVelocity: 0
    )

    static let buttery = Animation.timingCurve(0.2, 0.0, 0.2, 1.0, duration: 0.5)

    static let silk = Animation.interpolatingSpring(
        mass: 0.8,
        stiffness: 250,
        damping: 25,
        initialVelocity: 0
    )

    static let glass = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 400,
        damping: 40,
        initialVelocity: 0
    )

    static let quickBounce = Animation.interpolatingSpring(
        mass: 0.3,
        stiffness: 500,
        damping: 20,
        initialVelocity: 10
    )

    static let gentleSpring = Animation.interpolatingSpring(
        mass: 1.2,
        stiffness: 200,
        damping: 35,
        initialVelocity: 0
    )

    static let microInteraction = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.2)

    static func customSpring(
        response: Double = 0.5,
        dampingFraction: Double = 0.8,
        blendDuration: Double = 0
    ) -> Animation {
        .spring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration)
    }

    static func adaptiveAnimation(for device: UIDevice = UIDevice.current) -> Animation {
        if device.userInterfaceIdiom == .phone {
            return quickBounce
        } else {
            return gentleSpring
        }
    }
}

struct HighRefreshRateAnimationView: View {
    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero

    let content: AnyView
    let animationType: HighRefreshAnimationType

    init<Content: View>(
        animationType: HighRefreshAnimationType = .spring,
        @ViewBuilder content: () -> Content
    ) {
        self.animationType = animationType
        self.content = AnyView(content())
    }

    var body: some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .onAppear {
                startAnimation()
            }
    }

    private func startAnimation() {
        switch animationType {
        case .spring:
            withAnimation(ProMotionAnimations.ultraSmooth) {
                isAnimating = true
            }
        case .bounce:
            withAnimation(ProMotionAnimations.quickBounce) {
                scale = 1.1
            }
            withAnimation(ProMotionAnimations.gentleSpring.delay(0.1)) {
                scale = 1.0
            }
        case .rotate:
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        case .float:
            withAnimation(
                ProMotionAnimations.silk
                    .repeatForever(autoreverses: true)
            ) {
                offset = CGSize(width: 0, height: -10)
            }
        case .pulse:
            withAnimation(
                ProMotionAnimations.gentleSpring
                    .repeatForever(autoreverses: true)
            ) {
                scale = 1.05
            }
        }
    }
}

enum HighRefreshAnimationType {
    case spring
    case bounce
    case rotate
    case float
    case pulse
}

struct FluidButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    @State private var brightness: Double = 0

    var body: some View {
        Button(action: action) {
            label()
                .scaleEffect(scale)
                .brightness(brightness)
        }
        .buttonStyle(FluidButtonStyle())
        .onTapGesture {
            performTapAnimation()
        }
    }

    private func performTapAnimation() {
        withAnimation(ProMotionAnimations.microInteraction) {
            scale = 0.95
            brightness = 0.1
        }

        withAnimation(ProMotionAnimations.quickBounce.delay(0.1)) {
            scale = 1.0
            brightness = 0
        }
    }
}

struct FluidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(ProMotionAnimations.microInteraction, value: configuration.isPressed)
    }
}

struct SmoothScrollView<Content: View>: View {
    let content: Content
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let currentDrag = value.translation.y
                                let dragDelta = currentDrag - lastDragValue

                                withAnimation(ProMotionAnimations.silk) {
                                    dragOffset += dragDelta * 0.1
                                }

                                lastDragValue = currentDrag
                            }
                            .onEnded { _ in
                                withAnimation(ProMotionAnimations.gentleSpring) {
                                    dragOffset = 0
                                    lastDragValue = 0
                                }
                            }
                    )
            }
        }
    }
}

struct MorphingShape: View {
    @State private var morphProgress: Double = 0
    @State private var animationOffset: CGFloat = 0

    let startShape: MorphableShape
    let endShape: MorphableShape
    let duration: Double

    init(
        from startShape: MorphableShape,
        to endShape: MorphableShape,
        duration: Double = 2.0
    ) {
        self.startShape = startShape
        self.endShape = endShape
        self.duration = duration
    }

    var body: some View {
        Canvas { context, size in
            let interpolatedPath = interpolatePaths(
                from: startShape.path(in: CGRect(origin: .zero, size: size)),
                to: endShape.path(in: CGRect(origin: .zero, size: size)),
                progress: morphProgress
            )

            context.stroke(
                Path(interpolatedPath.cgPath),
                with: .linearGradient(
                    Gradient(colors: [.blue, .purple]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            withAnimation(
                .linear(duration: duration)
                .repeatForever(autoreverses: true)
            ) {
                morphProgress = 1.0
            }
        }
    }

    private func interpolatePaths(from: Path, to: Path, progress: Double) -> Path {
        return from
    }
}

protocol MorphableShape {
    func path(in rect: CGRect) -> Path
}

extension Circle: MorphableShape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addEllipse(in: rect)
        }
    }
}

extension RoundedRectangle: MorphableShape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
    }
}

struct LiquidButton: View {
    let title: String
    let action: () -> Void

    @State private var isPressed = false
    @State private var rippleEffect = false
    @State private var liquidOffset: CGSize = .zero

    var body: some View {
        Button(action: {
            performLiquidAnimation()
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 50)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .offset(liquidOffset)

                if rippleEffect {
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .scaleEffect(rippleEffect ? 2.0 : 0.1)
                        .opacity(rippleEffect ? 0 : 1)
                        .frame(width: 50, height: 50)
                }

                Text(title)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func performLiquidAnimation() {
        withAnimation(ProMotionAnimations.microInteraction) {
            isPressed = true
        }

        withAnimation(.linear(duration: 0.6)) {
            rippleEffect = true
        }

        withAnimation(ProMotionAnimations.silk) {
            liquidOffset = CGSize(width: Double.random(in: -5...5), height: Double.random(in: -3...3))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(ProMotionAnimations.quickBounce) {
                isPressed = false
                liquidOffset = .zero
            }

            withAnimation(.linear(duration: 0.1)) {
                rippleEffect = false
            }
        }
    }
}

struct ParallaxScrollEffect<Content: View>: View {
    let content: Content
    @State private var scrollOffset: CGFloat = 0

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .offset(y: scrollOffset * 0.5)
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .onAppear {
                                    updateScrollOffset(scrollGeometry, parentGeometry: geometry)
                                }
                                .onChange(of: scrollGeometry.frame(in: .global).minY) { _ in
                                    updateScrollOffset(scrollGeometry, parentGeometry: geometry)
                                }
                        }
                    )
            }
        }
    }

    private func updateScrollOffset(_ scrollGeometry: GeometryProxy, parentGeometry: GeometryProxy) {
        let offset = scrollGeometry.frame(in: .global).minY - parentGeometry.frame(in: .global).minY

        withAnimation(ProMotionAnimations.silk) {
            scrollOffset = offset
        }
    }
}

struct ElasticDragModifier: ViewModifier {
    @State private var dragOffset: CGSize = .zero
    @State private var elasticScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .offset(dragOffset)
            .scaleEffect(elasticScale)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(ProMotionAnimations.silk) {
                            dragOffset = value.translation
                            elasticScale = 1.0 + (abs(value.translation.x) + abs(value.translation.y)) * 0.0005
                        }
                    }
                    .onEnded { _ in
                        withAnimation(ProMotionAnimations.quickBounce) {
                            dragOffset = .zero
                            elasticScale = 1.0
                        }
                    }
            )
    }
}

struct GlowingOrb: View {
    @State private var glowRadius: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    let color: Color
    let size: CGFloat

    init(color: Color = .blue, size: CGFloat = 100) {
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.8), color.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2 + glowRadius
                    )
                )
                .frame(width: size + glowRadius * 2, height: size + glowRadius * 2)
                .scaleEffect(pulseScale)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(
                ProMotionAnimations.gentleSpring
                    .repeatForever(autoreverses: true)
            ) {
                glowRadius = 20
                pulseScale = 1.1
            }

            withAnimation(
                .linear(duration: 8)
                    .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
    }
}

extension View {
    func fluidAnimation() -> some View {
        modifier(FluidAnimationModifier())
    }

    func elasticDrag() -> some View {
        modifier(ElasticDragModifier())
    }

    func parallaxEffect() -> some View {
        ParallaxScrollEffect {
            self
        }
    }
}

struct FluidAnimationModifier: ViewModifier {
    @State private var animationOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: animationOffset)
            .onAppear {
                withAnimation(
                    ProMotionAnimations.silk
                        .repeatForever(autoreverses: true)
                ) {
                    animationOffset = 5
                }
            }
    }
}

struct ProMotionShowcase: View {
    @State private var selectedDemo = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("120Hz ProMotion Showcase")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fluidAnimation()

            Picker("Demo Type", selection: $selectedDemo) {
                Text("Buttons").tag(0)
                Text("Morphing").tag(1)
                Text("Parallax").tag(2)
                Text("Elastic").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())

            Group {
                switch selectedDemo {
                case 0:
                    VStack(spacing: 16) {
                        LiquidButton(title: "Liquid Button") {}

                        FluidButton {
                            print("Fluid button tapped")
                        } label: {
                            Text("Fluid Button")
                                .padding()
                                .background(.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }

                case 1:
                    MorphingShape(
                        from: Circle(),
                        to: RoundedRectangle(cornerRadius: 20)
                    )
                    .frame(width: 200, height: 200)

                case 2:
                    ParallaxScrollEffect {
                        VStack(spacing: 20) {
                            ForEach(0..<5) { i in
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(height: 150)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 400)

                case 3:
                    VStack(spacing: 20) {
                        GlowingOrb(color: .purple, size: 80)

                        RoundedRectangle(cornerRadius: 15)
                            .fill(.blue.gradient)
                            .frame(width: 150, height: 100)
                            .elasticDrag()
                    }

                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: 300)

            Spacer()
        }
        .padding()
    }
}