import SwiftUI
import Combine

// MARK: - Physics Interaction System
public class PhysicsInteractionEngine: ObservableObject {
    @Published public var activeElements: [String: PhysicsElement] = [:]

    private var updateTimer: Timer?
    private let targetFPS: Double = 60.0
    private var lastUpdateTime: CFTimeInterval = 0

    public static let shared = PhysicsInteractionEngine()

    private init() {
        startPhysicsLoop()
    }

    public func addElement(_ element: PhysicsElement) {
        activeElements[element.id] = element
    }

    public func removeElement(id: String) {
        activeElements.removeValue(forKey: id)
    }

    public func updateElement(id: String, position: CGPoint) {
        activeElements[id]?.position = position
    }

    public func applyForce(id: String, force: CGVector) {
        activeElements[id]?.applyForce(force)
    }

    private func startPhysicsLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/targetFPS, repeats: true) { [weak self] _ in
            self?.updatePhysics()
        }
    }

    private func updatePhysics() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard deltaTime > 0 else { return }

        for element in activeElements.values {
            element.update(deltaTime: deltaTime)
        }
    }

    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Physics Element
public class PhysicsElement: ObservableObject, Identifiable {
    public let id: String
    @Published public var position: CGPoint
    @Published public var velocity: CGVector
    public var acceleration: CGVector = CGVector.zero
    public var mass: CGFloat = 1.0
    public var friction: CGFloat = 0.95
    public var bounciness: CGFloat = 0.8
    public var boundaries: CGRect = .zero

    private var forces: [CGVector] = []

    public init(id: String, position: CGPoint, mass: CGFloat = 1.0) {
        self.id = id
        self.position = position
        self.velocity = CGVector.zero
        self.mass = mass
    }

    public func applyForce(_ force: CGVector) {
        forces.append(force)
    }

    public func update(deltaTime: TimeInterval) {
        // Calculate net force
        let netForce = forces.reduce(CGVector.zero) { result, force in
            CGVector(dx: result.dx + force.dx, dy: result.dy + force.dy)
        }

        // Clear forces for next frame
        forces.removeAll()

        // Apply Newton's second law (F = ma, so a = F/m)
        acceleration = CGVector(
            dx: netForce.dx / mass,
            dy: netForce.dy / mass
        )

        // Update velocity
        velocity = CGVector(
            dx: velocity.dx + acceleration.dx * CGFloat(deltaTime),
            dy: velocity.dy + acceleration.dy * CGFloat(deltaTime)
        )

        // Apply friction
        velocity = CGVector(
            dx: velocity.dx * friction,
            dy: velocity.dy * friction
        )

        // Update position
        position = CGPoint(
            x: position.x + velocity.dx * CGFloat(deltaTime),
            y: position.y + velocity.dy * CGFloat(deltaTime)
        )

        // Handle boundaries
        handleBoundaryCollisions()
    }

    private func handleBoundaryCollisions() {
        guard !boundaries.isEmpty else { return }

        if position.x < boundaries.minX {
            position.x = boundaries.minX
            velocity.dx *= -bounciness
        } else if position.x > boundaries.maxX {
            position.x = boundaries.maxX
            velocity.dx *= -bounciness
        }

        if position.y < boundaries.minY {
            position.y = boundaries.minY
            velocity.dy *= -bounciness
        } else if position.y > boundaries.maxY {
            position.y = boundaries.maxY
            velocity.dy *= -bounciness
        }
    }
}

// MARK: - Drag and Drop with Physics
public struct PhysicsDragView<Content: View>: View {
    let content: Content
    let physicsConfig: PhysicsConfig

    @StateObject private var physicsEngine = PhysicsInteractionEngine.shared
    @StateObject private var element: PhysicsElement
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var lastDragPosition = CGPoint.zero
    @State private var trailPoints: [TrailPoint] = []

    public init(
        id: String,
        physicsConfig: PhysicsConfig = PhysicsConfig(),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.physicsConfig = physicsConfig
        self._element = StateObject(wrappedValue: PhysicsElement(
            id: id,
            position: .zero,
            mass: physicsConfig.mass
        ))
    }

    public var body: some View {
        ZStack {
            // Trail effect
            if physicsConfig.showTrail {
                ForEach(Array(trailPoints.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(physicsConfig.trailColor)
                        .frame(width: point.size, height: point.size)
                        .position(point.position)
                        .opacity(point.opacity)
                }
            }

            // Main content
            content
                .offset(dragOffset)
                .scaleEffect(isDragging ? physicsConfig.dragScale : 1.0)
                .rotation3D(
                    .degrees(isDragging ? physicsConfig.dragRotation : 0),
                    axis: (x: 1, y: 1, z: 0),
                    perspective: 0.5
                )
                .animation(.interactiveSpring(
                    response: physicsConfig.springResponse,
                    dampingFraction: physicsConfig.springDamping
                ), value: dragOffset)
                .animation(.spring(
                    response: 0.3,
                    dampingFraction: 0.7
                ), value: isDragging)
        }
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastDragPosition = value.location
                        HapticFeedbackSystem.shared.impact(.light)
                    }

                    dragOffset = value.translation

                    // Apply magnetic force if enabled
                    if physicsConfig.magneticForce > 0 {
                        let magneticOffset = calculateMagneticForce(
                            dragPosition: value.location,
                            strength: physicsConfig.magneticForce
                        )
                        dragOffset = CGSize(
                            width: dragOffset.width + magneticOffset.dx,
                            height: dragOffset.height + magneticOffset.dy
                        )
                    }

                    // Update trail
                    updateTrail(at: value.location)

                    // Update physics element
                    element.position = value.location
                    element.velocity = calculateVelocity(
                        current: value.location,
                        previous: lastDragPosition
                    )
                    lastDragPosition = value.location
                }
                .onEnded { value in
                    isDragging = false

                    // Apply physics-based momentum
                    let momentum = CGVector(
                        dx: value.velocity.x * physicsConfig.momentumMultiplier,
                        dy: value.velocity.y * physicsConfig.momentumMultiplier
                    )

                    element.applyForce(momentum)

                    // Animate back to rest position with physics
                    withAnimation(.interactiveSpring(
                        response: physicsConfig.returnSpringResponse,
                        dampingFraction: physicsConfig.returnSpringDamping
                    )) {
                        dragOffset = .zero
                    }

                    // Haptic feedback
                    HapticFeedbackSystem.shared.impact(
                        magnitude(momentum) > 500 ? .heavy : .medium
                    )

                    // Clear trail
                    clearTrail()
                }
        )
        .onAppear {
            physicsEngine.addElement(element)
            setupPhysicsProperties()
        }
        .onDisappear {
            physicsEngine.removeElement(id: element.id)
        }
    }

    private func setupPhysicsProperties() {
        element.mass = physicsConfig.mass
        element.friction = physicsConfig.friction
        element.bounciness = physicsConfig.bounciness
    }

    private func calculateMagneticForce(dragPosition: CGPoint, strength: CGFloat) -> CGVector {
        // Simple magnetic attraction to center
        let center = CGPoint(x: 0, y: 0) // Relative to drag start
        let dx = center.x - dragPosition.x
        let dy = center.y - dragPosition.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 0 else { return CGVector.zero }

        let forceStrength = min(strength / distance, strength * 0.1)
        return CGVector(
            dx: (dx / distance) * forceStrength,
            dy: (dy / distance) * forceStrength
        )
    }

    private func calculateVelocity(current: CGPoint, previous: CGPoint) -> CGVector {
        return CGVector(
            dx: current.x - previous.x,
            dy: current.y - previous.y
        )
    }

    private func updateTrail(at position: CGPoint) {
        let trailPoint = TrailPoint(
            position: position,
            opacity: 1.0,
            size: physicsConfig.trailSize
        )

        trailPoints.append(trailPoint)

        // Limit trail length
        if trailPoints.count > physicsConfig.maxTrailPoints {
            trailPoints.removeFirst()
        }

        // Fade trail points
        for (index, _) in trailPoints.enumerated() {
            let progress = Double(index) / Double(trailPoints.count)
            trailPoints[index].opacity = progress * 0.8
            trailPoints[index].size = physicsConfig.trailSize * CGFloat(0.5 + progress * 0.5)
        }
    }

    private func clearTrail() {
        withAnimation(.easeOut(duration: 1.0)) {
            for index in trailPoints.indices {
                trailPoints[index].opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            trailPoints.removeAll()
        }
    }

    private func magnitude(_ vector: CGVector) -> CGFloat {
        return sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
    }
}

// MARK: - Physics Configuration
public struct PhysicsConfig {
    public var mass: CGFloat = 1.0
    public var friction: CGFloat = 0.95
    public var bounciness: CGFloat = 0.8
    public var springResponse: Double = 0.4
    public var springDamping: Double = 0.8
    public var returnSpringResponse: Double = 0.6
    public var returnSpringDamping: Double = 0.7
    public var momentumMultiplier: CGFloat = 0.3
    public var dragScale: CGFloat = 1.05
    public var dragRotation: Double = 5.0
    public var magneticForce: CGFloat = 0
    public var showTrail: Bool = false
    public var trailColor: Color = .blue.opacity(0.6)
    public var trailSize: CGFloat = 8
    public var maxTrailPoints: Int = 20

    public init() {}

    public static let light = PhysicsConfig(
        mass: 0.5,
        springResponse: 0.3,
        springDamping: 0.9
    )

    public static let heavy = PhysicsConfig(
        mass: 2.0,
        friction: 0.9,
        springResponse: 0.6,
        springDamping: 0.6
    )

    public static let bouncy = PhysicsConfig(
        bounciness: 1.2,
        springResponse: 0.3,
        springDamping: 0.5,
        momentumMultiplier: 0.8
    )

    public static let magnetic = PhysicsConfig(
        magneticForce: 300,
        showTrail: true
    )

    public static let elastic = PhysicsConfig(
        bounciness: 0.9,
        springResponse: 0.2,
        springDamping: 0.4,
        dragScale: 1.1,
        dragRotation: 10
    )
}

// MARK: - Trail Point
struct TrailPoint {
    var position: CGPoint
    var opacity: Double
    var size: CGFloat
}

// MARK: - Swipe Actions with Feedback
public struct PhysicsSwipeActions<Content: View>: View {
    let content: Content
    let actions: [SwipeAction]
    let threshold: CGFloat

    @State private var dragOffset: CGFloat = 0
    @State private var currentAction: SwipeAction?
    @State private var isAnimating = false
    @State private var feedbackTriggered = false

    public init(
        threshold: CGFloat = 80,
        actions: [SwipeAction],
        @ViewBuilder content: () -> Content
    ) {
        self.threshold = threshold
        self.actions = actions
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // Action backgrounds
            HStack {
                if dragOffset > 0 {
                    // Right swipe actions
                    ForEach(actions.filter { $0.direction == .right }) { action in
                        actionBackground(action)
                    }
                    Spacer()
                } else {
                    Spacer()
                    // Left swipe actions
                    ForEach(actions.filter { $0.direction == .left }) { action in
                        actionBackground(action)
                    }
                }
            }

            // Main content
            content
                .offset(x: dragOffset)
                .scaleEffect(
                    y: 1.0 - abs(dragOffset) * 0.0005,
                    anchor: dragOffset > 0 ? .leading : .trailing
                )
                .animation(.interactiveSpring(
                    response: 0.4,
                    dampingFraction: 0.8
                ), value: dragOffset)
        }
        .clipped()
        .gesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    let translation = value.translation.x
                    let dampedTranslation = dampening(translation)
                    dragOffset = dampedTranslation

                    // Trigger haptic feedback at threshold
                    let absOffset = abs(dragOffset)
                    if absOffset > threshold && !feedbackTriggered {
                        HapticFeedbackSystem.shared.impact(.medium)
                        feedbackTriggered = true

                        // Update current action
                        currentAction = getActiveAction(offset: dragOffset)
                    } else if absOffset < threshold && feedbackTriggered {
                        feedbackTriggered = false
                        currentAction = nil
                    }
                }
                .onEnded { value in
                    let finalOffset = dragOffset
                    let absOffset = abs(finalOffset)

                    if absOffset > threshold, let action = getActiveAction(offset: finalOffset) {
                        // Execute action
                        executeAction(action)
                    } else {
                        // Spring back
                        withAnimation(.interactiveSpring(
                            response: 0.5,
                            dampingFraction: 0.7
                        )) {
                            dragOffset = 0
                        }
                    }

                    feedbackTriggered = false
                    currentAction = nil
                }
        )
    }

    @ViewBuilder
    private func actionBackground(_ action: SwipeAction) -> some View {
        let isActive = currentAction?.id == action.id
        let progress = min(abs(dragOffset) / threshold, 1.0)

        HStack(spacing: 12) {
            Image(systemName: action.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .scaleEffect(isActive ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)

            if progress > 0.7 {
                Text(action.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: max(abs(dragOffset) * 0.8, 60))
        .frame(maxHeight: .infinity)
        .background(action.color)
        .opacity(progress)
    }

    private func dampening(_ translation: CGFloat) -> CGFloat {
        let maxTranslation: CGFloat = 200
        let dampeningFactor: CGFloat = 0.3

        if abs(translation) <= maxTranslation {
            return translation
        } else {
            let excess = abs(translation) - maxTranslation
            let dampened = maxTranslation + excess * dampeningFactor
            return translation > 0 ? dampened : -dampened
        }
    }

    private func getActiveAction(offset: CGFloat) -> SwipeAction? {
        let direction: SwipeDirection = offset > 0 ? .right : .left
        return actions.first { $0.direction == direction }
    }

    private func executeAction(_ action: SwipeAction) {
        isAnimating = true

        // Animate to full width
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = action.direction == .right ? 300 : -300
        }

        // Execute action after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action.handler()

            // Animate back
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                dragOffset = 0
                isAnimating = false
            }
        }

        // Haptic feedback
        HapticFeedbackSystem.shared.impact(action.impactStyle)
    }
}

// MARK: - Swipe Action
public struct SwipeAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let iconName: String
    public let color: Color
    public let direction: SwipeDirection
    public let impactStyle: HapticStyle
    public let handler: () -> Void

    public init(
        title: String,
        iconName: String,
        color: Color,
        direction: SwipeDirection,
        impactStyle: HapticStyle = .medium,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.color = color
        self.direction = direction
        self.impactStyle = impactStyle
        self.handler = handler
    }
}

public enum SwipeDirection {
    case left, right
}

// MARK: - Pull to Refresh with Physics
public struct PhysicsPullToRefresh<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    let threshold: CGFloat

    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var refreshTriggered = false
    @State private var indicatorRotation: Double = 0
    @State private var indicatorScale: CGFloat = 0

    public init(
        threshold: CGFloat = 80,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.threshold = threshold
        self.onRefresh = onRefresh
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Pull indicator
                pullIndicator
                    .frame(height: max(pullOffset, 0))
                    .clipped()

                // Main content
                content
                    .offset(y: max(pullOffset, 0))
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if value.translation.y > 0 && !isRefreshing {
                            let translation = value.translation.y
                            pullOffset = dampening(translation)

                            // Update indicator
                            let progress = min(pullOffset / threshold, 1.0)
                            indicatorScale = progress
                            indicatorRotation = progress * 180

                            // Trigger haptic at threshold
                            if pullOffset > threshold && !refreshTriggered {
                                HapticFeedbackSystem.shared.impact(.light)
                                refreshTriggered = true
                            }
                        }
                    }
                    .onEnded { value in
                        if pullOffset > threshold && !isRefreshing {
                            triggerRefresh()
                        } else {
                            springBack()
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private var pullIndicator: some View {
        VStack {
            Spacer()

            ZStack {
                // Background circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)

                // Loading indicator
                if isRefreshing {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(indicatorRotation))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: indicatorRotation)
                } else {
                    Image(systemName: "arrow.down")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(pullOffset > threshold ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pullOffset > threshold)
                }
            }
            .scaleEffect(indicatorScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: indicatorScale)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private func dampening(_ translation: CGFloat) -> CGFloat {
        let resistance: CGFloat = 0.4
        return translation * resistance
    }

    private func triggerRefresh() {
        isRefreshing = true
        refreshTriggered = false

        // Animate to resting position
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            pullOffset = threshold * 0.6
        }

        // Start loading animation
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            indicatorRotation = 360
        }

        // Execute refresh
        Task {
            await onRefresh()
            await MainActor.run {
                completeRefresh()
            }
        }
    }

    private func completeRefresh() {
        isRefreshing = false

        // Success feedback
        HapticFeedbackSystem.shared.impact(.success)

        // Spring back
        springBack()
    }

    private func springBack() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            pullOffset = 0
            indicatorScale = 0
            indicatorRotation = 0
        }

        refreshTriggered = false
    }
}

// MARK: - Pinch to Zoom with Physics
public struct PhysicsPinchZoom<Content: View>: View {
    let content: Content
    let minScale: CGFloat
    let maxScale: CGFloat

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    public init(
        minScale: CGFloat = 0.5,
        maxScale: CGFloat = 3.0,
        @ViewBuilder content: () -> Content
    ) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.content = content()
    }

    public var body: some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .animation(.interactiveSpring(
                response: 0.4,
                dampingFraction: 0.8
            ), value: scale)
            .animation(.interactiveSpring(
                response: 0.3,
                dampingFraction: 0.7
            ), value: offset)
            .gesture(
                SimultaneousGesture(
                    // Magnification gesture
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = max(minScale, min(maxScale, newScale))

                            // Haptic feedback at limits
                            if newScale <= minScale || newScale >= maxScale {
                                HapticFeedbackSystem.shared.impact(.light)
                            }
                        }
                        .onEnded { _ in
                            lastScale = scale

                            // Snap to 1.0 if close
                            if abs(scale - 1.0) < 0.1 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                                HapticFeedbackSystem.shared.impact(.selection)
                            }
                        },

                    // Pan gesture
                    DragGesture()
                        .onChanged { value in
                            let newOffset = CGSize(
                                width: lastOffset.width + value.translation.x,
                                height: lastOffset.height + value.translation.y
                            )
                            offset = constrainOffset(newOffset, scale: scale)
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
            .onTapGesture(count: 2) {
                doubleTapToZoom()
            }
    }

    private func constrainOffset(_ proposedOffset: CGSize, scale: CGFloat) -> CGSize {
        let maxOffset: CGFloat = 100 * (scale - 1)

        let constrainedX = max(-maxOffset, min(maxOffset, proposedOffset.width))
        let constrainedY = max(-maxOffset, min(maxOffset, proposedOffset.height))

        return CGSize(width: constrainedX, height: constrainedY)
    }

    private func doubleTapToZoom() {
        let targetScale: CGFloat = scale > 1.5 ? 1.0 : 2.0

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            scale = targetScale
            lastScale = targetScale

            if targetScale == 1.0 {
                offset = .zero
                lastOffset = .zero
            }
        }

        HapticFeedbackSystem.shared.impact(.medium)
    }
}

// MARK: - View Extensions
public extension View {
    func physicsDrag(
        id: String = UUID().uuidString,
        config: PhysicsConfig = PhysicsConfig()
    ) -> some View {
        PhysicsDragView(id: id, physicsConfig: config) {
            self
        }
    }

    func physicsSwipeActions(
        threshold: CGFloat = 80,
        actions: [SwipeAction]
    ) -> some View {
        PhysicsSwipeActions(threshold: threshold, actions: actions) {
            self
        }
    }

    func physicsPullToRefresh(
        threshold: CGFloat = 80,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        PhysicsPullToRefresh(threshold: threshold, onRefresh: onRefresh) {
            self
        }
    }

    func physicsPinchZoom(
        minScale: CGFloat = 0.5,
        maxScale: CGFloat = 3.0
    ) -> some View {
        PhysicsPinchZoom(minScale: minScale, maxScale: maxScale) {
            self
        }
    }

    func magneticSnap(strength: CGFloat = 20) -> some View {
        physicsDrag(config: .magnetic)
    }

    func elasticDrag() -> some View {
        physicsDrag(config: .elastic)
    }

    func lightPhysics() -> some View {
        physicsDrag(config: .light)
    }

    func heavyPhysics() -> some View {
        physicsDrag(config: .heavy)
    }
}