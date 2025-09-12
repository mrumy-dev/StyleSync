import SwiftUI
import AVFoundation
import Combine

// MARK: - Sound Design System
public class SoundDesignManager: ObservableObject {
    
    // MARK: - Properties
    @Published public var isSoundEnabled: Bool = true
    @Published public var masterVolume: Float = 0.8
    @Published public var soundTheme: SoundTheme = .modern
    @Published public var spatialAudioEnabled: Bool = false
    
    private var audioEngine = AVAudioEngine()
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var audioBuffers: [String: AVAudioPCMBuffer] = [:]
    private var audioSources: [String: AVAudioPlayerNode] = [:]
    private var reverbNode = AVAudioUnitReverb()
    private var delayNode = AVAudioUnitDelay()
    private var distortionNode = AVAudioUnitDistortion()
    private var eqNode = AVAudioUnitEQ()
    private var spatialMixer = AVAudioEnvironmentNode()
    
    // MARK: - Initialization
    public init() {
        setupAudioSession()
        setupAudioEngine()
        preloadSounds()
    }
    
    deinit {
        audioEngine.stop()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        // Setup audio nodes
        setupAudioNodes()
        
        // Connect nodes
        connectAudioNodes()
        
        // Start engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func setupAudioNodes() {
        // Configure reverb
        reverbNode.loadFactoryPreset(.cathedral)
        reverbNode.wetDryMix = 20
        
        // Configure delay
        delayNode.delayTime = 0.1
        delayNode.feedback = 10
        delayNode.wetDryMix = 15
        
        // Configure EQ
        eqNode.bands[0].frequency = 80
        eqNode.bands[0].gain = 0
        eqNode.bands[0].filterType = .highPass
        
        // Configure spatial audio
        spatialMixer.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        spatialMixer.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
    }
    
    private func connectAudioNodes() {
        let mainMixer = audioEngine.mainMixerNode
        
        // Connect effects chain
        audioEngine.attach(reverbNode)
        audioEngine.attach(delayNode)
        audioEngine.attach(distortionNode)
        audioEngine.attach(eqNode)
        audioEngine.attach(spatialMixer)
        
        if spatialAudioEnabled {
            audioEngine.connect(spatialMixer, to: mainMixer, format: nil)
            audioEngine.connect(eqNode, to: spatialMixer, format: nil)
        } else {
            audioEngine.connect(eqNode, to: mainMixer, format: nil)
        }
        
        audioEngine.connect(reverbNode, to: eqNode, format: nil)
        audioEngine.connect(delayNode, to: reverbNode, format: nil)
    }
    
    private func preloadSounds() {
        // Preload sound buffers for better performance
        for sound in SoundType.allCases {
            if let audioData = generateAudioData(for: sound) {
                audioBuffers[sound.id] = audioData
            }
        }
    }
    
    // MARK: - Public Interface
    public func playSound(_ sound: SoundType, volume: Float? = nil, pan: Float = 0, pitch: Float = 1.0) {
        guard isSoundEnabled else { return }
        
        let finalVolume = (volume ?? 1.0) * masterVolume
        
        if spatialAudioEnabled {
            playSpatialSound(sound, volume: finalVolume, position: AVAudio3DPoint(x: pan * 10, y: 0, z: 0), pitch: pitch)
        } else {
            playStandardSound(sound, volume: finalVolume, pan: pan, pitch: pitch)
        }
    }
    
    public func playSequence(_ sequence: [SoundSequenceElement]) {
        for (index, element) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + element.delay + Double(index) * 0.01) {
                self.playSound(element.sound, volume: element.volume, pan: element.pan, pitch: element.pitch)
            }
        }
    }
    
    public func setSoundTheme(_ theme: SoundTheme) {
        soundTheme = theme
        updateAudioProcessing(for: theme)
    }
    
    private func playStandardSound(_ sound: SoundType, volume: Float, pan: Float, pitch: Float) {
        guard let buffer = audioBuffers[sound.id] else {
            // Fallback to system sounds
            playSystemSound(sound)
            return
        }
        
        let playerNode = AVAudioPlayerNode()
        let pitchNode = AVAudioUnitTimePitch()
        
        pitchNode.pitch = pitch * 1200 // Convert to cents
        
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        
        // Connect nodes
        audioEngine.connect(playerNode, to: pitchNode, format: buffer.format)
        audioEngine.connect(pitchNode, to: delayNode, format: buffer.format)
        
        // Set volume and pan
        playerNode.volume = volume
        playerNode.pan = pan
        
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.audioEngine.detach(playerNode)
                self?.audioEngine.detach(pitchNode)
            }
        })
        
        playerNode.play()
    }
    
    private func playSpatialSound(_ sound: SoundType, volume: Float, position: AVAudio3DPoint, pitch: Float) {
        guard let buffer = audioBuffers[sound.id] else { return }
        
        let playerNode = AVAudioPlayerNode()
        let pitchNode = AVAudioUnitTimePitch()
        
        pitchNode.pitch = pitch * 1200
        
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        
        audioEngine.connect(playerNode, to: pitchNode, format: buffer.format)
        audioEngine.connect(pitchNode, to: spatialMixer, format: buffer.format)
        
        // Set 3D position
        spatialMixer.setSourceMode(.spatializeIfMono, for: playerNode)
        spatialMixer.setPosition(position, for: playerNode)
        
        playerNode.volume = volume
        
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.audioEngine.detach(playerNode)
                self?.audioEngine.detach(pitchNode)
            }
        })
        
        playerNode.play()
    }
    
    private func playSystemSound(_ sound: SoundType) {
        if let systemSoundID = sound.systemSoundID {
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }
    
    private func updateAudioProcessing(for theme: SoundTheme) {
        switch theme {
        case .modern:
            reverbNode.wetDryMix = 20
            delayNode.wetDryMix = 15
            eqNode.bands[0].gain = 0
        case .vintage:
            reverbNode.wetDryMix = 40
            delayNode.wetDryMix = 30
            eqNode.bands[0].gain = -3 // Warmer sound
        case .minimal:
            reverbNode.wetDryMix = 5
            delayNode.wetDryMix = 0
            eqNode.bands[0].gain = 2 // Crisper sound
        case .cinematic:
            reverbNode.wetDryMix = 60
            delayNode.wetDryMix = 25
            eqNode.bands[0].gain = -1
        case .cyberpunk:
            distortionNode.wetDryMix = 20
            reverbNode.wetDryMix = 30
            delayNode.wetDryMix = 40
        case .organic:
            reverbNode.loadFactoryPreset(.smallRoom)
            reverbNode.wetDryMix = 35
            delayNode.wetDryMix = 10
        }
    }
}

// MARK: - Sound Types and Themes
public enum SoundType: String, CaseIterable {
    // UI Sounds
    case buttonTap = "button_tap"
    case buttonHover = "button_hover"
    case switchToggle = "switch_toggle"
    case modalAppear = "modal_appear"
    case modalDismiss = "modal_dismiss"
    case pageTransition = "page_transition"
    case tabSwitch = "tab_switch"
    
    // Feedback Sounds
    case success = "success"
    case error = "error"
    case warning = "warning"
    case notification = "notification"
    case message = "message"
    case achievement = "achievement"
    
    // Interaction Sounds
    case swipe = "swipe"
    case scroll = "scroll"
    case pullToRefresh = "pull_refresh"
    case dropComplete = "drop_complete"
    case magneticSnap = "magnetic_snap"
    case elasticBounce = "elastic_bounce"
    
    // Animation Sounds
    case whoosh = "whoosh"
    case pop = "pop"
    case bounce = "bounce"
    case slide = "slide"
    case fade = "fade"
    case scale = "scale"
    
    // Particle Effects
    case sparkle = "sparkle"
    case shimmer = "shimmer"
    case burst = "burst"
    case crackle = "crackle"
    
    public var id: String { rawValue }
    
    public var systemSoundID: SystemSoundID? {
        switch self {
        case .buttonTap: return 1104 // Tock
        case .success: return 1106 // Camera shutter
        case .error: return 1107 // Begin recording
        case .notification: return 1315 // Anticipate
        default: return nil
        }
    }
}

public enum SoundTheme: String, CaseIterable {
    case modern = "modern"
    case vintage = "vintage"
    case minimal = "minimal"
    case cinematic = "cinematic"
    case cyberpunk = "cyberpunk"
    case organic = "organic"
    
    public var displayName: String {
        switch self {
        case .modern: return "Modern"
        case .vintage: return "Vintage"
        case .minimal: return "Minimal"
        case .cinematic: return "Cinematic"
        case .cyberpunk: return "Cyberpunk"
        case .organic: return "Organic"
        }
    }
}

public struct SoundSequenceElement {
    public let sound: SoundType
    public let delay: TimeInterval
    public let volume: Float
    public let pan: Float
    public let pitch: Float
    
    public init(
        sound: SoundType,
        delay: TimeInterval = 0,
        volume: Float = 1.0,
        pan: Float = 0,
        pitch: Float = 1.0
    ) {
        self.sound = sound
        self.delay = delay
        self.volume = volume
        self.pan = pan
        self.pitch = pitch
    }
}

// MARK: - Audio Generation
extension SoundDesignManager {
    private func generateAudioData(for sound: SoundType) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let duration: Double = sound.duration
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!,
            frameCapacity: frameCount
        ) else { return nil }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        // Generate waveform based on sound type
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let sample = generateSample(for: sound, at: time, duration: duration)
            channelData[frame] = Float(sample)
        }
        
        return buffer
    }
    
    private func generateSample(for sound: SoundType, at time: Double, duration: Double) -> Double {
        let progress = time / duration
        let envelope = applyEnvelope(progress: progress, type: sound.envelopeType)
        
        switch sound.waveform {
        case .sine:
            return sin(2 * .pi * sound.frequency * time) * envelope
        case .square:
            return (sin(2 * .pi * sound.frequency * time) > 0 ? 1 : -1) * envelope
        case .sawtooth:
            return (2 * (time * sound.frequency - floor(time * sound.frequency + 0.5))) * envelope
        case .triangle:
            let t = time * sound.frequency - floor(time * sound.frequency)
            return (t < 0.5 ? 4 * t - 1 : -4 * t + 3) * envelope
        case .noise:
            return (Double.random(in: -1...1)) * envelope
        case .impulse:
            return (time < 0.01 ? 1 : 0) * envelope
        }
    }
    
    private func applyEnvelope(progress: Double, type: EnvelopeType) -> Double {
        switch type {
        case .linear:
            return max(0, 1 - progress)
        case .exponential:
            return exp(-progress * 5)
        case .adsr:
            if progress < 0.1 { // Attack
                return progress / 0.1
            } else if progress < 0.3 { // Decay
                return 1 - (progress - 0.1) / 0.2 * 0.3
            } else if progress < 0.7 { // Sustain
                return 0.7
            } else { // Release
                return 0.7 * (1 - (progress - 0.7) / 0.3)
            }
        case .pluck:
            return exp(-progress * 3)
        case .percussion:
            return exp(-progress * 8) * (1 + sin(progress * 50))
        }
    }
}

// MARK: - Sound Properties
extension SoundType {
    var duration: Double {
        switch self {
        case .buttonTap, .switchToggle: return 0.1
        case .buttonHover, .tabSwitch: return 0.15
        case .success, .error, .warning: return 0.3
        case .modalAppear, .modalDismiss: return 0.4
        case .pageTransition, .achievement: return 0.5
        case .notification, .message: return 0.4
        case .swipe, .slide: return 0.2
        case .pullToRefresh: return 0.6
        case .whoosh: return 0.3
        case .pop, .bounce: return 0.2
        case .sparkle, .shimmer: return 0.4
        case .burst, .crackle: return 0.3
        default: return 0.2
        }
    }
    
    var frequency: Double {
        switch self {
        case .buttonTap: return 800
        case .buttonHover: return 600
        case .success: return 440
        case .error: return 200
        case .warning: return 330
        case .notification: return 550
        case .pop: return 1000
        case .bounce: return 220
        case .sparkle: return 2000
        case .whoosh: return 100
        default: return 440
        }
    }
    
    var waveform: Waveform {
        switch self {
        case .buttonTap, .buttonHover, .success: return .sine
        case .error, .warning: return .square
        case .pop, .bounce: return .triangle
        case .sparkle, .shimmer: return .noise
        case .whoosh: return .sawtooth
        default: return .sine
        }
    }
    
    var envelopeType: EnvelopeType {
        switch self {
        case .buttonTap, .buttonHover: return .pluck
        case .success, .error, .warning: return .adsr
        case .pop, .bounce: return .percussion
        case .whoosh: return .linear
        case .sparkle, .shimmer: return .exponential
        default: return .linear
        }
    }
}

enum Waveform {
    case sine, square, sawtooth, triangle, noise, impulse
}

enum EnvelopeType {
    case linear, exponential, adsr, pluck, percussion
}

// MARK: - Preset Sound Sequences
public extension SoundSequenceElement {
    static let successSequence = [
        SoundSequenceElement(sound: .pop, delay: 0, volume: 0.6, pitch: 1.0),
        SoundSequenceElement(sound: .success, delay: 0.1, volume: 0.8, pitch: 1.2),
        SoundSequenceElement(sound: .sparkle, delay: 0.2, volume: 0.4, pitch: 1.5)
    ]
    
    static let errorSequence = [
        SoundSequenceElement(sound: .error, delay: 0, volume: 0.8, pitch: 0.8),
        SoundSequenceElement(sound: .error, delay: 0.1, volume: 0.6, pitch: 0.9),
        SoundSequenceElement(sound: .error, delay: 0.15, volume: 0.4, pitch: 1.0)
    ]
    
    static let magicSpell = [
        SoundSequenceElement(sound: .shimmer, delay: 0, volume: 0.3, pitch: 2.0),
        SoundSequenceElement(sound: .whoosh, delay: 0.2, volume: 0.6, pitch: 1.0),
        SoundSequenceElement(sound: .sparkle, delay: 0.4, volume: 0.8, pitch: 1.8),
        SoundSequenceElement(sound: .pop, delay: 0.6, volume: 0.7, pitch: 1.3)
    ]
}

// MARK: - SwiftUI Integration
public struct SoundModifier: ViewModifier {
    let sound: SoundType
    let trigger: SoundTrigger
    let volume: Float?
    let pan: Float
    let pitch: Float
    
    @EnvironmentObject private var soundManager: SoundDesignManager
    
    public init(
        sound: SoundType,
        trigger: SoundTrigger = .tap,
        volume: Float? = nil,
        pan: Float = 0,
        pitch: Float = 1.0
    ) {
        self.sound = sound
        self.trigger = trigger
        self.volume = volume
        self.pan = pan
        self.pitch = pitch
    }
    
    public func body(content: Content) -> some View {
        switch trigger {
        case .tap:
            content.onTapGesture {
                soundManager.playSound(sound, volume: volume, pan: pan, pitch: pitch)
            }
        case .hover:
            content.onHover { isHovering in
                if isHovering {
                    soundManager.playSound(sound, volume: volume, pan: pan, pitch: pitch)
                }
            }
        case .appear:
            content.onAppear {
                soundManager.playSound(sound, volume: volume, pan: pan, pitch: pitch)
            }
        case .disappear:
            content.onDisappear {
                soundManager.playSound(sound, volume: volume, pan: pan, pitch: pitch)
            }
        case .manual:
            content
        }
    }
}

public enum SoundTrigger {
    case tap, hover, appear, disappear, manual
}

// MARK: - View Extensions
public extension View {
    func soundEffect(
        _ sound: SoundType,
        trigger: SoundTrigger = .tap,
        volume: Float? = nil,
        pan: Float = 0,
        pitch: Float = 1.0
    ) -> some View {
        modifier(SoundModifier(
            sound: sound,
            trigger: trigger,
            volume: volume,
            pan: pan,
            pitch: pitch
        ))
    }
    
    func tapWithSound(
        _ sound: SoundType = .buttonTap,
        volume: Float? = nil,
        action: @escaping () -> Void = {}
    ) -> some View {
        self
            .soundEffect(sound, trigger: .tap, volume: volume)
            .onTapGesture(perform: action)
    }
    
    func hoverSound(_ sound: SoundType = .buttonHover, volume: Float? = nil) -> some View {
        soundEffect(sound, trigger: .hover, volume: volume)
    }
    
    func appearSound(_ sound: SoundType, volume: Float? = nil) -> some View {
        soundEffect(sound, trigger: .appear, volume: volume)
    }
}