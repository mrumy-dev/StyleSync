import SwiftUI
import SwiftData
import Speech
import AVFoundation
import Combine
import PhotosUI

struct AIStylistView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatManager = AIStylistChatManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var imageAnalyzer = ChatImageAnalyzer()
    @State private var messageText = ""
    @State private var selectedPersona: StylistPersona = .classic
    @State private var showingPersonaSelection = false
    @State private var showingImagePicker = false
    @State private var isListening = false
    @State private var showingEducationMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Chat Background
                ChatBackgroundView(persona: selectedPersona)

                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Welcome Message
                                if chatManager.messages.isEmpty {
                                    WelcomeMessageView(persona: selectedPersona)
                                        .id("welcome")
                                }

                                // Chat Messages
                                ForEach(chatManager.messages) { message in
                                    ChatMessageView(
                                        message: message,
                                        persona: selectedPersona,
                                        onImageAnalysis: { image in
                                            analyzeImageInChat(image)
                                        },
                                        onShoppingTap: { items in
                                            showShoppingRecommendations(items)
                                        },
                                        onOutfitMockup: { outfit in
                                            showOutfitMockup(outfit)
                                        }
                                    )
                                    .id(message.id)
                                }

                                // Typing Indicator
                                if chatManager.isTyping {
                                    TypingIndicatorView(persona: selectedPersona)
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: chatManager.messages.count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                if let lastMessage = chatManager.messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: chatManager.isTyping) { isTyping in
                            if isTyping {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Input Bar
                    ChatInputBarView(
                        messageText: $messageText,
                        selectedPersona: selectedPersona,
                        isListening: $isListening,
                        onSendMessage: sendMessage,
                        onVoiceInput: startVoiceInput,
                        onImagePicker: { showingImagePicker = true },
                        onMoodBoard: generateMoodBoard,
                        onColorPalette: generateColorPalette
                    )
                }
            }
            .navigationTitle(selectedPersona.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingPersonaSelection = true
                        HapticManager.HapticType.selection.trigger()
                    }) {
                        StylistAvatarView(persona: selectedPersona, size: 32)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        StylistMenuView(
                            onEducationMode: { showingEducationMode = true },
                            onClearChat: clearChat,
                            onExportChat: exportChat,
                            onVoiceSettings: showVoiceSettings
                        )
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
        }
        .onAppear {
            setupStylistChat()
        }
        .sheet(isPresented: $showingPersonaSelection) {
            PersonaSelectionView(selectedPersona: $selectedPersona)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView { image in
                analyzeImageInChat(image)
            }
        }
        .sheet(isPresented: $showingEducationMode) {
            FashionEducationView()
                .presentationDetents([.large])
        }
        .environment(chatManager)
    }

    private func setupStylistChat() {
        chatManager.setupPersona(selectedPersona)
        voiceManager.setupVoice(for: selectedPersona)

        // Load conversation history
        Task {
            await chatManager.loadConversationHistory()
        }

        // Check for proactive suggestions
        Task {
            await chatManager.checkProactiveSuggestions()
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = ChatMessage(
            id: UUID(),
            content: messageText,
            isFromUser: true,
            timestamp: Date(),
            messageType: .text
        )

        chatManager.addMessage(userMessage)
        messageText = ""

        Task {
            await chatManager.generateResponse(to: userMessage, persona: selectedPersona)
        }

        HapticManager.HapticType.lightImpact.trigger()
    }

    private func startVoiceInput() {
        isListening = true
        Task {
            let transcript = await voiceManager.startListening()
            await MainActor.run {
                messageText = transcript
                isListening = false
            }
        }
        HapticManager.HapticType.success.trigger()
    }

    private func analyzeImageInChat(_ image: UIImage) {
        let imageMessage = ChatMessage(
            id: UUID(),
            content: "Analyze this image",
            isFromUser: true,
            timestamp: Date(),
            messageType: .image(image)
        )

        chatManager.addMessage(imageMessage)

        Task {
            await imageAnalyzer.analyzeImage(image) { analysis in
                let responseMessage = ChatMessage(
                    id: UUID(),
                    content: analysis.description,
                    isFromUser: false,
                    timestamp: Date(),
                    messageType: .imageAnalysis(analysis)
                )
                chatManager.addMessage(responseMessage)
            }
        }
    }

    private func showShoppingRecommendations(_ items: [ShoppingItem]) {
        let shoppingMessage = ChatMessage(
            id: UUID(),
            content: "Here are my recommendations:",
            isFromUser: false,
            timestamp: Date(),
            messageType: .shoppingList(items)
        )
        chatManager.addMessage(shoppingMessage)
    }

    private func showOutfitMockup(_ outfit: OutfitMockup) {
        let mockupMessage = ChatMessage(
            id: UUID(),
            content: "Here's how this outfit would look:",
            isFromUser: false,
            timestamp: Date(),
            messageType: .outfitMockup(outfit)
        )
        chatManager.addMessage(mockupMessage)
    }

    private func generateMoodBoard() {
        Task {
            let moodBoard = await chatManager.generateMoodBoard(for: selectedPersona)
            let moodBoardMessage = ChatMessage(
                id: UUID(),
                content: "I've created a mood board based on your style:",
                isFromUser: false,
                timestamp: Date(),
                messageType: .moodBoard(moodBoard)
            )
            chatManager.addMessage(moodBoardMessage)
        }
        HapticManager.HapticType.success.trigger()
    }

    private func generateColorPalette() {
        Task {
            let palette = await chatManager.generateColorPalette(for: selectedPersona)
            let paletteMessage = ChatMessage(
                id: UUID(),
                content: "Here's a color palette perfect for you:",
                isFromUser: false,
                timestamp: Date(),
                messageType: .colorPalette(palette)
            )
            chatManager.addMessage(paletteMessage)
        }
        HapticManager.HapticType.success.trigger()
    }

    private func clearChat() {
        chatManager.clearMessages()
        HapticManager.HapticType.success.trigger()
    }

    private func exportChat() {
        Task {
            await chatManager.exportConversation()
        }
        HapticManager.HapticType.success.trigger()
    }

    private func showVoiceSettings() {
        HapticManager.HapticType.selection.trigger()
    }
}

// MARK: - Chat Background

struct ChatBackgroundView: View {
    let persona: StylistPersona

    var body: some View {
        LinearGradient(
            colors: [
                persona.primaryColor.opacity(0.1),
                persona.secondaryColor.opacity(0.05),
                DesignSystem.Colors.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            // Subtle pattern overlay
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(persona.primaryColor.opacity(0.02))
                    .frame(width: CGFloat.random(in: 100...200))
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: CGFloat.random(in: -400...400)
                    )
            }
        }
    }
}

// MARK: - Welcome Message

struct WelcomeMessageView: View {
    let persona: StylistPersona

    var body: some View {
        VStack(spacing: 20) {
            StylistAvatarView(persona: persona, size: 80)

            VStack(spacing: 12) {
                Text("Hi, I'm \(persona.name)!")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text(persona.welcomeMessage)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Quick Action Buttons
            VStack(spacing: 12) {
                Text("What would you like to do?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                FlowLayout(spacing: 8) {
                    ForEach(persona.quickActions, id: \.self) { action in
                        QuickActionButton(
                            title: action,
                            persona: persona
                        ) {
                            // Handle quick action
                        }
                    }
                }
            }
        }
        .padding(.vertical, 40)
    }
}

struct QuickActionButton: View {
    let title: String
    let persona: StylistPersona
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(persona.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(persona.primaryColor.opacity(0.1))
                        .stroke(persona.primaryColor.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    let message: ChatMessage
    let persona: StylistPersona
    let onImageAnalysis: (UIImage) -> Void
    let onShoppingTap: ([ShoppingItem]) -> Void
    let onOutfitMockup: (OutfitMockup) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isFromUser {
                Spacer()
            } else {
                StylistAvatarView(persona: persona, size: 32)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
                // Message Content
                switch message.messageType {
                case .text:
                    TextMessageBubble(
                        text: message.content,
                        isFromUser: message.isFromUser,
                        persona: persona
                    )

                case .image(let image):
                    ImageMessageBubble(
                        image: image,
                        text: message.content,
                        isFromUser: message.isFromUser,
                        persona: persona
                    )

                case .imageAnalysis(let analysis):
                    ImageAnalysisBubble(
                        analysis: analysis,
                        persona: persona
                    )

                case .shoppingList(let items):
                    ShoppingListBubble(
                        items: items,
                        persona: persona,
                        onItemTap: onShoppingTap
                    )

                case .outfitMockup(let mockup):
                    OutfitMockupBubble(
                        mockup: mockup,
                        persona: persona
                    )

                case .moodBoard(let board):
                    MoodBoardBubble(
                        moodBoard: board,
                        persona: persona
                    )

                case .colorPalette(let palette):
                    ColorPaletteBubble(
                        palette: palette,
                        persona: persona
                    )

                case .trendExplanation(let explanation):
                    TrendExplanationBubble(
                        explanation: explanation,
                        persona: persona
                    )

                case .educationContent(let content):
                    EducationContentBubble(
                        content: content,
                        persona: persona
                    )
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.secondary.opacity(0.7))
            }

            if !message.isFromUser {
                Spacer()
            }
        }
    }
}

// MARK: - Message Bubbles

struct TextMessageBubble: View {
    let text: String
    let isFromUser: Bool
    let persona: StylistPersona

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isFromUser ? .white : DesignSystem.Colors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isFromUser
                        ? persona.primaryColor
                        : DesignSystem.Colors.surface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isFromUser
                        ? Color.clear
                        : DesignSystem.Colors.accent.opacity(0.1),
                        lineWidth: 1
                    )
            )
    }
}

struct ImageMessageBubble: View {
    let image: UIImage
    let text: String
    let isFromUser: Bool
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 250, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(isFromUser ? .white : DesignSystem.Colors.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    isFromUser
                    ? persona.primaryColor
                    : DesignSystem.Colors.surface
                )
        )
    }
}

struct ImageAnalysisBubble: View {
    let analysis: ImageAnalysisResult
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Image Analysis")
                .font(.headline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(title: "Style", value: analysis.detectedStyle)
                AnalysisRow(title: "Colors", value: analysis.dominantColors.map(\.description).joined(separator: ", "))
                AnalysisRow(title: "Occasion", value: analysis.suggestedOccasion)
                AnalysisRow(title: "Quality", value: "\(Int(analysis.qualityScore * 100))%")
            }

            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations:")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    ForEach(analysis.recommendations, id: \.self) { rec in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(persona.primaryColor)
                                .font(.caption)

                            Text(rec)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

struct AnalysisRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text("\(title):")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)

            Spacer()
        }
    }
}

struct ShoppingListBubble: View {
    let items: [ShoppingItem]
    let persona: StylistPersona
    let onItemTap: ([ShoppingItem]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Shopping Recommendations")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Spacer()

                Button("View All") {
                    onItemTap(items)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(persona.primaryColor)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(items.prefix(4), id: \.id) { item in
                    ShoppingItemCard(item: item, persona: persona)
                }
            }

            if items.count > 4 {
                Text("+ \(items.count - 4) more items")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

struct ShoppingItemCard: View {
    let item: ShoppingItem
    let persona: StylistPersona

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: item.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    )
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 4) {
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .lineLimit(2)

                Text(item.priceFormatted)
                    .font(.caption2)
                    .foregroundStyle(persona.primaryColor)
            }
        }
    }
}

struct OutfitMockupBubble: View {
    let mockup: OutfitMockup
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outfit Visualization")
                .font(.headline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            // 3D/Visual mockup would go here
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: mockup.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.8))

                        Text(mockup.description)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                )

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Style Match")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Text("\(Int(mockup.styleMatch * 100))%")
                        .font(.caption2)
                        .foregroundStyle(persona.primaryColor)
                }

                Spacer()

                Button("Try On") {
                    HapticManager.HapticType.selection.trigger()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(persona.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(persona.primaryColor, lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

struct MoodBoardBubble: View {
    let moodBoard: StyleMoodBoard
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Style Mood Board")
                .font(.headline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(moodBoard.images.prefix(9), id: \.self) { imageURL in
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(persona.primaryColor.opacity(0.3))
                    }
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Text(moodBoard.description)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondary)
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

struct ColorPaletteBubble: View {
    let palette: ColorPalette
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Color Palette")
                .font(.headline.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.primary)

            HStack(spacing: 8) {
                ForEach(palette.colors, id: \.self) { color in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4)

                        Text(color.hexString)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                }
            }

            Text(palette.description)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondary)
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

struct TrendExplanationBubble: View {
    let explanation: TrendExplanation
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(explanation.trendName)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Spacer()

                Text(explanation.season)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(persona.primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(persona.primaryColor.opacity(0.1))
                    )
            }

            Text(explanation.description)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondary)

            if !explanation.keyPieces.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Pieces:")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    FlowLayout(spacing: 6) {
                        ForEach(explanation.keyPieces, id: \.self) { piece in
                            Text(piece)
                                .font(.caption)
                                .foregroundStyle(persona.primaryColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(persona.primaryColor.opacity(0.1))
                                )
                        }
                    }
                }
            }

            Text("Adoption Level: \(explanation.adoptionLevel)")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.accent)
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

struct EducationContentBubble: View {
    let content: EducationContent
    let persona: StylistPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(persona.primaryColor)

                Text(content.title)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Spacer()
            }

            Text(content.content)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondary)

            if !content.tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pro Tips:")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.primary)

                    ForEach(content.tips, id: \.self) { tip in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(persona.primaryColor)
                                .font(.caption)

                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            GlassCardView(
                cornerRadius: 20,
                blurRadius: 10,
                opacity: 0.1
            ) {
                Rectangle().fill(.clear)
            }
        )
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    let persona: StylistPersona
    @State private var animationPhase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StylistAvatarView(persona: persona, size: 32)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(persona.primaryColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.surface)
            )

            Spacer()
        }
        .onAppear {
            animationPhase = 1
        }
    }
}

// MARK: - Chat Input Bar

struct ChatInputBarView: View {
    @Binding var messageText: String
    let selectedPersona: StylistPersona
    @Binding var isListening: Bool
    let onSendMessage: () -> Void
    let onVoiceInput: () -> Void
    let onImagePicker: () -> Void
    let onMoodBoard: () -> Void
    let onColorPalette: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Quick Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickActionChip(
                        title: "Mood Board",
                        icon: "photo.on.rectangle.angled",
                        color: selectedPersona.primaryColor,
                        action: onMoodBoard
                    )

                    QuickActionChip(
                        title: "Colors",
                        icon: "paintpalette",
                        color: selectedPersona.primaryColor,
                        action: onColorPalette
                    )

                    QuickActionChip(
                        title: "Photo",
                        icon: "camera",
                        color: selectedPersona.primaryColor,
                        action: onImagePicker
                    )
                }
                .padding(.horizontal, 20)
            }

            // Input Field
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Ask \(selectedPersona.name) anything...", text: $messageText, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...4)
                        .textFieldStyle(PlainTextFieldStyle())

                    Button(action: onVoiceInput) {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .font(.title2)
                            .foregroundStyle(
                                isListening
                                ? selectedPersona.primaryColor
                                : DesignSystem.Colors.secondary
                            )
                    }
                    .buttonStyle(SpringButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(DesignSystem.Colors.surface)
                        .stroke(DesignSystem.Colors.accent.opacity(0.2), lineWidth: 1)
                )

                Button(action: onSendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DesignSystem.Colors.secondary
                            : selectedPersona.primaryColor
                        )
                }
                .buttonStyle(SpringButtonStyle())
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.background.opacity(0.9))
                .blur(radius: 10)
        )
    }
}

struct QuickActionChip: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Stylist Avatar

struct StylistAvatarView: View {
    let persona: StylistPersona
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [persona.primaryColor, persona.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(persona.initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .overlay(
            Circle()
                .stroke(.white, lineWidth: size * 0.05)
        )
        .shadow(color: persona.primaryColor.opacity(0.3), radius: size * 0.1)
    }
}

// MARK: - Persona Selection

struct PersonaSelectionView: View {
    @Binding var selectedPersona: StylistPersona
    @Environment(\.dismiss) private var dismiss

    private let personas: [StylistPersona] = [
        .classic, .trendy, .minimalist, .bohemian, .edgy
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose Your Stylist")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                    ForEach(personas, id: \.self) { persona in
                        PersonaCard(
                            persona: persona,
                            isSelected: selectedPersona == persona,
                            onSelect: {
                                selectedPersona = persona
                                dismiss()
                                HapticManager.HapticType.success.trigger()
                            }
                        )
                    }
                }

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PersonaCard: View {
    let persona: StylistPersona
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            StylistAvatarView(persona: persona, size: 60)

            VStack(spacing: 8) {
                Text(persona.name)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text(persona.specialty)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surface)
                .stroke(
                    isSelected ? persona.primaryColor : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Data Models

enum StylistPersona: CaseIterable {
    case classic, trendy, minimalist, bohemian, edgy

    var name: String {
        switch self {
        case .classic: return "Sophia"
        case .trendy: return "Zara"
        case .minimalist: return "Luna"
        case .bohemian: return "Indie"
        case .edgy: return "Raven"
        }
    }

    var initials: String {
        return String(name.prefix(1))
    }

    var specialty: String {
        switch self {
        case .classic: return "Timeless elegance & sophisticated looks"
        case .trendy: return "Latest trends & fashion-forward styles"
        case .minimalist: return "Clean lines & capsule wardrobes"
        case .bohemian: return "Free-spirited & artistic expression"
        case .edgy: return "Bold statements & urban aesthetics"
        }
    }

    var welcomeMessage: String {
        switch self {
        case .classic:
            return "I specialize in timeless elegance and sophisticated styling. Let's create looks that never go out of style!"
        case .trendy:
            return "I'm all about the latest trends and fashion-forward looks. Ready to stay ahead of the curve?"
        case .minimalist:
            return "Less is more! I'll help you build a refined wardrobe with clean lines and versatile pieces."
        case .bohemian:
            return "Let's embrace your free spirit! I love mixing textures, patterns, and creating artistic expressions."
        case .edgy:
            return "Ready to make a statement? I'm here to help you push boundaries with bold, urban-inspired looks."
        }
    }

    var quickActions: [String] {
        switch self {
        case .classic:
            return ["Capsule Wardrobe", "Work Outfits", "Evening Looks", "Investment Pieces"]
        case .trendy:
            return ["Latest Trends", "Street Style", "Instagram-Worthy", "Celebrity Looks"]
        case .minimalist:
            return ["Color Analysis", "Wardrobe Audit", "Quality Basics", "Versatile Pieces"]
        case .bohemian:
            return ["Festival Style", "Layering Tips", "Vintage Finds", "Artistic Mixing"]
        case .edgy:
            return ["Statement Pieces", "Urban Style", "Bold Colors", "Alternative Fashion"]
        }
    }

    var primaryColor: Color {
        switch self {
        case .classic: return Color(red: 0.2, green: 0.3, blue: 0.5)
        case .trendy: return Color(red: 1.0, green: 0.4, blue: 0.7)
        case .minimalist: return Color(red: 0.4, green: 0.4, blue: 0.4)
        case .bohemian: return Color(red: 0.8, green: 0.6, blue: 0.3)
        case .edgy: return Color(red: 0.1, green: 0.1, blue: 0.1)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .classic: return Color(red: 0.8, green: 0.8, blue: 0.9)
        case .trendy: return Color(red: 0.9, green: 0.7, blue: 0.8)
        case .minimalist: return Color(red: 0.9, green: 0.9, blue: 0.9)
        case .bohemian: return Color(red: 0.9, green: 0.8, blue: 0.6)
        case .edgy: return Color(red: 0.3, green: 0.3, blue: 0.3)
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let messageType: MessageType
}

enum MessageType {
    case text
    case image(UIImage)
    case imageAnalysis(ImageAnalysisResult)
    case shoppingList([ShoppingItem])
    case outfitMockup(OutfitMockup)
    case moodBoard(StyleMoodBoard)
    case colorPalette(ColorPalette)
    case trendExplanation(TrendExplanation)
    case educationContent(EducationContent)
}

struct ImageAnalysisResult {
    let detectedStyle: String
    let dominantColors: [Color]
    let suggestedOccasion: String
    let qualityScore: Double
    let recommendations: [String]
    let description: String
}

struct ShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let imageURL: URL?
    let brand: String
    let category: String

    var priceFormatted: String {
        return String(format: "$%.0f", price)
    }
}

struct OutfitMockup {
    let description: String
    let colors: [Color]
    let styleMatch: Double
}

struct StyleMoodBoard {
    let images: [URL]
    let description: String
    let theme: String
}

struct ColorPalette {
    let colors: [Color]
    let description: String
    let season: String
}

struct TrendExplanation {
    let trendName: String
    let description: String
    let season: String
    let keyPieces: [String]
    let adoptionLevel: String
}

struct EducationContent {
    let title: String
    let content: String
    let tips: [String]
    let category: String
}

// MARK: - Chat Manager

@MainActor
class AIStylistChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false
    @Published var currentPersona: StylistPersona = .classic

    private let aiEngine = AIStyleEngine.shared
    private var conversationHistory: [ChatMessage] = []

    func setupPersona(_ persona: StylistPersona) {
        currentPersona = persona
    }

    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        conversationHistory.append(message)
        saveConversationHistory()
    }

    func generateResponse(to message: ChatMessage, persona: StylistPersona) async {
        isTyping = true

        // Simulate AI thinking time
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let response = await generateAIResponse(for: message, persona: persona)

        await MainActor.run {
            let responseMessage = ChatMessage(
                id: UUID(),
                content: response.content,
                isFromUser: false,
                timestamp: Date(),
                messageType: response.messageType
            )
            addMessage(responseMessage)
            isTyping = false
        }
    }

    private func generateAIResponse(for message: ChatMessage, persona: StylistPersona) async -> (content: String, messageType: MessageType) {
        // This would integrate with the AI engine
        let responses = [
            "That's a great question! Based on your style preferences, I'd recommend...",
            "I love that choice! Here's how you can style it...",
            "Let me analyze your wardrobe and suggest some combinations...",
            "That color would look amazing on you! Here's why...",
        ]

        return (
            content: responses.randomElement() ?? "I'd love to help you with that!",
            messageType: .text
        )
    }

    func generateMoodBoard(for persona: StylistPersona) async -> StyleMoodBoard {
        return StyleMoodBoard(
            images: [],
            description: "A curated mood board reflecting \(persona.name)'s aesthetic",
            theme: persona.specialty
        )
    }

    func generateColorPalette(for persona: StylistPersona) async -> ColorPalette {
        return ColorPalette(
            colors: [persona.primaryColor, persona.secondaryColor, .white, .black, .gray],
            description: "Colors that complement your personal style",
            season: "All Seasons"
        )
    }

    func loadConversationHistory() async {
        // Load from Core Data or local storage
    }

    func saveConversationHistory() {
        // Save to Core Data or local storage
    }

    func clearMessages() {
        messages.removeAll()
        conversationHistory.removeAll()
    }

    func exportConversation() async {
        // Export conversation as PDF or text
    }

    func checkProactiveSuggestions() async {
        // Check for proactive suggestions based on user behavior
    }
}

// MARK: - Voice Manager

class VoiceManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func setupVoice(for persona: StylistPersona) {
        // Configure voice synthesis for persona
    }

    func startListening() async -> String {
        // Implement speech-to-text
        return "Voice input would be transcribed here"
    }

    func speak(_ text: String, for persona: StylistPersona) {
        let utterance = AVSpeechUtterance(string: text)
        // Configure voice characteristics for persona
        synthesizer.speak(utterance)
    }
}

// MARK: - Image Analyzer

class ChatImageAnalyzer: ObservableObject {
    func analyzeImage(_ image: UIImage, completion: @escaping (ImageAnalysisResult) -> Void) async {
        // This would use the AI engine to analyze images
        let analysis = ImageAnalysisResult(
            detectedStyle: "Casual Chic",
            dominantColors: [.blue, .white, .denim],
            suggestedOccasion: "Weekend Brunch",
            qualityScore: 0.85,
            recommendations: [
                "Perfect for casual outings",
                "Add a statement necklace",
                "Pair with white sneakers"
            ],
            description: "This is a versatile casual look that works well for daytime activities."
        )

        await MainActor.run {
            completion(analysis)
        }
    }
}

// MARK: - Additional Views

struct StylistMenuView: View {
    let onEducationMode: () -> Void
    let onClearChat: () -> Void
    let onExportChat: () -> Void
    let onVoiceSettings: () -> Void

    var body: some View {
        Button("Fashion Education") {
            onEducationMode()
        }

        Button("Voice Settings") {
            onVoiceSettings()
        }

        Divider()

        Button("Export Chat") {
            onExportChat()
        }

        Button("Clear Chat") {
            onClearChat()
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
    }
}

struct FashionEducationView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Fashion Education")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Learn about fashion trends, styling tips, and more")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Extensions

extension Color {
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
}

#Preview {
    AIStylistView()
        .modelContainer(for: [StyleItem.self], inMemory: true)
}