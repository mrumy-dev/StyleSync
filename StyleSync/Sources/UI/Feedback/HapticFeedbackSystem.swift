import SwiftUI
import UIKit
import CoreHaptics
import Combine

// MARK: - Haptic Feedback System
public class HapticFeedbackManager: ObservableObject {
    
    // MARK: - Properties
    @Published public var isHapticsEnabled: Bool = true
    @Published public var hapticIntensity: HapticIntensity = .medium
    @Published public var isAdvancedHapticsSupported: Bool = false
    
    private var hapticEngine: CHHapticEngine?
    private var impactFeedbackGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private var notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    private var selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Initialization
    public init() {
        setupHapticEngine()
        setupFeedbackGenerators()
        checkAdvancedHapticsSupport()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            isAdvancedHapticsSupported = true
            
            // Handle engine stopped
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.restartHapticEngine()
            }
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartHapticEngine()
            }
        } catch {
            print("Failed to start haptic engine: \(error)")
            isAdvancedHapticsSupported = false
        }
    }
    
    private func setupFeedbackGenerators() {
        // Pre-initialize impact generators
        for style in UIImpactFeedbackGenerator.FeedbackStyle.allCases {
            impactFeedbackGenerators[style] = UIImpactFeedbackGenerator(style: style)
        }
        
        // Prepare generators
        impactFeedbackGenerators.values.forEach { $0.prepare() }
        notificationFeedbackGenerator.prepare()
        selectionFeedbackGenerator.prepare()
    }
    
    private func checkAdvancedHapticsSupport() {
        isAdvancedHapticsSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    private func restartHapticEngine() {
        hapticEngine?.stop { _ in
            do {
                try self.hapticEngine?.start()
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
    }
    
    // MARK: - Public Interface
    public func playHaptic(_ hapticType: HapticType) {
        guard isHapticsEnabled else { return }
        
        switch hapticType {
        case .impact(let style):
            playImpactFeedback(style: style)
        case .notification(let type):
            playNotificationFeedback(type: type)
        case .selection:
            playSelectionFeedback()
        case .custom(let pattern):
            playCustomHaptic(pattern: pattern)
        case .advanced(let pattern):
            playAdvancedHaptic(pattern: pattern)
        }
    }
    
    // MARK: - Basic Haptic Feedback
    private func playImpactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let adjustedStyle = adjustStyleForIntensity(style)
        impactFeedbackGenerators[adjustedStyle]?.impactOccurred()
    }
    
    private func playNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedbackGenerator.notificationOccurred(type)
    }
    
    private func playSelectionFeedback() {
        selectionFeedbackGenerator.selectionChanged()
    }
    
    private func adjustStyleForIntensity(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch hapticIntensity {
        case .light:
            return .light
        case .medium:
            return style
        case .strong:
            return style == .light ? .medium : .heavy
        case .heavy:
            return .heavy
        }
    }
    
    // MARK: - Custom Haptic Patterns
    private func playCustomHaptic(pattern: HapticPattern) {
        guard isAdvancedHapticsSupported, let engine = hapticEngine else {
            // Fallback to basic haptics
            playFallbackPattern(pattern)
            return
        }
        
        do {
            let hapticPattern = try createCHHapticPattern(from: pattern)
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic: \(error)")
            playFallbackPattern(pattern)
        }
    }
    
    private func playAdvancedHaptic(pattern: AdvancedHapticPattern) {
        guard isAdvancedHapticsSupported, let engine = hapticEngine else {
            // Fallback to basic haptics
            playFallbackAdvancedPattern(pattern)
            return
        }
        
        do {
            let hapticPattern = try createAdvancedCHHapticPattern(from: pattern)
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play advanced haptic: \(error)")
            playFallbackAdvancedPattern(pattern)
        }
    }
    
    private func createCHHapticPattern(from pattern: HapticPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        for (index, element) in pattern.elements.enumerated() {
            let time = TimeInterval(index) * pattern.spacing
            
            let intensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: Float(element.intensity * hapticIntensity.multiplier)
            )
            
            let sharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: Float(element.sharpness)
            )
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            )
            
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createAdvancedCHHapticPattern(from pattern: AdvancedHapticPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var parameters: [CHHapticParameterCurve] = []
        
        // Create events
        for event in pattern.events {
            let intensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: Float(event.intensity * hapticIntensity.multiplier)
            )
            
            let sharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: Float(event.sharpness)
            )
            
            let hapticEvent = CHHapticEvent(
                eventType: event.type == .transient ? .hapticTransient : .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: event.time,
                duration: event.duration
            )
            
            events.append(hapticEvent)
        }
        
        // Create parameter curves
        for curve in pattern.parameterCurves {
            let controlPoints = curve.controlPoints.map { point in
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: point.time,
                    value: Float(point.value * hapticIntensity.multiplier)
                )
            }
            
            let parameterCurve = CHHapticParameterCurve(
                parameterID: curve.parameter == .intensity ? .hapticIntensityControl : .hapticSharpnessControl,
                controlPoints: controlPoints,
                relativeTime: 0
            )
            
            parameters.append(parameterCurve)
        }
        
        return try CHHapticPattern(events: events, parameterCurves: parameters)
    }
    
    // MARK: - Fallback Patterns
    private func playFallbackPattern(_ pattern: HapticPattern) {
        for (index, element) in pattern.elements.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * pattern.spacing) {
                let style: UIImpactFeedbackGenerator.FeedbackStyle = element.intensity > 0.7 ? .heavy : element.intensity > 0.4 ? .medium : .light
                self.impactFeedbackGenerators[style]?.impactOccurred()
            }
        }
    }
    
    private func playFallbackAdvancedPattern(_ pattern: AdvancedHapticPattern) {
        for event in pattern.events {
            DispatchQueue.main.asyncAfter(deadline: .now() + event.time) {
                let style: UIImpactFeedbackGenerator.FeedbackStyle = event.intensity > 0.7 ? .heavy : event.intensity > 0.4 ? .medium : .light
                self.impactFeedbackGenerators[style]?.impactOccurred()
            }
        }
    }
}

// MARK: - Haptic Types and Patterns
public enum HapticType {
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
    case selection
    case custom(HapticPattern)
    case advanced(AdvancedHapticPattern)
}

public enum HapticIntensity: CaseIterable {
    case light
    case medium
    case strong
    case heavy
    
    public var multiplier: Double {
        switch self {
        case .light: return 0.5
        case .medium: return 1.0
        case .strong: return 1.5
        case .heavy: return 2.0
        }
    }
}

public struct HapticPattern {
    public let elements: [HapticElement]
    public let spacing: Double // Time between elements in seconds
    
    public init(elements: [HapticElement], spacing: Double = 0.1) {
        self.elements = elements
        self.spacing = spacing
    }
}

public struct HapticElement {
    public let intensity: Double // 0.0 to 1.0
    public let sharpness: Double // 0.0 to 1.0
    
    public init(intensity: Double, sharpness: Double = 0.5) {
        self.intensity = max(0, min(1, intensity))
        self.sharpness = max(0, min(1, sharpness))
    }
}

public struct AdvancedHapticPattern {
    public let events: [AdvancedHapticEvent]
    public let parameterCurves: [HapticParameterCurve]
    
    public init(events: [AdvancedHapticEvent], parameterCurves: [HapticParameterCurve] = []) {
        self.events = events
        self.parameterCurves = parameterCurves
    }
}

public struct AdvancedHapticEvent {
    public enum EventType {
        case transient
        case continuous
    }
    
    public let type: EventType
    public let time: Double
    public let duration: Double
    public let intensity: Double
    public let sharpness: Double
    
    public init(type: EventType, time: Double, duration: Double = 0, intensity: Double, sharpness: Double = 0.5) {
        self.type = type
        self.time = time
        self.duration = duration
        self.intensity = max(0, min(1, intensity))
        self.sharpness = max(0, min(1, sharpness))
    }
}

public struct HapticParameterCurve {
    public enum ParameterType {
        case intensity
        case sharpness
    }
    
    public struct ControlPoint {
        public let time: Double
        public let value: Double
        
        public init(time: Double, value: Double) {
            self.time = time
            self.value = max(0, min(1, value))
        }
    }
    
    public let parameter: ParameterType
    public let controlPoints: [ControlPoint]
    
    public init(parameter: ParameterType, controlPoints: [ControlPoint]) {
        self.parameter = parameter
        self.controlPoints = controlPoints
    }
}

// MARK: - Preset Haptic Patterns
public extension HapticPattern {
    static let tap = HapticPattern(
        elements: [HapticElement(intensity: 0.8, sharpness: 0.8)],
        spacing: 0
    )
    
    static let doubleTap = HapticPattern(
        elements: [
            HapticElement(intensity: 0.6, sharpness: 0.7),
            HapticElement(intensity: 0.8, sharpness: 0.9)
        ],
        spacing: 0.1
    )
    
    static let heartbeat = HapticPattern(
        elements: [
            HapticElement(intensity: 0.5, sharpness: 0.3),
            HapticElement(intensity: 0.8, sharpness: 0.6)
        ],
        spacing: 0.15
    )
    
    static let pulse = HapticPattern(
        elements: Array(repeating: HapticElement(intensity: 0.6, sharpness: 0.4), count: 3),
        spacing: 0.2
    )
    
    static let wave = HapticPattern(
        elements: [0.2, 0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4, 0.2].map { intensity in
            HapticElement(intensity: intensity, sharpness: 0.5)
        },
        spacing: 0.05
    )
    
    static let drumroll = HapticPattern(
        elements: Array(repeating: HapticElement(intensity: 0.7, sharpness: 0.8), count: 10),
        spacing: 0.03
    )
    
    static let success = HapticPattern(
        elements: [
            HapticElement(intensity: 0.4, sharpness: 0.2),
            HapticElement(intensity: 0.6, sharpness: 0.4),
            HapticElement(intensity: 1.0, sharpness: 0.8)
        ],
        spacing: 0.08
    )
    
    static let error = HapticPattern(
        elements: [
            HapticElement(intensity: 1.0, sharpness: 1.0),
            HapticElement(intensity: 0.8, sharpness: 0.9),
            HapticElement(intensity: 1.0, sharpness: 1.0)
        ],
        spacing: 0.06
    )
}

public extension AdvancedHapticPattern {
    static let crescendo = AdvancedHapticPattern(
        events: [
            AdvancedHapticEvent(type: .continuous, time: 0, duration: 1.0, intensity: 0.2, sharpness: 0.3)
        ],
        parameterCurves: [
            HapticParameterCurve(parameter: .intensity, controlPoints: [
                HapticParameterCurve.ControlPoint(time: 0, value: 0.2),
                HapticParameterCurve.ControlPoint(time: 0.5, value: 0.6),
                HapticParameterCurve.ControlPoint(time: 1.0, value: 1.0)
            ])
        ]
    )
    
    static let bounce = AdvancedHapticPattern(
        events: [
            AdvancedHapticEvent(type: .transient, time: 0, intensity: 1.0, sharpness: 0.8),
            AdvancedHapticEvent(type: .transient, time: 0.2, intensity: 0.6, sharpness: 0.6),
            AdvancedHapticEvent(type: .transient, time: 0.35, intensity: 0.3, sharpness: 0.4),
            AdvancedHapticEvent(type: .transient, time: 0.45, intensity: 0.15, sharpness: 0.2)
        ]
    )
    
    static let whoosh = AdvancedHapticPattern(
        events: [
            AdvancedHapticEvent(type: .continuous, time: 0, duration: 0.3, intensity: 0.8, sharpness: 0.2)
        ],
        parameterCurves: [
            HapticParameterCurve(parameter: .intensity, controlPoints: [
                HapticParameterCurve.ControlPoint(time: 0, value: 0.8),
                HapticParameterCurve.ControlPoint(time: 0.1, value: 1.0),
                HapticParameterCurve.ControlPoint(time: 0.3, value: 0.0)
            ]),
            HapticParameterCurve(parameter: .sharpness, controlPoints: [
                HapticParameterCurve.ControlPoint(time: 0, value: 0.2),
                HapticParameterCurve.ControlPoint(time: 0.3, value: 0.8)
            ])
        ]
    )
}

// MARK: - Extensions
extension UIImpactFeedbackGenerator.FeedbackStyle: CaseIterable {
    public static var allCases: [UIImpactFeedbackGenerator.FeedbackStyle] {
        return [.light, .medium, .heavy, .rigid, .soft]
    }
}

// MARK: - SwiftUI Integration
public struct HapticModifier: ViewModifier {
    let hapticType: HapticType
    let trigger: HapticTrigger
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    
    public init(hapticType: HapticType, trigger: HapticTrigger = .tap) {
        self.hapticType = hapticType
        self.trigger = trigger
    }
    
    public func body(content: Content) -> some View {
        switch trigger {
        case .tap:
            content.onTapGesture {
                hapticManager.playHaptic(hapticType)
            }
        case .longPress:
            content.onLongPressGesture {
                hapticManager.playHaptic(hapticType)
            }
        case .hover:
            content.onHover { isHovering in
                if isHovering {
                    hapticManager.playHaptic(hapticType)
                }
            }
        case .appear:
            content.onAppear {
                hapticManager.playHaptic(hapticType)
            }
        case .manual:
            content
        }
    }
}

public enum HapticTrigger {
    case tap
    case longPress
    case hover
    case appear
    case manual
}

// MARK: - View Extensions
public extension View {
    func hapticFeedback(
        _ hapticType: HapticType,
        trigger: HapticTrigger = .tap
    ) -> some View {
        modifier(HapticModifier(hapticType: hapticType, trigger: trigger))
    }
    
    func tapWithHaptic(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        action: @escaping () -> Void = {}
    ) -> some View {
        self
            .hapticFeedback(.impact(style), trigger: .tap)
            .onTapGesture(perform: action)
    }
    
    func successHaptic() -> some View {
        hapticFeedback(.custom(.success), trigger: .appear)
    }
    
    func errorHaptic() -> some View {
        hapticFeedback(.custom(.error), trigger: .appear)
    }
}