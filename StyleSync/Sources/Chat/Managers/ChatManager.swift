import SwiftUI
import Combine

@MainActor
class ChatManager: ObservableObject {
    @Published var currentSession: ChatSession
    @Published var isAITyping = false
    @Published var typingAnimationScale: [CGFloat] = [1.0, 1.0, 1.0]
    @Published var quickSuggestions: [String] = []
    @Published var replyingTo: ChatMessage?
    
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private let aiResponseManager = AIResponseManager()
    private let visualAnalysisManager = VisualAnalysisManager()
    private let privacyManager = PrivacyManager()
    
    // Context awareness
    @Published var conversationContext: ConversationContext = ConversationContext()
    private var previousOutfits: [OutfitMessage] = []
    private var userPreferences: UserPreferences = UserPreferences()
    
    init() {
        self.currentSession = ChatSession()
        setupInitialState()
        startTypingAnimation()
    }
    
    // MARK: - Session Management
    func startSession() {
        generateWelcomeMessage()
        updateQuickSuggestions()
    }
    
    func clearChat() {
        currentSession.messages.removeAll()
        conversationContext = ConversationContext()
        previousOutfits.removeAll()
        generateWelcomeMessage()
        updateQuickSuggestions()
    }
    
    func exportChat() -> URL? {
        let chatData = encodeChatSession()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "StyleSync_Chat_\(Date().timeIntervalSince1970).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try chatData.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export chat: \(error)")
            return nil
        }
    }
    
    // MARK: - Message Sending
    func sendMessage(_ message: ChatMessage) {
        // Add message to session
        var updatedMessage = message
        updatedMessage.status = .sent
        currentSession.messages.append(updatedMessage)
        
        // Update context
        updateConversationContext(with: updatedMessage)
        
        // Generate AI response
        Task {
            await generateAIResponse(to: updatedMessage)
        }
        
        // Update suggestions
        updateQuickSuggestions()
        
        // Mark as delivered/read after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateMessageStatus(messageId: updatedMessage.id, status: .delivered)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateMessageStatus(messageId: updatedMessage.id, status: .read)
        }
    }
    
    func sendImageMessage(image: UIImage, isOutfit: Bool = false) {
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        
        // Apply privacy blur if enabled
        let processedImageData = currentSession.settings.blurImagesBeforeSending ? 
            privacyManager.blurImage(imageData) : imageData
        
        let imageMessage = ImageMessage(
            imageData: processedImageData,
            caption: nil,
            isOutfit: isOutfit,
            analysisResults: nil
        )
        
        let message = ChatMessage(
            content: .image(imageMessage),
            sender: .user
        )
        
        sendMessage(message)
        
        // Perform visual analysis
        if isOutfit {
            Task {
                await performVisualAnalysis(for: message.id, imageData: imageData)
            }
        }
    }
    
    func sendVoiceMessage(_ voiceMessage: VoiceMessage) {
        let message = ChatMessage(
            content: .voice(voiceMessage),
            sender: .user
        )
        
        sendMessage(message)
        
        // Transcribe voice message if needed
        if voiceMessage.transcription == nil {
            Task {
                await transcribeVoiceMessage(messageId: message.id)
            }
        }
    }
    
    func sendColorMessage(color: Color) {
        let colorMessage = ColorMessage(
            color: CodableColor(color: color),
            colorName: getColorName(for: color),
            season: determineColorSeason(for: color),
            suggestions: generateColorSuggestions(for: color)
        )
        
        let message = ChatMessage(
            content: .color(colorMessage),
            sender: .user
        )
        
        sendMessage(message)
    }
    
    func sendSketchMessage(sketch: SketchData) {
        let sketchMessage = SketchMessage(
            drawingData: sketch.data,
            strokes: sketch.strokes,
            description: nil
        )
        
        let message = ChatMessage(
            content: .sketch(sketchMessage),
            sender: .user
        )
        
        sendMessage(message)
        
        // Analyze sketch
        Task {
            await analyzeSketch(for: message.id, sketch: sketch)
        }
    }
    
    // MARK: - AI Response Generation
    private func generateAIResponse(to message: ChatMessage) async {
        isAITyping = true
        
        // Simulate thinking delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let persona = currentSession.settings.currentPersona
        let response = await aiResponseManager.generateResponse(
            to: message,
            context: conversationContext,
            persona: persona,
            previousOutfits: previousOutfits
        )
        
        let aiMessage = ChatMessage(
            content: response.content,
            sender: .ai(persona: persona),
            replyTo: message.id
        )
        
        currentSession.messages.append(aiMessage)
        updateConversationContext(with: aiMessage)
        
        // Update suggestions based on AI response
        quickSuggestions = response.suggestedReplies
        
        isAITyping = false
        
        // Update message status
        updateMessageStatus(messageId: aiMessage.id, status: .delivered)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateMessageStatus(messageId: aiMessage.id, status: .read)
        }
    }
    
    // MARK: - Message Reactions
    func addReaction(to messageId: UUID, emoji: String) {
        guard let index = currentSession.messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        let reaction = MessageReaction(
            emoji: emoji,
            sender: .user,
            timestamp: Date()
        )
        
        // Remove existing reaction from user if any
        currentSession.messages[index].reactions.removeAll { $0.sender.isUser && $0.emoji == emoji }
        
        // Add new reaction
        currentSession.messages[index].reactions.append(reaction)
        
        // Generate AI reaction if appropriate
        if shouldAIReact(to: emoji) {
            let aiReaction = MessageReaction(
                emoji: getAIReactionResponse(to: emoji),
                sender: .ai(persona: currentSession.settings.currentPersona),
                timestamp: Date()
            )
            currentSession.messages[index].reactions.append(aiReaction)
        }
    }
    
    // MARK: - Reply Management
    func startReply(to messageId: UUID) {
        replyingTo = currentSession.messages.first { $0.id == messageId }
    }
    
    func cancelReply() {
        replyingTo = nil
    }
    
    // MARK: - Typing Indicators
    func updateTypingStatus(_ isTyping: Bool) {
        if isTyping {
            startTypingTimer()
        } else {
            stopTypingTimer()
        }
    }
    
    private func startTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            // Stop typing indicator after 2 seconds of inactivity
        }
    }
    
    private func stopTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = nil
    }
    
    // MARK: - Visual Analysis
    private func performVisualAnalysis(for messageId: UUID, imageData: Data) async {
        guard let index = currentSession.messages.firstIndex(where: { $0.id == messageId }),
              case .image(var imageMessage) = currentSession.messages[index].content else { return }
        
        let analysis = await visualAnalysisManager.analyzeImage(imageData)
        imageMessage.analysisResults = analysis
        currentSession.messages[index].content = .image(imageMessage)
        
        // Generate analysis message from AI
        let analysisContent = AnalysisMessage(
            analysisType: .outfitFeedback,
            results: convertToAnalysisResults(analysis),
            confidence: analysis.confidence,
            recommendations: generateRecommendations(from: analysis)
        )
        
        let aiMessage = ChatMessage(
            content: .analysis(analysisContent),
            sender: .ai(persona: currentSession.settings.currentPersona),
            replyTo: messageId
        )
        
        currentSession.messages.append(aiMessage)
    }
    
    // MARK: - Voice Transcription
    private func transcribeVoiceMessage(messageId: UUID) async {
        // Implementation for voice transcription
        // This would integrate with speech recognition services
    }
    
    // MARK: - Sketch Analysis
    private func analyzeSketch(for messageId: UUID, sketch: SketchData) async {
        // Implementation for sketch analysis
        // This would use AI to interpret the sketch and provide suggestions
    }
    
    // MARK: - Context Management
    private func updateConversationContext(with message: ChatMessage) {
        conversationContext.messageCount += 1
        conversationContext.lastActivity = Date()
        
        // Extract relevant information based on message type
        switch message.content {
        case .text(let text):
            conversationContext.topics.append(extractTopics(from: text))
        case .outfit(let outfit):
            previousOutfits.append(outfit)
            conversationContext.stylePreferences.append(outfit.style)
        case .color(let color):
            conversationContext.preferredColors.append(color.colorName)
        default:
            break
        }
        
        // Maintain context window
        if conversationContext.topics.count > 50 {
            conversationContext.topics = Array(conversationContext.topics.suffix(50))
        }
    }
    
    // MARK: - Quick Suggestions
    private func updateQuickSuggestions() {
        let persona = currentSession.settings.currentPersona
        let recentMessages = Array(currentSession.messages.suffix(3))
        
        quickSuggestions = generateContextualSuggestions(
            for: persona,
            recentMessages: recentMessages,
            context: conversationContext
        )
    }
    
    private func generateContextualSuggestions(
        for persona: AIPersona,
        recentMessages: [ChatMessage],
        context: ConversationContext
    ) -> [String] {
        var suggestions: [String] = []
        
        // Base suggestions based on persona
        switch persona.personality {
        case .friendly:
            suggestions = ["What do you think?", "Can you help me?", "Show me more", "That's perfect!"]
        case .professional:
            suggestions = ["Please analyze this", "What are the options?", "Provide details", "Thank you"]
        case .creative:
            suggestions = ["That's interesting!", "Try something bold", "Mix it up", "Love the creativity!"]
        case .casual:
            suggestions = ["Cool!", "What else?", "Nice choice", "Let's see more"]
        case .expert:
            suggestions = ["Explain the reasoning", "What's the methodology?", "Show technical details", "Analyze further"]
        }
        
        // Add contextual suggestions based on recent activity
        if let lastMessage = recentMessages.last {
            switch lastMessage.content {
            case .image:
                suggestions.append("Analyze this outfit")
                suggestions.append("Suggest improvements")
            case .color:
                suggestions.append("Show similar colors")
                suggestions.append("What season is this?")
            case .outfit:
                suggestions.append("Save this style")
                suggestions.append("Shop similar items")
            default:
                break
            }
        }
        
        return Array(suggestions.prefix(4))
    }
    
    // MARK: - Helper Methods
    private func setupInitialState() {
        // Setup typing animation
        startTypingAnimation()
    }
    
    private func startTypingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                for i in 0..<3 {
                    self.typingAnimationScale[i] = self.isAITyping ? (i % 2 == 0 ? 1.2 : 0.8) : 1.0
                }
            }
        }
    }
    
    private func generateWelcomeMessage() {
        let persona = currentSession.settings.currentPersona
        let welcomeText = generatePersonalizedWelcome(for: persona)
        
        let welcomeMessage = ChatMessage(
            content: .text(welcomeText),
            sender: .ai(persona: persona),
            status: .read
        )
        
        currentSession.messages.append(welcomeMessage)
    }
    
    private func generatePersonalizedWelcome(for persona: AIPersona) -> String {
        switch persona.personality {
        case .friendly:
            return "Hi! I'm \(persona.name), your friendly style assistant! 👋 Ready to explore some amazing looks together?"
        case .professional:
            return "Good day! I'm \(persona.name), your professional styling consultant. How may I assist you with your wardrobe today?"
        case .creative:
            return "Hey there! \(persona.name) here! ✨ Let's create something absolutely stunning together. What's inspiring you today?"
        case .casual:
            return "Hey! I'm \(persona.name) 😊 What's up? Ready to have some fun with fashion?"
        case .expert:
            return "Hello, I'm \(persona.name), your expert style analyst. I'm here to provide detailed fashion insights and recommendations."
        }
    }
    
    private func updateMessageStatus(messageId: UUID, status: MessageStatus) {
        guard let index = currentSession.messages.firstIndex(where: { $0.id == messageId }) else { return }
        currentSession.messages[index].status = status
    }
    
    private func encodeChatSession() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(currentSession)) ?? Data()
    }
    
    private func getColorName(for color: Color) -> String {
        // Simplified color naming - in practice, this would use a comprehensive color database
        return "Custom Color"
    }
    
    private func determineColorSeason(for color: Color) -> ColorSeason? {
        // Simplified color season analysis
        return .spring
    }
    
    private func generateColorSuggestions(for color: Color) -> [String] {
        return ["Complementary colors", "Analogous palette", "Monochromatic scheme"]
    }
    
    private func shouldAIReact(to emoji: String) -> Bool {
        // Determine if AI should react based on emoji and context
        return ["❤️", "👍", "🔥", "✨"].contains(emoji)
    }
    
    private func getAIReactionResponse(to emoji: String) -> String {
        switch emoji {
        case "❤️": return "😊"
        case "👍": return "👍"
        case "🔥": return "✨"
        default: return "😊"
        }
    }
    
    private func extractTopics(from text: String) -> [String] {
        // Simple topic extraction - in practice, this would use NLP
        let words = text.lowercased().components(separatedBy: .whitespacesAndPunctuation)
        let styleKeywords = ["outfit", "dress", "shirt", "pants", "color", "style", "fashion", "look"]
        return words.filter { styleKeywords.contains($0) }
    }
    
    private func convertToAnalysisResults(_ analysis: VisualAnalysisResult) -> [AnalysisResult] {
        var results: [AnalysisResult] = []
        
        if let bodyShape = analysis.bodyShape {
            results.append(AnalysisResult(
                category: "Body Shape",
                score: analysis.confidence,
                description: bodyShape,
                recommendations: ["Enhance your natural silhouette", "Focus on proportional balance"]
            ))
        }
        
        if let colorSeason = analysis.colorSeason {
            results.append(AnalysisResult(
                category: "Color Season",
                score: analysis.confidence,
                description: colorSeason,
                recommendations: ["Choose colors that complement your undertones", "Avoid colors that wash you out"]
            ))
        }
        
        return results
    }
    
    private func generateRecommendations(from analysis: VisualAnalysisResult) -> [String] {
        var recommendations: [String] = []
        
        for note in analysis.styleNotes {
            recommendations.append("Consider \(note.lowercased())")
        }
        
        if recommendations.isEmpty {
            recommendations = ["Great style choices!", "Keep experimenting with different looks"]
        }
        
        return recommendations
    }
}

// MARK: - Supporting Data Models
struct ConversationContext {
    var messageCount: Int = 0
    var topics: [[String]] = []
    var stylePreferences: [String] = []
    var preferredColors: [String] = []
    var lastActivity: Date = Date()
}

struct UserPreferences {
    var favoriteColors: [String] = []
    var bodyType: String?
    var stylePersonality: String?
    var preferredBrands: [String] = []
}

struct SketchData {
    let data: Data
    let strokes: [DrawingStroke]
}

// MARK: - MessageSender Extension
extension MessageSender {
    var isUser: Bool {
        switch self {
        case .user: return true
        case .ai: return false
        }
    }
}