import SwiftUI

struct SmoothTransitionManager {
    static let pageTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    static let modalTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )

    static let fadeScale = AnyTransition.scale(scale: 0.95).combined(with: .opacity)

    static let slideUp = AnyTransition.move(edge: .bottom)

    static let rotateAndFade = AnyTransition.scale(scale: 0.8)
        .combined(with: .opacity)
        .combined(with: .rotation(angle: .degrees(5)))
}

struct NavigationTransition: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .transition(SmoothTransitionManager.pageTransition)
            .animation(ProMotionAnimations.silk, value: isActive)
    }
}

struct ModalTransition: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .transition(SmoothTransitionManager.modalTransition)
            .animation(ProMotionAnimations.gentleSpring, value: isPresented)
    }
}

struct SlideTransition: ViewModifier {
    let direction: Edge
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .transition(.move(edge: direction))
            .animation(ProMotionAnimations.quickBounce, value: isVisible)
    }
}

struct ScaleTransition: ViewModifier {
    let isVisible: Bool
    let scale: CGFloat

    init(isVisible: Bool, scale: CGFloat = 0.95) {
        self.isVisible = isVisible
        self.scale = scale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : scale)
            .opacity(isVisible ? 1.0 : 0)
            .animation(ProMotionAnimations.ultraSmooth, value: isVisible)
    }
}

struct HeroTransition<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
    }
}

struct CardFlipTransition: ViewModifier {
    let isFlipped: Bool
    @State private var backDegree = -90.0
    @State private var frontDegree = 0.0

    func body(content: Content) -> some View {
        ZStack {
            content
                .rotation3DEffect(Angle(degrees: frontDegree), axis: (x: 0, y: 1, z: 0))
        }
        .onTapGesture {
            flipCard()
        }
    }

    private func flipCard() {
        withAnimation(ProMotionAnimations.silk) {
            frontDegree = isFlipped ? 0 : -90
            backDegree = isFlipped ? -90 : 0
        }
    }
}

struct MorphingTransition: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + (progress * 0.1))
            .blur(radius: progress * 2)
            .animation(ProMotionAnimations.silk, value: progress)
    }
}

struct ElasticSheet<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    @State private var dragAmount = CGSize.zero
    @State private var dragVelocity = CGSize.zero

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 12)

                        content()
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .offset(y: max(0, dragAmount.height))
                    .scaleEffect(1.0 - (dragAmount.height / 2000))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                withAnimation(ProMotionAnimations.silk) {
                                    dragAmount = value.translation
                                    dragVelocity = value.velocity
                                }
                            }
                            .onEnded { _ in
                                handleDragEnd()
                            }
                    )
                }
            }
        }
        .animation(ProMotionAnimations.gentleSpring, value: isPresented)
    }

    private func dismiss() {
        withAnimation(ProMotionAnimations.quickBounce) {
            isPresented = false
        }
    }

    private func handleDragEnd() {
        let threshold: CGFloat = 150
        let velocityThreshold: CGFloat = 1000

        if dragAmount.height > threshold || dragVelocity.height > velocityThreshold {
            dismiss()
        } else {
            withAnimation(ProMotionAnimations.quickBounce) {
                dragAmount = .zero
                dragVelocity = .zero
            }
        }
    }
}

struct PageCurlTransition: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(progress * 180),
                axis: (x: 0, y: 1, z: 0),
                anchor: .trailing,
                anchorZ: 0,
                perspective: 0.5
            )
            .scaleEffect(1.0 - (progress * 0.2))
            .animation(ProMotionAnimations.silk, value: progress)
    }
}

struct LiquidTransition: View {
    @Binding var isVisible: Bool
    let content: AnyView

    @State private var morphProgress: Double = 0
    @State private var rippleOffset: CGFloat = 0

    var body: some View {
        ZStack {
            content
                .clipShape(
                    LiquidShape(progress: morphProgress)
                )
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0)
        }
        .onChange(of: isVisible) { newValue in
            withAnimation(ProMotionAnimations.silk) {
                morphProgress = newValue ? 1.0 : 0
            }
        }
    }
}

struct LiquidShape: Shape {
    let progress: Double

    var animatableData: Double {
        get { progress }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            let cornerRadius = rect.height * 0.1 * progress
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
    }
}

struct BreatheTransition: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if isActive {
                    withAnimation(
                        .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.05
                    }
                }
            }
    }
}

struct TabTransition: ViewModifier {
    let selectedTab: Int
    let tabIndex: Int

    func body(content: Content) -> some View {
        content
            .scaleEffect(selectedTab == tabIndex ? 1.0 : 0.95)
            .opacity(selectedTab == tabIndex ? 1.0 : 0.7)
            .animation(ProMotionAnimations.quickBounce, value: selectedTab)
    }
}

struct PushTransition<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                content()
                    .frame(width: geometry.size.width)
                    .clipped()

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geometry.size.width)
            }
            .offset(x: isPresented ? 0 : geometry.size.width)
            .animation(ProMotionAnimations.silk, value: isPresented)
        }
    }
}

struct CrossDissolveTransition<PrimaryContent: View, SecondaryContent: View>: View {
    let showPrimary: Bool
    @ViewBuilder let primaryContent: () -> PrimaryContent
    @ViewBuilder let secondaryContent: () -> SecondaryContent

    var body: some View {
        ZStack {
            primaryContent()
                .opacity(showPrimary ? 1 : 0)

            secondaryContent()
                .opacity(showPrimary ? 0 : 1)
        }
        .animation(ProMotionAnimations.silk, value: showPrimary)
    }
}

struct MagneticTransition: ViewModifier {
    let isAttracted: Bool
    @State private var position: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .position(position)
            .onAppear {
                if isAttracted {
                    withAnimation(ProMotionAnimations.quickBounce) {
                        position = CGPoint(x: 100, y: 100)
                    }
                }
            }
    }
}

struct PhysicsTransition: ViewModifier {
    let isActive: Bool
    @State private var offset: CGSize = .zero
    @State private var velocity: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                if isActive {
                    simulatePhysics()
                }
            }
    }

    private func simulatePhysics() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let gravity: CGFloat = 0.5
            let damping: CGFloat = 0.95

            velocity.height += gravity
            velocity.width *= damping
            velocity.height *= damping

            offset.width += velocity.width
            offset.height += velocity.height

            if abs(velocity.width) < 0.1 && abs(velocity.height) < 0.1 {
                timer.invalidate()
            }
        }
    }
}

extension View {
    func navigationTransition(isActive: Bool) -> some View {
        modifier(NavigationTransition(isActive: isActive))
    }

    func modalTransition(isPresented: Bool) -> some View {
        modifier(ModalTransition(isPresented: isPresented))
    }

    func slideTransition(from edge: Edge, isVisible: Bool) -> some View {
        modifier(SlideTransition(direction: edge, isVisible: isVisible))
    }

    func scaleTransition(isVisible: Bool, scale: CGFloat = 0.95) -> some View {
        modifier(ScaleTransition(isVisible: isVisible, scale: scale))
    }

    func heroTransition<ID: Hashable>(id: ID, namespace: Namespace.ID) -> some View {
        modifier(HeroTransition(id: id, namespace: namespace))
    }

    func cardFlip(isFlipped: Bool) -> some View {
        modifier(CardFlipTransition(isFlipped: isFlipped))
    }

    func morphing(progress: Double) -> some View {
        modifier(MorphingTransition(progress: progress))
    }

    func pageCurl(progress: Double) -> some View {
        modifier(PageCurlTransition(progress: progress))
    }

    func breathe(isActive: Bool = true) -> some View {
        modifier(BreatheTransition(isActive: isActive))
    }

    func tabTransition(selectedTab: Int, tabIndex: Int) -> some View {
        modifier(TabTransition(selectedTab: selectedTab, tabIndex: tabIndex))
    }

    func magnetic(isAttracted: Bool) -> some View {
        modifier(MagneticTransition(isAttracted: isAttracted))
    }

    func physics(isActive: Bool) -> some View {
        modifier(PhysicsTransition(isActive: isActive))
    }
}

struct TransitionShowcase: View {
    @State private var selectedTransition = 0
    @State private var isVisible = false
    @State private var showSecondary = false
    @State private var selectedTab = 0
    @Namespace private var heroNamespace

    private let transitions = [
        "Scale & Fade",
        "Slide Up",
        "Hero",
        "Cross Dissolve",
        "Card Flip",
        "Liquid",
        "Breathe"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Picker("Transition Type", selection: $selectedTransition) {
                ForEach(0..<transitions.count, id: \.self) { index in
                    Text(transitions[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Button("Toggle Animation") {
                withAnimation {
                    isVisible.toggle()
                    showSecondary.toggle()
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Group {
                switch selectedTransition {
                case 0:
                    if isVisible {
                        sampleView
                            .scaleTransition(isVisible: isVisible)
                    }

                case 1:
                    if isVisible {
                        sampleView
                            .slideTransition(from: .bottom, isVisible: isVisible)
                    }

                case 2:
                    if isVisible {
                        sampleView
                            .heroTransition(id: "hero", namespace: heroNamespace)
                    }

                case 3:
                    CrossDissolveTransition(showPrimary: !showSecondary) {
                        sampleView.background(.blue)
                    } secondaryContent: {
                        sampleView.background(.purple)
                    }

                case 4:
                    sampleView
                        .cardFlip(isFlipped: showSecondary)

                case 5:
                    LiquidTransition(isVisible: $isVisible) {
                        AnyView(sampleView)
                    }

                case 6:
                    sampleView
                        .breathe(isActive: isVisible)

                default:
                    sampleView
                }
            }
            .frame(height: 200)

            Spacer()
        }
        .padding()
    }

    private var sampleView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 150, height: 150)
            .overlay(
                Text("Sample")
                    .font(.headline)
                    .foregroundColor(.white)
            )
    }
}