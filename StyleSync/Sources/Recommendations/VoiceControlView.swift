import SwiftUI
import Speech
import AVFoundation

struct VoiceControlView: View {
    @StateObject private var voiceController = VoiceController()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingPermissionAlert = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerSection
                    mainContentArea
                    controlsSection
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            voiceController.checkPermissions()
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") { showingSettings = true }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Please enable microphone access in Settings to use voice control features.")
        }
        .sheet(isPresented: $showingSettings) {
            VoiceSettingsView()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.9),
                Color.purple.opacity(0.3),
                Color.blue.opacity(0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .backdrop(BlurView(style: .systemThinMaterial))
                    )
            }
            .tapWithHaptic(.light)

            Spacer()

            VStack(spacing: 4) {
                Text("Voice Control")
                    .typography(.title3, theme: .modern)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(voiceController.status.description)
                    .typography(.caption1, theme: .minimal)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .backdrop(BlurView(style: .systemThinMaterial))
                    )
            }
            .tapWithHaptic(.light)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var mainContentArea: some View {
        VStack(spacing: 32) {
            visualFeedbackSection
            suggestedCommandsSection
            conversationHistorySection
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }

    private var visualFeedbackSection: some View {
        VStack(spacing: 24) {
            // Voice visualization
            VoiceVisualizerView(
                isListening: voiceController.isListening,
                audioLevel: voiceController.audioLevel,
                isProcessing: voiceController.isProcessing
            )

            // Current speech text
            if !voiceController.currentSpeechText.isEmpty {
                Text(voiceController.currentSpeechText)
                    .typography(.title3, theme: .modern)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: voiceController.currentSpeechText)
            }

            // AI Response
            if !voiceController.lastResponse.isEmpty {
                ResponseBubble(text: voiceController.lastResponse)
            }
        }
    }

    private var suggestedCommandsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try saying:")
                .typography(.body1, theme: .modern)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(voiceController.suggestedCommands, id: \.self) { command in
                    CommandSuggestionCard(command: command) {
                        voiceController.processCommand(command)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var conversationHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !voiceController.conversationHistory.isEmpty {
                Text("Recent Conversation")
                    .typography(.body1, theme: .modern)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(voiceController.conversationHistory.suffix(5), id: \.id) { interaction in
                            ConversationBubble(interaction: interaction)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(.horizontal, 20)
    }

    private var controlsSection: some View {
        HStack(spacing: 24) {
            // Listen button
            Button(action: { voiceController.toggleListening() }) {
                ZStack {
                    Circle()
                        .fill(voiceController.isListening ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(color: voiceController.isListening ? .red : .blue, radius: 20, x: 0, y: 0)
                        .scaleEffect(voiceController.isListening ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voiceController.isListening)

                    Image(systemName: voiceController.isListening ? "mic.fill" : "mic")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .tapWithHaptic(.heavy)
            .disabled(!voiceController.hasPermission)

            VStack(spacing: 12) {
                // Speak response button
                Button(action: { voiceController.speakLastResponse() }) {
                    Image(systemName: voiceController.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.3")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.green)
                                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .tapWithHaptic(.medium)
                .disabled(voiceController.lastResponse.isEmpty)

                // Clear conversation
                Button(action: { voiceController.clearConversation() }) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.6))
                        )
                }
                .tapWithHaptic(.light)
                .disabled(voiceController.conversationHistory.isEmpty)
            }
        }
        .padding(.bottom, 34)
    }
}

struct VoiceVisualizerView: View {
    let isListening: Bool
    let audioLevel: CGFloat
    let isProcessing: Bool

    @State private var animationTimer: Timer?
    @State private var wavePhases: [Double] = Array(repeating: 0, count: 5)

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 200, height: 200)

            // Sound waves
            if isListening {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(
                            width: CGFloat(80 + index * 20) + audioLevel * 40,
                            height: CGFloat(80 + index * 20) + audioLevel * 40
                        )
                        .opacity(0.8 - Double(index) * 0.15)
                        .scaleEffect(1.0 + sin(wavePhases[index]) * 0.1)
                }
            }

            // Processing indicator
            if isProcessing {
                ProcessingIndicator()
            } else {
                // Microphone icon
                Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isListening ? .blue : .gray)
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            startWaveAnimation()
        }
        .onDisappear {
            stopWaveAnimation()
        }
    }

    private func startWaveAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                for i in 0..<wavePhases.count {
                    wavePhases[i] += Double.pi / 10 + Double(i) * Double.pi / 20
                }
            }
        }
    }

    private func stopWaveAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct ProcessingIndicator: View {
    @State private var rotationAngle = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotationAngle))
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

struct ResponseBubble: View {
    let text: String
    @State private var isVisible = false

    var body: some View {
        Text(text)
            .typography(.body1, theme: .modern)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isVisible = true
                }
            }
    }
}

struct CommandSuggestionCard: View {
    let command: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(command)
                .typography(.caption1, theme: .minimal)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .tapWithHaptic(.light)
    }
}

struct ConversationBubble: View {
    let interaction: VoiceInteraction

    var body: some View {
        HStack {
            if interaction.isUserSpeech {
                Spacer()
                userBubble
            } else {
                aiBubble
                Spacer()
            }
        }
    }

    private var userBubble: some View {
        Text(interaction.text)
            .typography(.body2, theme: .minimal)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.6))
            )
    }

    private var aiBubble: some View {
        Text(interaction.text)
            .typography(.body2, theme: .minimal)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.4))
            )
    }
}

struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = VoiceSettings.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Voice Recognition") {
                    Toggle("Continuous Listening", isOn: $settings.continuousListening)

                    HStack {
                        Text("Recognition Language")
                        Spacer()
                        Picker("Language", selection: $settings.recognitionLanguage) {
                            ForEach(VoiceSettings.supportedLanguages, id: \.code) { language in
                                Text(language.name).tag(language.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Picker("Sensitivity", selection: $settings.sensitivity) {
                            Text("Low").tag(VoiceSettings.Sensitivity.low)
                            Text("Medium").tag(VoiceSettings.Sensitivity.medium)
                            Text("High").tag(VoiceSettings.Sensitivity.high)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }

                Section("Voice Response") {
                    Toggle("Speak Responses", isOn: $settings.speakResponses)

                    if settings.speakResponses {
                        HStack {
                            Text("Voice")
                            Spacer()
                            Picker("Voice", selection: $settings.selectedVoice) {
                                ForEach(settings.availableVoices, id: \.identifier) { voice in
                                    Text(voice.name).tag(voice.identifier)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack {
                            Text("Speech Rate")
                            Spacer()
                            Slider(value: $settings.speechRate, in: 0.3...0.7)
                                .frame(width: 120)
                        }
                    }
                }

                Section("Commands") {
                    Toggle("Custom Wake Word", isOn: $settings.customWakeWord)

                    if settings.customWakeWord {
                        TextField("Wake Word", text: $settings.wakeWord)
                    }

                    NavigationLink("Manage Custom Commands") {
                        CustomCommandsView()
                    }
                }

                Section("Privacy") {
                    Toggle("Store Voice Data", isOn: $settings.storeVoiceData)

                    Toggle("Improve Recognition", isOn: $settings.improveRecognition)

                    Button("Clear Voice History") {
                        settings.clearVoiceHistory()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct CustomCommandsView: View {
    @StateObject private var commandManager = CustomCommandManager.shared
    @State private var showingAddCommand = false

    var body: some View {
        List {
            ForEach(commandManager.customCommands) { command in
                CustomCommandRow(command: command) {
                    commandManager.deleteCommand(command)
                }
            }
            .onDelete(perform: commandManager.deleteCommands)
        }
        .navigationTitle("Custom Commands")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showingAddCommand = true
                }
            }
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCustomCommandView()
        }
    }
}

struct CustomCommandRow: View {
    let command: CustomVoiceCommand
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command.phrase)
                .typography(.body1, theme: .modern)
                .fontWeight(.medium)

            Text(command.action.description)
                .typography(.caption1, theme: .minimal)
                .foregroundColor(.secondary)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct AddCustomCommandView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commandManager = CustomCommandManager.shared
    @State private var phrase = ""
    @State private var selectedAction = VoiceAction.showRecommendations
    @State private var parameters = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Command Phrase") {
                    TextField("e.g., 'Show me summer dresses'", text: $phrase)
                }

                Section("Action") {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(VoiceAction.allCases, id: \.self) { action in
                            Text(action.description).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if selectedAction.requiresParameters {
                    Section("Parameters") {
                        TextField("Additional parameters", text: $parameters)
                    }
                }
            }
            .navigationTitle("Add Command")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCommand()
                        dismiss()
                    }
                    .disabled(phrase.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveCommand() {
        let command = CustomVoiceCommand(
            id: UUID(),
            phrase: phrase,
            action: selectedAction,
            parameters: parameters.isEmpty ? nil : parameters,
            isEnabled: true,
            createdAt: Date()
        )

        commandManager.addCommand(command)
    }
}

#Preview {
    VoiceControlView()
        .environmentObject(ThemeManager())
}