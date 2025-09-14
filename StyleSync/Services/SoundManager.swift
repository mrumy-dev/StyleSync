import AVFoundation
import SwiftUI

@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var isSoundEnabled: Bool = true

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }

    // MARK: - Sound Preloading

    private func preloadSounds() {
        let sounds: [SoundType] = [
            .tap, .success, .error, .whoosh, .pop, .chime, .click, .notification
        ]

        for sound in sounds {
            loadSound(sound)
        }
    }

    private func loadSound(_ soundType: SoundType) {
        guard let url = soundType.url else {
            print("Sound file not found: \(soundType.filename)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[soundType.rawValue] = player
        } catch {
            print("Failed to load sound \(soundType.filename): \(error)")
        }
    }

    // MARK: - Sound Playback

    func playSound(_ soundType: SoundType, volume: Float = 1.0) {
        guard isSoundEnabled else { return }

        if let player = audioPlayers[soundType.rawValue] {
            player.volume = volume
            player.currentTime = 0
            player.play()
        } else {
            loadSound(soundType)
            audioPlayers[soundType.rawValue]?.volume = volume
            audioPlayers[soundType.rawValue]?.play()
        }
    }

    func stopSound(_ soundType: SoundType) {
        audioPlayers[soundType.rawValue]?.stop()
    }

    func stopAllSounds() {
        audioPlayers.values.forEach { $0.stop() }
    }

    // MARK: - System Sound Effects

    func playSystemSound(_ systemSoundID: SystemSoundID) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(systemSoundID)
    }

    // Common system sounds
    func playKeyboardTap() {
        playSystemSound(1104)
    }

    func playScreenshot() {
        playSystemSound(1108)
    }

    func playLock() {
        playSystemSound(1100)
    }

    func playUnlock() {
        playSystemSound(1101)
    }

    // MARK: - Sound Effects with Haptics

    func playWithHaptic(_ soundType: SoundType, hapticType: HapticManager.HapticType, volume: Float = 1.0) {
        playSound(soundType, volume: volume)
        hapticType.trigger()
    }
}

// MARK: - Sound Types

extension SoundManager {
    enum SoundType: String, CaseIterable {
        case tap = "tap"
        case success = "success"
        case error = "error"
        case whoosh = "whoosh"
        case pop = "pop"
        case chime = "chime"
        case click = "click"
        case notification = "notification"
        case cameraShutter = "camera_shutter"
        case celebration = "celebration"
        case subtleBeep = "subtle_beep"
        case swipeSound = "swipe_sound"
        case magicChime = "magic_chime"
        case elasticSnap = "elastic_snap"

        var filename: String {
            return "\(rawValue).wav"
        }

        var url: URL? {
            return Bundle.main.url(forResource: rawValue, withExtension: "wav")
        }

        func play(volume: Float = 1.0) {
            SoundManager.shared.playSound(self, volume: volume)
        }

        var description: String {
            switch self {
            case .tap: return "Light tap sound"
            case .success: return "Success chime"
            case .error: return "Error tone"
            case .whoosh: return "Whoosh transition"
            case .pop: return "Pop sound"
            case .chime: return "Gentle chime"
            case .click: return "Click sound"
            case .notification: return "Notification tone"
            case .cameraShutter: return "Camera shutter click"
            case .celebration: return "Celebration fanfare"
            case .subtleBeep: return "Subtle interaction beep"
            case .swipeSound: return "Swipe gesture sound"
            case .magicChime: return "Magical sparkle chime"
            case .elasticSnap: return "Elastic snap sound"
            }
        }
    }
}

// MARK: - Audio Feedback Extension

extension View {
    func onTapSoundEffect(_ soundType: SoundManager.SoundType = .tap, volume: Float = 0.7) -> some View {
        onTapGesture {
            soundType.play(volume: volume)
        }
    }

    func onTapWithHaptic(
        sound: SoundManager.SoundType = .tap,
        haptic: HapticManager.HapticType = .light,
        volume: Float = 0.7
    ) -> some View {
        onTapGesture {
            SoundManager.shared.playWithHaptic(sound, hapticType: haptic, volume: volume)
        }
    }
}

// MARK: - Sound Files Creation Helper

// Note: In a real app, you would include actual sound files in the bundle
// For this template, we'll create placeholder references
extension Bundle {
    func createDefaultSoundFiles() {
        // This would typically be handled by including actual .wav files in the bundle
        // For development, you can use system sounds or record custom sounds
        print("Sound files should be added to the bundle: tap.wav, success.wav, error.wav, etc.")
    }
}