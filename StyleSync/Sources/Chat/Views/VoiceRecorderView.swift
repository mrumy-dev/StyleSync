import SwiftUI
import AVFoundation
import Speech

class VoiceRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var waveform: [Float] = []
    @Published var transcriptionText = ""
    @Published var isTranscribing = false
    
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
        setupAudioSession()
        requestPermissions()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func requestPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Audio recording permission denied")
            }
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("Speech recognition authorized")
            default:
                print("Speech recognition not authorized")
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() {
        guard !isRecording else { return }
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("voice_message.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                isRecording = true
                recordingStartTime = Date()
                startTimers()
                
                // Start real-time transcription if available
                startLiveTranscription()
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording(completion: @escaping (Result<VoiceMessage, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(VoiceRecordingError.notRecording))
            return
        }
        
        isRecording = false
        stopTimers()
        stopLiveTranscription()
        
        audioRecorder?.stop()
        
        guard let audioRecorder = audioRecorder,
              let startTime = recordingStartTime else {
            completion(.failure(VoiceRecordingError.recordingFailed))
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let audioURL = audioRecorder.url
        
        // Generate final waveform
        generateWaveform(from: audioURL) { [weak self] waveformData in
            guard let self = self else { return }
            
            let voiceMessage = VoiceMessage(
                audioURL: audioURL,
                duration: duration,
                waveform: waveformData,
                transcription: self.transcriptionText.isEmpty ? nil : self.transcriptionText,
                isTranscribing: false
            )
            
            completion(.success(voiceMessage))
        }
    }
    
    // MARK: - Live Transcription
    private func startLiveTranscription() {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcriptionText = result.bestTranscription.formattedString
                    self.isTranscribing = !result.isFinal
                }
            }
            
            if error != nil {
                self.stopLiveTranscription()
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func stopLiveTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    // MARK: - Audio Level Monitoring
    private func startTimers() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                if let startTime = self.recordingStartTime {
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateAudioLevel()
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        let normalizedLevel = max(0, (level + 60) / 60) // Normalize to 0-1 range
        
        DispatchQueue.main.async {
            self.recordingLevel = normalizedLevel
            
            // Update waveform data
            self.waveform.append(normalizedLevel)
            if self.waveform.count > 100 {
                self.waveform.removeFirst()
            }
        }
    }
    
    // MARK: - Waveform Generation
    private func generateWaveform(from url: URL, completion: @escaping ([Float]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let frameCount = UInt32(audioFile.length)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    completion([])
                    return
                }
                
                try audioFile.read(into: buffer)
                
                let channelData = buffer.floatChannelData?[0]
                let frameLength = Int(buffer.frameLength)
                
                var waveformData: [Float] = []
                let samplesPerPoint = max(1, frameLength / 100) // Generate 100 points
                
                for i in stride(from: 0, to: frameLength, by: samplesPerPoint) {
                    var sum: Float = 0
                    let endIndex = min(i + samplesPerPoint, frameLength)
                    
                    for j in i..<endIndex {
                        sum += abs(channelData?[j] ?? 0)
                    }
                    
                    let average = sum / Float(endIndex - i)
                    waveformData.append(average)
                }
                
                DispatchQueue.main.async {
                    completion(waveformData)
                }
            } catch {
                print("Failed to generate waveform: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

// MARK: - AVAudioRecorderDelegate
extension VoiceRecorderManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Audio recording finished unsuccessfully")
        }
    }
}

// MARK: - Voice Recording View
struct VoiceRecorderView: View {
    @StateObject private var recorder = VoiceRecorderManager()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    @State private var isPressed = false
    
    let onRecordingComplete: (VoiceMessage) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button("Cancel") {
                    if recorder.isRecording {
                        recorder.stopRecording { _ in }
                    }
                    onCancel()
                }
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                
                Spacer()
                
                Text("Voice Message")
                    .typography(.heading4, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                Spacer()
                
                if recorder.isRecording {
                    Button("Stop") {
                        recorder.stopRecording { result in
                            switch result {
                            case .success(let voiceMessage):
                                onRecordingComplete(voiceMessage)
                            case .failure(let error):
                                print("Recording failed: \(error)")
                            }
                        }
                    }
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Waveform Visualization
            waveformView
            
            // Recording Info
            VStack(spacing: 8) {
                Text(formatDuration(recorder.recordingDuration))
                    .typography(.heading2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .monospacedDigit()
                
                if recorder.isTranscribing {
                    Text("Transcribing...")
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                } else if !recorder.transcriptionText.isEmpty {
                    ScrollView {
                        Text(recorder.transcriptionText)
                            .typography(.body1, theme: .modern)
                            .foregroundColor(themeManager.currentTheme.colors.primary)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(themeManager.currentTheme.colors.surface.opacity(0.5))
                            )
                    }
                    .frame(maxHeight: 120)
                }
            }
            
            Spacer()
            
            // Record Button
            recordButton
                .scaleEffect(isPressed ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .padding()
        .background(
            GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                .opacity(0.3)
        )
        .onAppear {
            hapticManager.playHaptic(.light)
        }
    }
    
    // MARK: - Waveform View
    private var waveformView: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<recorder.waveform.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent,
                                themeManager.currentTheme.colors.accent.opacity(0.6)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(4, CGFloat(recorder.waveform[index] * 80)))
                    .animation(.easeOut(duration: 0.1), value: recorder.waveform[index])
            }
            
            // Placeholder bars if no data
            if recorder.waveform.isEmpty {
                ForEach(0..<50, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.2))
                        .frame(width: 3, height: 4)
                }
            }
        }
        .frame(height: 80)
    }
    
    // MARK: - Record Button
    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        recorder.isRecording ? Color.red : themeManager.currentTheme.colors.accent,
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)
                
                // Inner circle
                Circle()
                    .fill(recorder.isRecording ? Color.red : themeManager.currentTheme.colors.accent)
                    .frame(width: recorder.isRecording ? 50 : 80, height: recorder.isRecording ? 50 : 80)
                    .overlay(
                        Group {
                            if recorder.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                    )
                
                // Pulse animation when recording
                if recorder.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(1.2)
                        .opacity(0.6)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: recorder.isRecording)
                }
            }
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: 50
        ) {
            // Long press completed
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = pressing
            }
            
            if pressing && !recorder.isRecording {
                hapticManager.playHaptic(.medium)
            }
        }
    }
    
    // MARK: - Actions
    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording { result in
                switch result {
                case .success(let voiceMessage):
                    onRecordingComplete(voiceMessage)
                case .failure(let error):
                    print("Recording failed: \(error)")
                }
            }
        } else {
            recorder.startRecording()
            hapticManager.playHaptic(.medium)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Error Types
enum VoiceRecordingError: Error {
    case notRecording
    case recordingFailed
    case permissionDenied
    case audioSessionFailed
}