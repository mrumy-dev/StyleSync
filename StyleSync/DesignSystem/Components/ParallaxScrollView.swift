import SwiftUI

struct ParallaxScrollView<Content: View, Header: View>: View {
    let content: Content
    let header: Header
    let headerHeight: CGFloat
    let parallaxMultiplier: CGFloat

    @State private var scrollOffset: CGFloat = 0

    init(
        headerHeight: CGFloat = 300,
        parallaxMultiplier: CGFloat = 0.5,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.headerHeight = headerHeight
        self.parallaxMultiplier = parallaxMultiplier
        self.header = header()
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Parallax Header
                    GeometryReader { headerGeometry in
                        header
                            .frame(
                                width: geometry.size.width,
                                height: max(headerHeight, headerHeight + headerGeometry.frame(in: .global).minY * parallaxMultiplier)
                            )
                            .offset(y: -headerGeometry.frame(in: .global).minY * parallaxMultiplier)
                            .clipped()
                    }
                    .frame(height: headerHeight)

                    // Content
                    content
                        .background(DesignSystem.Colors.background)
                }
            }
            .coordinateSpace(name: "scroll")
        }
    }
}

// MARK: - Advanced Parallax with Multiple Layers

struct LayeredParallaxScrollView<Content: View>: View {
    let content: Content
    let layers: [ParallaxLayer]
    let headerHeight: CGFloat

    @State private var scrollOffset: CGFloat = 0

    init(
        headerHeight: CGFloat = 300,
        layers: [ParallaxLayer],
        @ViewBuilder content: () -> Content
    ) {
        self.headerHeight = headerHeight
        self.layers = layers
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Multi-layer parallax header
                    ZStack {
                        ForEach(Array(layers.enumerated()), id: \.offset) { index, layer in
                            GeometryReader { headerGeometry in
                                layer.content
                                    .frame(width: geometry.size.width)
                                    .offset(
                                        y: -headerGeometry.frame(in: .global).minY * layer.speed
                                    )
                                    .scaleEffect(
                                        max(1.0, 1.0 + (-headerGeometry.frame(in: .global).minY / headerHeight) * layer.scale)
                                    )
                                    .opacity(
                                        layer.fadeOnScroll
                                        ? max(0.3, 1.0 + (headerGeometry.frame(in: .global).minY / headerHeight))
                                        : 1.0
                                    )
                            }
                            .frame(height: headerHeight)
                        }
                    }
                    .frame(height: headerHeight)

                    // Content with smooth transition
                    content
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(DesignSystem.Colors.background)
                                .shadow(
                                    color: DesignSystem.Colors.shadow.opacity(0.1),
                                    radius: 20,
                                    y: -10
                                )
                        )
                        .offset(y: -24)
                }
            }
            .coordinateSpace(name: "scroll")
        }
    }
}

struct ParallaxLayer {
    let content: AnyView
    let speed: CGFloat
    let scale: CGFloat
    let fadeOnScroll: Bool

    init<Content: View>(
        speed: CGFloat = 0.5,
        scale: CGFloat = 0.2,
        fadeOnScroll: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.speed = speed
        self.scale = scale
        self.fadeOnScroll = fadeOnScroll
        self.content = AnyView(content())
    }
}

// MARK: - Magnetic Scroll Effects

struct MagneticParallaxScrollView<Content: View>: View {
    let content: Content
    let snapPoints: [CGFloat]
    let headerHeight: CGFloat

    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0

    init(
        headerHeight: CGFloat = 300,
        snapPoints: [CGFloat] = [0, 150, 300],
        @ViewBuilder content: () -> Content
    ) {
        self.headerHeight = headerHeight
        self.snapPoints = snapPoints
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Magnetic parallax header
                    GeometryReader { headerGeometry in
                        ZStack {
                            // Background layer
                            RoundedRectangle(cornerRadius: 0)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.accent.opacity(0.8),
                                            DesignSystem.Colors.primary.opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(
                                    max(1.0, 1.0 + (-headerGeometry.frame(in: .global).minY / headerHeight) * 0.3)
                                )

                            // Content layer
                            content
                        }
                        .offset(y: -headerGeometry.frame(in: .global).minY * 0.4)
                        .onChange(of: headerGeometry.frame(in: .global).minY) { offset in
                            scrollOffset = -offset

                            // Magnetic snapping
                            if !isDragging {
                                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                                    snapToClosestPoint()
                                }
                            }
                        }
                    }
                    .frame(height: headerHeight)
                    .clipped()

                    // Additional content
                    Rectangle()
                        .fill(DesignSystem.Colors.background)
                        .frame(height: 1000)
                }
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.y
                        isDragging = true
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                            snapToClosestPoint()
                        }
                    }
            )
        }
    }

    private func snapToClosestPoint() {
        let closestPoint = snapPoints.min { abs($0 - scrollOffset) < abs($1 - scrollOffset) } ?? 0
        // Implement snapping logic here
    }
}

// MARK: - Premium Parallax Card

struct ParallaxCard<Content: View>: View {
    let content: Content
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                GlassCardView(
                    cornerRadius: 20,
                    blurRadius: 15,
                    opacity: 0.2,
                    shadowRadius: 15
                ) {
                    Rectangle()
                        .fill(.clear)
                }
            )
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: -offset.height, y: offset.width, z: 0)
            )
            .scaleEffect(1.0 + (abs(offset.width) + abs(offset.height)) / 1000)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                            offset = CGSize(
                                width: value.translation.x * 0.5,
                                height: value.translation.y * 0.5
                            )
                            rotation = Double(value.translation.x * 0.1)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                            offset = .zero
                            rotation = 0
                        }
                    }
            )
    }
}

// MARK: - Infinity Scroll with Parallax

struct InfiniteParallaxScrollView<Content: View>: View {
    let content: Content
    let itemHeight: CGFloat
    let parallaxOffset: CGFloat

    @State private var scrollOffset: CGFloat = 0

    init(
        itemHeight: CGFloat = 200,
        parallaxOffset: CGFloat = 50,
        @ViewBuilder content: () -> Content
    ) {
        self.itemHeight = itemHeight
        self.parallaxOffset = parallaxOffset
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 20) {
                    content
                }
                .padding()
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: contentGeometry.frame(in: .named("scroll")).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    ParallaxScrollView(
        headerHeight: 300,
        header: {
            ZStack {
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack {
                    Spacer()
                    Text("Parallax Header")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        },
        content: {
            VStack(spacing: 20) {
                ForEach(0..<10) { index in
                    GlassCardView {
                        VStack {
                            Text("Card \(index + 1)")
                                .font(.title2.weight(.semibold))
                            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    )
}