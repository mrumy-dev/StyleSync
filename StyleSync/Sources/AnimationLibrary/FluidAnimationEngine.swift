import SwiftUI
import Combine

// MARK: - Fluid Animation Engine
public class FluidAnimationEngine: ObservableObject {
    
    // MARK: - Animation State Management
    private var activeAnimations: [String: AnimationState] = [:]
    private var animationTimers: [String: Timer] = [:]
    private let targetFPS: Double = 60.0
    private let frameInterval: Double
    
    public init() {
        self.frameInterval = 1.0 / targetFPS
    }
    
    // MARK: - Core Animation Types
    public enum AnimationType {
        case spring(response: Double, dampingFraction: Double, blendDuration: Double)
        case easeInOut(duration: Double)
        case easeIn(duration: Double)
        case easeOut(duration: Double)
        case linear(duration: Double)
        case bouncy(duration: Double, intensity: Double)
        case elastic(duration: Double, bounce: Double)
        case custom(keyframes: [AnimationKeyframe])
    }
    
    public struct AnimationKeyframe {
        public let time: Double
        public let value: Double
        public let easing: EasingFunction
        
        public init(time: Double, value: Double, easing: EasingFunction = .easeInOut) {
            self.time = time
            self.value = value
            self.easing = easing
        }
    }
    
    public enum EasingFunction {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case bounceIn
        case bounceOut
        case bounceInOut
        case elasticIn
        case elasticOut
        case elasticInOut
        case backIn
        case backOut
        case backInOut
        case custom(controlPoints: (Double, Double, Double, Double))
        
        public func apply(_ t: Double) -> Double {
            let clampedT = max(0, min(1, t))
            
            switch self {
            case .linear:
                return clampedT
            case .easeIn:
                return clampedT * clampedT
            case .easeOut:
                return 1 - (1 - clampedT) * (1 - clampedT)
            case .easeInOut:
                return clampedT < 0.5 ? 2 * clampedT * clampedT : 1 - pow(-2 * clampedT + 2, 2) / 2
            case .bounceIn:
                return 1 - bounceOut(1 - clampedT)
            case .bounceOut:
                return bounceOut(clampedT)
            case .bounceInOut:
                return clampedT < 0.5 ? (1 - bounceOut(1 - 2 * clampedT)) / 2 : (1 + bounceOut(2 * clampedT - 1)) / 2
            case .elasticIn:
                return elasticIn(clampedT)
            case .elasticOut:
                return elasticOut(clampedT)
            case .elasticInOut:
                return elasticInOut(clampedT)
            case .backIn:
                return backIn(clampedT)
            case .backOut:
                return backOut(clampedT)
            case .backInOut:
                return backInOut(clampedT)
            case .custom(let controlPoints):
                return cubicBezier(clampedT, controlPoints)
            }
        }
        
        private func bounceOut(_ t: Double) -> Double {
            let n1 = 7.5625
            let d1 = 2.75
            
            if t < 1 / d1 {
                return n1 * t * t
            } else if t < 2 / d1 {
                let t2 = t - 1.5 / d1
                return n1 * t2 * t2 + 0.75
            } else if t < 2.5 / d1 {
                let t2 = t - 2.25 / d1
                return n1 * t2 * t2 + 0.9375
            } else {
                let t2 = t - 2.625 / d1
                return n1 * t2 * t2 + 0.984375
            }
        }
        
        private func elasticIn(_ t: Double) -> Double {
            let c4 = (2 * Double.pi) / 3
            return t == 0 ? 0 : t == 1 ? 1 : -pow(2, 10 * (t - 1)) * sin((t - 1.1) * c4)
        }
        
        private func elasticOut(_ t: Double) -> Double {
            let c4 = (2 * Double.pi) / 3
            return t == 0 ? 0 : t == 1 ? 1 : pow(2, -10 * t) * sin((t - 0.1) * c4) + 1
        }
        
        private func elasticInOut(_ t: Double) -> Double {
            let c5 = (2 * Double.pi) / 4.5
            return t == 0 ? 0 : t == 1 ? 1 : t < 0.5 
                ? -(pow(2, 20 * t - 10) * sin((20 * t - 11.125) * c5)) / 2
                : (pow(2, -20 * t + 10) * sin((20 * t - 11.125) * c5)) / 2 + 1
        }
        
        private func backIn(_ t: Double) -> Double {
            let c1 = 1.70158
            let c3 = c1 + 1
            return c3 * t * t * t - c1 * t * t
        }
        
        private func backOut(_ t: Double) -> Double {
            let c1 = 1.70158
            let c3 = c1 + 1
            let t2 = t - 1
            return 1 + c3 * pow(t2, 3) + c1 * pow(t2, 2)
        }
        
        private func backInOut(_ t: Double) -> Double {
            let c1 = 1.70158
            let c2 = c1 * 1.525
            
            return t < 0.5
                ? (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
                : (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
        }
        
        private func cubicBezier(_ t: Double, _ controlPoints: (Double, Double, Double, Double)) -> Double {
            let (x1, y1, x2, y2) = controlPoints
            
            func bezierX(_ t: Double) -> Double {
                return 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
            }
            
            func bezierY(_ t: Double) -> Double {
                return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
            }
            
            var low: Double = 0
            var high: Double = 1
            let epsilon: Double = 1e-6
            
            while high - low > epsilon {
                let mid = (low + high) / 2
                if bezierX(mid) < t {
                    low = mid
                } else {
                    high = mid
                }
            }
            
            return bezierY((low + high) / 2)
        }
    }
    
    // MARK: - Animation State
    private class AnimationState {
        let id: String
        let startTime: Date
        let duration: Double
        let fromValue: Double
        let toValue: Double
        let easing: EasingFunction
        var currentValue: Double
        var isComplete: Bool = false
        var onUpdate: ((Double) -> Void)?
        var onComplete: (() -> Void)?
        
        init(id: String, from: Double, to: Double, duration: Double, easing: EasingFunction) {
            self.id = id
            self.startTime = Date()
            self.duration = duration
            self.fromValue = from
            self.toValue = to
            self.easing = easing
            self.currentValue = from
        }
        
        func update() {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            let easedProgress = easing.apply(progress)
            
            currentValue = fromValue + (toValue - fromValue) * easedProgress
            isComplete = progress >= 1.0
            
            onUpdate?(currentValue)
            
            if isComplete {
                onComplete?()
            }
        }
    }
    
    // MARK: - Animation Interface
    public func animate(
        id: String,
        from: Double,
        to: Double,
        type: AnimationType,
        onUpdate: @escaping (Double) -> Void,
        onComplete: (() -> Void)? = nil
    ) {
        stopAnimation(id: id)
        
        let (duration, easing) = extractDurationAndEasing(from: type)
        let animationState = AnimationState(id: id, from: from, to: to, duration: duration, easing: easing)
        animationState.onUpdate = onUpdate
        animationState.onComplete = { [weak self] in
            self?.stopAnimation(id: id)
            onComplete?()
        }
        
        activeAnimations[id] = animationState
        startAnimationTimer(for: id)
    }
    
    private func extractDurationAndEasing(from type: AnimationType) -> (Double, EasingFunction) {
        switch type {
        case .spring(let response, let dampingFraction, _):
            return (response * 2, .custom(controlPoints: (0.4, 0, 0.2, 1)))
        case .easeInOut(let duration):
            return (duration, .easeInOut)
        case .easeIn(let duration):
            return (duration, .easeIn)
        case .easeOut(let duration):
            return (duration, .easeOut)
        case .linear(let duration):
            return (duration, .linear)
        case .bouncy(let duration, _):
            return (duration, .bounceOut)
        case .elastic(let duration, _):
            return (duration, .elasticOut)
        case .custom(let keyframes):
            let totalDuration = keyframes.last?.time ?? 1.0
            return (totalDuration, .easeInOut)
        }
    }
    
    private func startAnimationTimer(for id: String) {
        let timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let animationState = self.activeAnimations[id] else {
                return
            }
            
            animationState.update()
            
            if animationState.isComplete {
                self.stopAnimation(id: id)
            }
        }
        
        animationTimers[id] = timer
    }
    
    public func stopAnimation(id: String) {
        animationTimers[id]?.invalidate()
        animationTimers.removeValue(forKey: id)
        activeAnimations.removeValue(forKey: id)
    }
    
    public func stopAllAnimations() {
        for timer in animationTimers.values {
            timer.invalidate()
        }
        animationTimers.removeAll()
        activeAnimations.removeAll()
    }
    
    public func isAnimating(id: String) -> Bool {
        return activeAnimations[id] != nil
    }
}

// MARK: - SwiftUI Animation Extensions
public extension Animation {
    
    static var fluidSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)
    }
    
    static var smoothSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    }
    
    static var snappySpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.1)
    }
    
    static var gentleSpring: Animation {
        .spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.4)
    }
    
    static var playfulSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3)
    }
    
    static var bouncySpring: Animation {
        .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.4)
    }
    
    static func customEase(duration: Double, controlPoints: (Double, Double, Double, Double)) -> Animation {
        .timingCurve(controlPoints.0, controlPoints.1, controlPoints.2, controlPoints.3, duration: duration)
    }
    
    static var morphing: Animation {
        .timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.4)
    }
    
    static var elastic: Animation {
        .timingCurve(0.68, -0.55, 0.265, 1.55, duration: 0.6)
    }
    
    static var dramatic: Animation {
        .timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.8)
    }
}

// MARK: - Animatable Properties
public struct AnimatableVector2D: VectorArithmetic {
    public var x: Double
    public var y: Double
    
    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }
    
    public static var zero: AnimatableVector2D {
        AnimatableVector2D(x: 0, y: 0)
    }
    
    public static func + (lhs: AnimatableVector2D, rhs: AnimatableVector2D) -> AnimatableVector2D {
        AnimatableVector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func - (lhs: AnimatableVector2D, rhs: AnimatableVector2D) -> AnimatableVector2D {
        AnimatableVector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    public static func * (lhs: AnimatableVector2D, rhs: Double) -> AnimatableVector2D {
        AnimatableVector2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    public mutating func scale(by rhs: Double) {
        x *= rhs
        y *= rhs
    }
    
    public var magnitudeSquared: Double {
        x * x + y * y
    }
}

public struct AnimatableColor: VectorArithmetic {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    
    public init(red: Double = 0, green: Double = 0, blue: Double = 0, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
    
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public static var zero: AnimatableColor {
        AnimatableColor()
    }
    
    public static func + (lhs: AnimatableColor, rhs: AnimatableColor) -> AnimatableColor {
        AnimatableColor(
            red: lhs.red + rhs.red,
            green: lhs.green + rhs.green,
            blue: lhs.blue + rhs.blue,
            alpha: lhs.alpha + rhs.alpha
        )
    }
    
    public static func - (lhs: AnimatableColor, rhs: AnimatableColor) -> AnimatableColor {
        AnimatableColor(
            red: lhs.red - rhs.red,
            green: lhs.green - rhs.green,
            blue: lhs.blue - rhs.blue,
            alpha: lhs.alpha - rhs.alpha
        )
    }
    
    public static func * (lhs: AnimatableColor, rhs: Double) -> AnimatableColor {
        AnimatableColor(
            red: lhs.red * rhs,
            green: lhs.green * rhs,
            blue: lhs.blue * rhs,
            alpha: lhs.alpha * rhs
        )
    }
    
    public mutating func scale(by rhs: Double) {
        red *= rhs
        green *= rhs
        blue *= rhs
        alpha *= rhs
    }
    
    public var magnitudeSquared: Double {
        red * red + green * green + blue * blue + alpha * alpha
    }
}

// MARK: - Performance Monitor
public class AnimationPerformanceMonitor: ObservableObject {
    @Published public var currentFPS: Double = 60.0
    @Published public var averageFPS: Double = 60.0
    @Published public var frameDropCount: Int = 0
    @Published public var isOptimized: Bool = true
    
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCountBuffer: [Double] = []
    private let bufferSize = 60
    
    public init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.recordFrame()
        }
    }
    
    private func recordFrame() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let deltaTime = currentTime - lastFrameTime
            let fps = 1.0 / deltaTime
            
            frameCountBuffer.append(fps)
            if frameCountBuffer.count > bufferSize {
                frameCountBuffer.removeFirst()
            }
            
            currentFPS = fps
            averageFPS = frameCountBuffer.reduce(0, +) / Double(frameCountBuffer.count)
            
            if fps < 55.0 {
                frameDropCount += 1
            }
            
            isOptimized = averageFPS > 55.0
        }
        
        lastFrameTime = currentTime
    }
}