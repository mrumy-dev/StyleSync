import UIKit
import CoreHaptics

@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()

    private var hapticEngine: CHHapticEngine?
    private var isHapticEnabled: Bool = true

    private init() {
        setupHapticEngine()
    }

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()

            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.restartEngine()
            }

            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartEngine()
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }

    private func restartEngine() {
        do {
            try hapticEngine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
        }
    }

    func setHapticEnabled(_ enabled: Bool) {
        isHapticEnabled = enabled
    }

    // MARK: - Impact Feedback

    func lightImpact() {
        guard isHapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    func mediumImpact() {
        guard isHapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    func heavyImpact() {
        guard isHapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }

    func rigidImpact() {
        guard isHapticEnabled else { return }
        if #available(iOS 13.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
            impactFeedback.impactOccurred()
        } else {
            heavyImpact()
        }
    }

    func softImpact() {
        guard isHapticEnabled else { return }
        if #available(iOS 13.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.impactOccurred()
        } else {
            lightImpact()
        }
    }

    // MARK: - Notification Feedback

    func successFeedback() {
        guard isHapticEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    func errorFeedback() {
        guard isHapticEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }

    func warningFeedback() {
        guard isHapticEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }

    // MARK: - Selection Feedback

    func selectionFeedback() {
        guard isHapticEnabled else { return }
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }

    // MARK: - Custom Haptic Patterns

    func customTapPattern() {
        guard isHapticEnabled, let engine = hapticEngine else { return }

        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic pattern: \(error)")
        }
    }

    func doubleTabPattern() {
        guard isHapticEnabled, let engine = hapticEngine else { return }

        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)

            let firstTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: 0
            )

            let secondTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: 0.1
            )

            let pattern = try CHHapticPattern(events: [firstTap, secondTap], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play double tap haptic pattern: \(error)")
        }
    }

    func heartbeatPattern() {
        guard isHapticEnabled, let engine = hapticEngine else { return }

        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)

            let beat1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity1],
                relativeTime: 0
            )

            let beat2 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity2],
                relativeTime: 0.15
            )

            let pattern = try CHHapticPattern(events: [beat1, beat2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play heartbeat haptic pattern: \(error)")
        }
    }
}

// MARK: - Convenience Extensions

extension HapticManager {
    enum HapticType {
        case light, medium, heavy, rigid, soft
        case success, error, warning
        case selection
        case customTap, doubleTap, heartbeat

        func trigger() {
            switch self {
            case .light:
                HapticManager.shared.lightImpact()
            case .medium:
                HapticManager.shared.mediumImpact()
            case .heavy:
                HapticManager.shared.heavyImpact()
            case .rigid:
                HapticManager.shared.rigidImpact()
            case .soft:
                HapticManager.shared.softImpact()
            case .success:
                HapticManager.shared.successFeedback()
            case .error:
                HapticManager.shared.errorFeedback()
            case .warning:
                HapticManager.shared.warningFeedback()
            case .selection:
                HapticManager.shared.selectionFeedback()
            case .customTap:
                HapticManager.shared.customTapPattern()
            case .doubleTap:
                HapticManager.shared.doubleTabPattern()
            case .heartbeat:
                HapticManager.shared.heartbeatPattern()
            }
        }
    }
}