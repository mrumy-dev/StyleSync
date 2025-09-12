import SwiftUI

// MARK: - Liquid Tab Bar
public struct LiquidTabBar: View {
    @Binding var selectedIndex: Int
    let items: [TabItem]
    @State private var indicatorOffset: CGFloat = 0
    @State private var liquidAnimation: CGFloat = 0
    @Environment(\.theme) private var theme
    
    public init(selectedIndex: Binding<Int>, items: [TabItem]) {
        self._selectedIndex = selectedIndex
        self.items = items
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let itemWidth = geometry.size.width / CGFloat(items.count)
            
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 25)
                    .fill(theme.colors.surface)
                    .glassmorphism(intensity: .medium)
                    .frame(height: 80)
                
                // Liquid indicator
                LiquidIndicator(
                    offset: indicatorOffset,
                    width: itemWidth,
                    animationPhase: liquidAnimation
                )
                .foregroundStyle(theme.gradients.primary)
                .frame(height: 6)
                .offset(y: -37)
                
                // Tab items
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        TabItemView(
                            item: item,
                            isSelected: selectedIndex == index,
                            action: {
                                selectTab(at: index, itemWidth: itemWidth)
                            }
                        )
                        .frame(width: itemWidth)
                    }
                }
            }
        }
        .frame(height: 80)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                liquidAnimation = 1.0
            }
        }
    }
    
    private func selectTab(at index: Int, itemWidth: CGFloat) {
        withAnimation(.fluidSpring) {
            selectedIndex = index
            indicatorOffset = CGFloat(index) * itemWidth
        }
    }
}

public struct TabItem {
    public let icon: String
    public let selectedIcon: String
    public let title: String
    
    public init(icon: String, selectedIcon: String? = nil, title: String) {
        self.icon = icon
        self.selectedIcon = selectedIcon ?? icon
        self.title = title
    }
}

struct TabItemView: View {
    let item: TabItem
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? theme.colors.primary : theme.colors.onSurfaceVariant)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.snappySpring, value: isSelected)
                
                Text(item.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? theme.colors.primary : theme.colors.onSurfaceVariant)
                    .opacity(isSelected ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .hapticFeedback(.impact(.light), trigger: .tap)
        .soundEffect(.tabSwitch, trigger: .tap)
    }
}

struct LiquidIndicator: View {
    let offset: CGFloat
    let width: CGFloat
    let animationPhase: CGFloat
    
    var body: some View {
        LiquidIndicatorShape(animationPhase: animationPhase)
            .frame(width: width * 0.6, height: 6)
            .offset(x: offset + width * 0.2)
    }
}

struct LiquidIndicatorShape: Shape {
    let animationPhase: CGFloat
    
    var animatableData: CGFloat {
        get { animationPhase }
        set { }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight: CGFloat = 2
        let waveLength = rect.width
        let waveCount = 2
        
        path.move(to: CGPoint(x: 0, y: rect.midY))
        
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / waveLength
            let sine = sin(relativeX * .pi * CGFloat(waveCount) + animationPhase * .pi * 2) * waveHeight
            let y = rect.midY + sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// MARK: - Floating Action Button
public struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    @State private var ripplePhase: CGFloat = 0
    @Environment(\.theme) private var theme
    
    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            triggerRipple()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(theme.gradients.primary)
                    .frame(width: 56, height: 56)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .shadow(color: theme.colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                
                // Ripple effect
                Circle()
                    .stroke(theme.colors.primary.opacity(0.3), lineWidth: 2)
                    .scaleEffect(1.0 + ripplePhase * 0.8)
                    .opacity(1.0 - ripplePhase)
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isPressed ? 0.8 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { pressing in
            withAnimation(.snappySpring) {
                isPressed = pressing
            }
        }
        .hapticFeedback(.impact(.medium), trigger: .tap)
        .soundEffect(.buttonTap, trigger: .tap)
        .interactiveParticles(config: .sparkles, triggerOnHover: false)
    }
    
    private func triggerRipple() {
        ripplePhase = 0
        withAnimation(.easeOut(duration: 0.8)) {
            ripplePhase = 1.0
        }
    }
}

// MARK: - Parallax Card
public struct ParallaxCard<Content: View>: View {
    let content: Content
    @State private var offset: CGSize = .zero
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @Environment(\.theme) private var theme
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.colors.surface)
                    .glassmorphism(intensity: .medium)
            )
            .rotation3D(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
            .rotation3D(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
            .offset(offset)
            .scaleEffect(offset == .zero ? 1.0 : 1.02)
            .animation(.snappySpring, value: offset)
            .animation(.snappySpring, value: rotationX)
            .animation(.snappySpring, value: rotationY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation
                        offset = CGSize(
                            width: translation.x * 0.3,
                            height: translation.y * 0.3
                        )
                        rotationY = Double(translation.x / 300) * 15
                        rotationX = Double(-translation.y / 300) * 15
                    }
                    .onEnded { _ in
                        withAnimation(.gentleSpring) {
                            offset = .zero
                            rotationX = 0
                            rotationY = 0
                        }
                    }
            )
            .shadow(
                color: theme.colors.primary.opacity(0.1),
                radius: offset == .zero ? 8 : 20,
                x: offset.width * 0.1,
                y: offset.height * 0.1 + 4
            )
    }
}

// MARK: - Magnetic Gesture Handler
public struct MagneticGestureHandler<Content: View>: View {
    let content: Content
    let magneticStrength: CGFloat
    let attractionRadius: CGFloat
    
    @State private var position: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var isNearTarget: Bool = false
    @State private var targetPosition: CGPoint = .zero
    
    public init(
        magneticStrength: CGFloat = 30,
        attractionRadius: CGFloat = 60,
        @ViewBuilder content: () -> Content
    ) {
        self.magneticStrength = magneticStrength
        self.attractionRadius = attractionRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .offset(dragOffset)
            .scaleEffect(isNearTarget ? 1.1 : 1.0)
            .animation(.magneticSpring, value: dragOffset)
            .animation(.snappySpring, value: isNearTarget)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let distance = distanceFromTarget(value.location)
                        
                        if distance <= attractionRadius {
                            isNearTarget = true
                            let attraction = magneticStrength * (1 - distance / attractionRadius)
                            let direction = directionToTarget(from: value.location)
                            
                            dragOffset = CGSize(
                                width: value.translation.x + direction.x * attraction,
                                height: value.translation.y + direction.y * attraction
                            )
                        } else {
                            isNearTarget = false
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.gentleSpring) {
                            if isNearTarget {
                                // Snap to target
                                dragOffset = CGSize(
                                    width: targetPosition.x - position.x,
                                    height: targetPosition.y - position.y
                                )
                            } else {
                                dragOffset = .zero
                            }
                            isNearTarget = false
                        }
                    }
            )
            .background(
                // Invisible target for magnetic attraction
                Circle()
                    .fill(Color.clear)
                    .frame(width: attractionRadius * 2, height: attractionRadius * 2)
                    .position(targetPosition)
                    .onAppear {
                        // Set default target position
                        targetPosition = CGPoint(x: 200, y: 200)
                    }
            )
    }
    
    private func distanceFromTarget(_ point: CGPoint) -> CGFloat {
        let dx = point.x - targetPosition.x
        let dy = point.y - targetPosition.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func directionToTarget(from point: CGPoint) -> CGPoint {
        let dx = targetPosition.x - point.x
        let dy = targetPosition.y - point.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance == 0 { return .zero }
        
        return CGPoint(x: dx / distance, y: dy / distance)
    }
}

// MARK: - 3D Card Flip Animation
public struct Card3DFlip<Front: View, Back: View>: View {
    let front: Front
    let back: Back
    @State private var isFlipped = false
    @State private var rotationAngle: Double = 0
    
    public init(@ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.front = front()
        self.back = back()
    }
    
    public var body: some View {
        ZStack {
            if !isFlipped {
                front
                    .rotation3D(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0))
                    .opacity(rotationAngle < 90 ? 1 : 0)
            } else {
                back
                    .rotation3D(.degrees(rotationAngle + 180), axis: (x: 0, y: 1, z: 0))
                    .opacity(rotationAngle < 90 ? 0 : 1)
            }
        }
        .onTapGesture {
            flipCard()
        }
        .hapticFeedback(.impact(.light), trigger: .tap)
        .soundEffect(.whoosh, trigger: .tap)
    }
    
    private func flipCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            rotationAngle += 180
            isFlipped.toggle()
        }
    }
}

// MARK: - Shimmer Loading Effect
public struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    let gradient: LinearGradient
    
    public init(gradient: LinearGradient? = nil) {
        self.gradient = gradient ?? LinearGradient(
            colors: [
                Color.gray.opacity(0.3),
                Color.white.opacity(0.8),
                Color.gray.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    public var body: some View {
        Rectangle()
            .fill(gradient)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black,
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: 0.3, y: 1.0)
                    .offset(x: -100 + 300 * phase)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

// MARK: - Gradient Mesh Background
public struct GradientMeshBackground: View {
    let colors: [Color]
    @State private var animationPhase: CGFloat = 0
    
    public init(colors: [Color]) {
        self.colors = colors
    }
    
    public var body: some View {
        Canvas { context, size in
            let gridSize = 4
            let cellWidth = size.width / CGFloat(gridSize)
            let cellHeight = size.height / CGFloat(gridSize)
            
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let x = CGFloat(col) * cellWidth
                    let y = CGFloat(row) * cellHeight
                    
                    let colorIndex = (row * gridSize + col) % colors.count
                    let baseColor = colors[colorIndex]
                    
                    let animatedHue = (animationPhase + CGFloat(colorIndex) * 0.1).truncatingRemainder(dividingBy: 1.0)
                    let animatedColor = baseColor.hueRotation(.degrees(Double(animatedHue) * 60))
                    
                    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                    let gradient = Gradient(colors: [animatedColor, animatedColor.opacity(0.7)])
                    
                    context.fill(
                        Path(rect),
                        with: .radialGradient(
                            gradient,
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 0,
                            endRadius: max(cellWidth, cellHeight)
                        )
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
        .blur(radius: 40)
        .saturation(1.2)
        .contrast(1.1)
    }
}

// MARK: - Custom Navigation Extensions
extension Animation {
    static var magneticSpring: Animation {
        .spring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.05)
    }
    
    static var gentleSpring: Animation {
        .spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.4)
    }
}