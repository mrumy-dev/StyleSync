import SwiftUI

struct ChatView: View {
    @StateObject private var chatManager = ChatManager()
    @StateObject private var voiceRecorder = VoiceRecorderManager()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var hapticManager: HapticFeedbackManager
    @EnvironmentObject private var soundManager: SoundDesignManager
    
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingColorPicker = false
    @State private var showingSketchPad = false
    @State private var isRecordingVoice = false
    @State private var showingPersonaSelector = false
    @State private var scrollProxy: ScrollViewReader?
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Chat Header
                chatHeader
                
                // Messages List
                messagesView
                
                // Typing Indicator
                if chatManager.isAITyping {
                    typingIndicator
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
                
                // Input Area
                inputArea
            }
        }
        .navigationBarHidden(true)
        .background(
            GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                .opacity(0.3)
        )
        .onAppear {
            chatManager.startSession()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                chatManager.sendImageMessage(image: image)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                chatManager.sendImageMessage(image: image, isOutfit: true)
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView { color in
                chatManager.sendColorMessage(color: color)
            }
        }
        .sheet(isPresented: $showingSketchPad) {
            SketchPadView { sketch in
                chatManager.sendSketchMessage(sketch: sketch)
            }
        }
        .sheet(isPresented: $showingPersonaSelector) {
            PersonaSelectorView(selectedPersona: $chatManager.currentSession.settings.currentPersona)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                keyboardHeight = keyboardFrame.cgRectValue.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
    
    // MARK: - Chat Header
    private var chatHeader: some View {
        HStack(spacing: 16) {
            // AI Avatar
            Button(action: { showingPersonaSelector = true }) {
                Image(systemName: chatManager.currentSession.settings.currentPersona.avatar)
                    .font(.title2)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(themeManager.currentTheme.colors.accent, lineWidth: 2)
                    )
            }
            .tapWithHaptic(.light)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chatManager.currentSession.settings.currentPersona.name)
                    .typography(.body1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(chatManager.isAITyping ? "typing..." : "Online")
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { /* Video call */ }) {
                    Image(systemName: "video")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .tapWithHaptic(.light)
                
                Menu {
                    Button("Search Messages", action: { /* Search */ })
                    Button("Export Chat", action: { chatManager.exportChat() })
                    Button("Clear Chat", action: { chatManager.clearChat() })
                    Button("Settings", action: { /* Settings */ })
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .tapWithHaptic(.light)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            themeManager.currentTheme.colors.surface
                .opacity(0.95)
                .glassmorphism(intensity: .medium)
        )
    }
    
    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.currentSession.messages) { message in
                        MessageBubbleView(
                            message: message,
                            onReaction: { emoji in
                                chatManager.addReaction(to: message.id, emoji: emoji)
                            },
                            onReply: { messageId in
                                chatManager.startReply(to: messageId)
                            }
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: message.sender.isAI ? .leading : .trailing)
                                .combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: chatManager.currentSession.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastMessage = chatManager.currentSession.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: chatManager.currentSession.settings.currentPersona.avatar)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.colors.accent)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                )
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(themeManager.currentTheme.colors.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(chatManager.typingAnimationScale[index])
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: chatManager.typingAnimationScale[index]
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeManager.currentTheme.colors.surface)
                    .glassmorphism(intensity: .light)
            )
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Reply Preview
            if let replyingTo = chatManager.replyingTo {
                replyPreview(message: replyingTo)
            }
            
            // Quick Suggestions
            if !chatManager.quickSuggestions.isEmpty {
                quickSuggestionsRow
            }
            
            // Main Input
            HStack(spacing: 12) {
                // Attachment Button
                Menu {
                    Button("Photo Library", action: { showingImagePicker = true })
                    Button("Camera", action: { showingCamera = true })
                    Button("Color Picker", action: { showingColorPicker = true })
                    Button("Sketch", action: { showingSketchPad = true })
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .tapWithHaptic(.light)
                
                // Text Input
                HStack(spacing: 8) {
                    TextField("Message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .onChange(of: messageText) { newValue in
                            chatManager.updateTypingStatus(!newValue.isEmpty)
                        }
                    
                    if !messageText.isEmpty {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.colors.accent)
                        }
                        .tapWithHaptic(.medium)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(themeManager.currentTheme.colors.surface)
                        .glassmorphism(intensity: .light)
                )
                
                // Voice Recording Button
                if messageText.isEmpty {
                    Button(action: toggleVoiceRecording) {
                        Image(systemName: isRecordingVoice ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            .foregroundColor(isRecordingVoice ? .red : themeManager.currentTheme.colors.accent)
                            .scaleEffect(isRecordingVoice ? 1.2 : 1.0)
                    }
                    .tapWithHaptic(.medium)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecordingVoice)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, max(16, keyboardHeight > 0 ? 8 : 34)) // Account for safe area
            .background(
                themeManager.currentTheme.colors.surface
                    .opacity(0.95)
                    .glassmorphism(intensity: .medium)
            )
        }
    }
    
    // MARK: - Reply Preview
    private func replyPreview(message: ChatMessage) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(themeManager.currentTheme.colors.accent)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.sender.displayName)")
                    .typography(.caption1, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                
                Text(message.content.displayText)
                    .typography(.caption2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: { chatManager.cancelReply() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
            .tapWithHaptic(.light)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            themeManager.currentTheme.colors.accent.opacity(0.1)
        )
    }
    
    // MARK: - Quick Suggestions
    private var quickSuggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chatManager.quickSuggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        messageText = suggestion
                        sendMessage()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(themeManager.currentTheme.colors.accent, lineWidth: 1)
                            )
                    )
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .typography(.caption1, theme: .modern)
                    .tapWithHaptic(.light)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = ChatMessage(
            content: .text(messageText),
            sender: .user,
            replyTo: chatManager.replyingTo?.id
        )
        
        chatManager.sendMessage(message)
        messageText = ""
        
        // Trigger haptic and sound feedback
        hapticManager.playHaptic(.light)
        soundManager.playSound(.messageSent)
        
        // Auto-scroll to new message
        withAnimation(.easeOut(duration: 0.3)) {
            scrollProxy?.scrollTo(message.id, anchor: .bottom)
        }
    }
    
    private func toggleVoiceRecording() {
        if isRecordingVoice {
            voiceRecorder.stopRecording { result in
                switch result {
                case .success(let voiceMessage):
                    chatManager.sendVoiceMessage(voiceMessage)
                case .failure(let error):
                    print("Voice recording failed: \(error)")
                }
                isRecordingVoice = false
            }
        } else {
            voiceRecorder.startRecording()
            isRecordingVoice = true
            hapticManager.playHaptic(.medium)
        }
    }
}