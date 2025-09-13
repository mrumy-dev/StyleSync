import SwiftUI

// MARK: - Direct Messages Main View
struct DirectMessagesView: View {
    @StateObject private var messagesManager = DirectMessagesManager.shared
    @Environment(\.theme) private var theme
    @State private var showingNewMessage = false
    @State private var searchText = ""

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return messagesManager.conversations
        } else {
            return messagesManager.conversations.filter { conversation in
                // Would filter by participant names or last message content
                true
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // Conversations List
                if filteredConversations.isEmpty {
                    EmptyMessagesView()
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { conversation in
                                NavigationLink(destination: ChatView(conversation: conversation)) {
                                    ConversationRowView(conversation: conversation)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Divider()
                                    .padding(.leading, 68)
                            }
                        }
                    }
                }
            }
            .background(
                GradientMeshBackground(colors: theme.gradients.mesh)
                    .ignoresSafeArea()
            )
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(theme.colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingNewMessage) {
                NewMessageView()
            }
            .onAppear {
                messagesManager.loadConversations()
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.colors.onSurfaceVariant)

            TextField("Search messages", text: $text)
                .typography(.body2, theme: .system)
                .foregroundColor(theme.colors.onSurface)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.colors.surfaceVariant)
        )
    }
}

// MARK: - Conversation Row View
struct ConversationRowView: View {
    let conversation: Conversation
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture / Group Avatar
            ConversationAvatarView(conversation: conversation)

            VStack(alignment: .leading, spacing: 4) {
                // Name and Time
                HStack {
                    Text(conversationTitle)
                        .typography(.body1, theme: .modern)
                        .foregroundColor(theme.colors.onSurface)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTimestamp(conversation.lastActivity))
                        .typography(.caption1, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }

                // Last Message Preview
                HStack {
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessagePreview(lastMessage))
                            .typography(.body2, theme: .system)
                            .foregroundColor(
                                hasUnreadMessages ? theme.colors.onSurface : theme.colors.onSurfaceVariant
                            )
                            .fontWeight(hasUnreadMessages ? .medium : .regular)
                            .lineLimit(2)
                    } else {
                        Text("No messages yet")
                            .typography(.body2, theme: .system)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                            .italic()
                    }

                    Spacer()

                    // Unread indicator
                    if hasUnreadMessages {
                        Circle()
                            .fill(theme.colors.primary)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(hasUnreadMessages ? theme.colors.primary.opacity(0.05) : Color.clear)
    }

    private var conversationTitle: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            // Would get participant name from user ID
            return "Stylist Name"
        }
    }

    private var hasUnreadMessages: Bool {
        // Would check if there are unread messages
        return Bool.random()
    }

    private func lastMessagePreview(_ message: DirectMessage) -> String {
        switch message.content {
        case .text(let text):
            return text
        case .voice:
            return "🎤 Voice message"
        case .image:
            return "📷 Photo"
        case .outfit:
            return "👗 Outfit"
        case .sketch:
            return "✏️ Sketch"
        case .color:
            return "🎨 Color"
        default:
            return "Message"
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Conversation Avatar View
struct ConversationAvatarView: View {
    let conversation: Conversation
    @Environment(\.theme) private var theme

    var body: some View {
        if conversation.isGroupChat {
            // Group avatar
            ZStack {
                Circle()
                    .fill(theme.colors.surfaceVariant)
                    .frame(width: 48, height: 48)

                if let groupImageData = conversation.groupImageData,
                   let uiImage = UIImage(data: groupImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.2.circle.fill")
                        .font(.title)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }
        } else {
            // Individual avatar
            Circle()
                .fill(theme.colors.surfaceVariant)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                )
        }
    }
}

// MARK: - Chat View
struct ChatView: View {
    let conversation: Conversation
    @StateObject private var messagesManager = DirectMessagesManager.shared
    @StateObject private var interactionManager = InteractionManager.shared
    @Environment(\.theme) private var theme
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingVoiceRecorder = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messagesManager.currentMessages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: isFromCurrentUser(message)
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    messagesManager.loadMessages(for: conversation.id)
                    scrollToBottom(proxy)
                }
                .onChange(of: messagesManager.currentMessages.count) { _ in
                    scrollToBottom(proxy)
                }
            }

            Divider()

            // Message Input
            MessageInputView(
                messageText: $messageText,
                isMessageFieldFocused: $isMessageFieldFocused,
                onSendText: sendTextMessage,
                onSendImage: { showingImagePicker = true },
                onSendVoice: { showingVoiceRecorder = true }
            )
            .padding(.bottom, keyboardHeight)
        }
        .background(
            GradientMeshBackground(colors: theme.gradients.mesh)
                .ignoresSafeArea()
        )
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Show conversation details
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.colors.onSurface)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView { image in
                sendImageMessage(image)
            }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView { voiceMessage in
                sendVoiceMessage(voiceMessage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = getKeyboardHeight(notification)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }

    private var conversationTitle: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            return "Chat" // Would get participant name
        }
    }

    private func isFromCurrentUser(_ message: DirectMessage) -> Bool {
        // Would check against current user ID
        return Bool.random()
    }

    private func sendTextMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = DirectMessage(
            conversationID: conversation.id,
            senderID: "current_user", // Would use actual user ID
            content: .text(messageText)
        )

        messagesManager.sendMessage(message)
        messageText = ""
        isMessageFieldFocused = false
    }

    private func sendImageMessage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let imageMessage = ImageMessage(
            imageData: imageData,
            caption: nil,
            isOutfit: false,
            analysisResults: nil
        )

        let message = DirectMessage(
            conversationID: conversation.id,
            senderID: "current_user",
            content: .image(imageMessage)
        )

        messagesManager.sendMessage(message)
    }

    private func sendVoiceMessage(_ voiceMessage: VoiceMessage) {
        let message = DirectMessage(
            conversationID: conversation.id,
            senderID: "current_user",
            content: .voice(voiceMessage)
        )

        messagesManager.sendMessage(message)
    }

    private func scrollToBottom(_ proxy: ScrollViewReader) {
        if let lastMessage = messagesManager.currentMessages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func getKeyboardHeight(_ notification: Notification) -> CGFloat {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        return keyboardFrame.height
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: DirectMessage
    let isFromCurrentUser: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message Content
                MessageContentBubble(
                    content: message.content,
                    isFromCurrentUser: isFromCurrentUser
                )

                // Message Status and Time
                HStack(spacing: 4) {
                    Text(formatTimestamp(message.timestamp))
                        .typography(.caption2, theme: .system)
                        .foregroundColor(theme.colors.onSurfaceVariant)

                    if isFromCurrentUser {
                        MessageStatusIcon(status: message.status)
                    }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 4)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Message Content Bubble
struct MessageContentBubble: View {
    let content: MessageContent
    let isFromCurrentUser: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch content {
            case .text(let text):
                TextMessageBubble(text: text, isFromCurrentUser: isFromCurrentUser)

            case .image(let imageMessage):
                ImageMessageBubble(imageMessage: imageMessage, isFromCurrentUser: isFromCurrentUser)

            case .voice(let voiceMessage):
                VoiceMessageBubble(voiceMessage: voiceMessage, isFromCurrentUser: isFromCurrentUser)

            case .outfit(let outfitMessage):
                OutfitMessageBubble(outfitMessage: outfitMessage, isFromCurrentUser: isFromCurrentUser)

            case .sketch(let sketchMessage):
                SketchMessageBubble(sketchMessage: sketchMessage, isFromCurrentUser: isFromCurrentUser)

            case .color(let colorMessage):
                ColorMessageBubble(colorMessage: colorMessage, isFromCurrentUser: isFromCurrentUser)

            default:
                DefaultMessageBubble(isFromCurrentUser: isFromCurrentUser)
            }
        }
    }
}

// MARK: - Text Message Bubble
struct TextMessageBubble: View {
    let text: String
    let isFromCurrentUser: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .typography(.body2, theme: .system)
            .foregroundColor(isFromCurrentUser ? .white : theme.colors.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isFromCurrentUser ? theme.colors.primary : theme.colors.surface)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
    }
}

// MARK: - Image Message Bubble
struct ImageMessageBubble: View {
    let imageMessage: ImageMessage
    let isFromCurrentUser: Bool
    @State private var showingFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = UIImage(data: imageMessage.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        showingFullScreen = true
                    }
            }

            if let caption = imageMessage.caption, !caption.isEmpty {
                Text(caption)
                    .typography(.body2, theme: .system)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let uiImage = UIImage(data: imageMessage.imageData) {
                FullScreenImageView(imageData: imageMessage.imageData)
            }
        }
    }
}

// MARK: - Voice Message Bubble
struct VoiceMessageBubble: View {
    let voiceMessage: VoiceMessage
    let isFromCurrentUser: Bool
    @Environment(\.theme) private var theme
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isPlaying.toggle()
                // Play/pause voice message
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isFromCurrentUser ? .white : theme.colors.primary)
            }

            // Waveform visualization
            WaveformView(waveform: voiceMessage.waveform, isFromCurrentUser: isFromCurrentUser)

            Text(formatDuration(voiceMessage.duration))
                .typography(.caption1, theme: .system)
                .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : theme.colors.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isFromCurrentUser ? theme.colors.primary : theme.colors.surface)
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    let waveform: [Float]
    let isFromCurrentUser: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(waveform.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isFromCurrentUser ? .white.opacity(0.8) : theme.colors.primary.opacity(0.8))
                    .frame(width: 3, height: CGFloat(waveform[index]) * 20 + 4)
            }
        }
        .frame(width: 100, height: 24)
    }
}

// MARK: - Message Status Icon
struct MessageStatusIcon: View {
    let status: MessageStatus
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: status.icon)
            .font(.caption2)
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .sending: return theme.colors.onSurfaceVariant
        case .sent: return theme.colors.onSurfaceVariant
        case .delivered: return theme.colors.primary
        case .read: return theme.colors.primary
        case .failed: return .red
        }
    }
}

// MARK: - Message Input View
struct MessageInputView: View {
    @Binding var messageText: String
    var isMessageFieldFocused: FocusState<Bool>.Binding
    let onSendText: () -> Void
    let onSendImage: () -> Void
    let onSendVoice: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            // Additional options button
            Button(action: onSendImage) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }

            // Text input
            HStack {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .focused(isMessageFieldFocused)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurface)
                    .lineLimit(1...4)

                if messageText.isEmpty {
                    Button(action: onSendVoice) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.colors.surfaceVariant)
            )

            // Send button
            Button(action: onSendText) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? theme.colors.onSurfaceVariant
                        : theme.colors.primary
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(theme.colors.surface)
    }
}

// MARK: - Empty Messages View
struct EmptyMessagesView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(theme.colors.onSurfaceVariant)

            VStack(spacing: 8) {
                Text("No messages yet")
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Text("Start a conversation with other stylists!")
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Placeholder Views
struct NewMessageView: View {
    var body: some View {
        Text("New Message")
            .navigationTitle("New Message")
    }
}

struct ImagePickerView: View {
    let onImageSelected: (UIImage) -> Void

    var body: some View {
        Text("Image Picker")
    }
}

struct VoiceRecorderView: View {
    let onVoiceRecorded: (VoiceMessage) -> Void

    var body: some View {
        Text("Voice Recorder")
    }
}

// Additional message bubble types would be implemented similarly
struct OutfitMessageBubble: View {
    let outfitMessage: OutfitMessage
    let isFromCurrentUser: Bool

    var body: some View {
        Text("Outfit Message")
    }
}

struct SketchMessageBubble: View {
    let sketchMessage: SketchMessage
    let isFromCurrentUser: Bool

    var body: some View {
        Text("Sketch Message")
    }
}

struct ColorMessageBubble: View {
    let colorMessage: ColorMessage
    let isFromCurrentUser: Bool

    var body: some View {
        Text("Color Message")
    }
}

struct DefaultMessageBubble: View {
    let isFromCurrentUser: Bool

    var body: some View {
        Text("Unsupported message type")
            .foregroundColor(.gray)
    }
}