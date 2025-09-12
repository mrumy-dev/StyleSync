import Foundation
import SwiftUI

@MainActor
class AIResponseManager: ObservableObject {
    private let contextAnalyzer = ContextAnalyzer()
    private let styleAnalyzer = StyleAnalyzer()
    private let responseGenerator = ResponseGenerator()
    private let learningEngine = LearningEngine()
    
    // AI Response structure
    struct AIResponse {
        let content: MessageContent
        let suggestedReplies: [String]
        let confidence: Float
        let reasoning: String
        let followUpActions: [String]
    }
    
    // Generate AI response based on user message and context
    func generateResponse(
        to message: ChatMessage,
        context: ConversationContext,
        persona: AIPersona,
        previousOutfits: [OutfitMessage]
    ) async -> AIResponse {
        
        // Analyze the context and user intent
        let intent = await analyzeIntent(message: message, context: context)
        let mood = determineMood(from: context)
        let styleProfile = buildStyleProfile(from: previousOutfits)
        
        // Generate response based on message type and persona
        switch message.content {
        case .text(let text):
            return await generateTextResponse(
                text: text,
                intent: intent,
                persona: persona,
                context: context,
                mood: mood,
                styleProfile: styleProfile
            )
            
        case .image(let imageMessage):
            return await generateImageResponse(
                imageMessage: imageMessage,
                persona: persona,
                context: context,
                styleProfile: styleProfile
            )
            
        case .voice(let voiceMessage):
            return await generateVoiceResponse(
                voiceMessage: voiceMessage,
                persona: persona,
                context: context
            )
            
        case .color(let colorMessage):
            return await generateColorResponse(
                colorMessage: colorMessage,
                persona: persona,
                styleProfile: styleProfile
            )
            
        case .sketch(let sketchMessage):
            return await generateSketchResponse(
                sketchMessage: sketchMessage,
                persona: persona,
                context: context
            )
            
        default:
            return generateFallbackResponse(persona: persona)
        }
    }
    
    // MARK: - Intent Analysis
    private func analyzeIntent(message: ChatMessage, context: ConversationContext) async -> UserIntent {
        let analyzer = IntentAnalyzer()
        return await analyzer.analyze(message: message, context: context)
    }
    
    // MARK: - Text Response Generation
    private func generateTextResponse(
        text: String,
        intent: UserIntent,
        persona: AIPersona,
        context: ConversationContext,
        mood: UserMood,
        styleProfile: StyleProfile
    ) async -> AIResponse {
        
        let responseText: String
        let suggestedReplies: [String]
        let followUpActions: [String]
        
        switch intent {
        case .askingForAdvice:
            (responseText, suggestedReplies, followUpActions) = await generateAdviceResponse(
                text: text,
                persona: persona,
                styleProfile: styleProfile,
                mood: mood
            )
            
        case .showingOutfit:
            (responseText, suggestedReplies, followUpActions) = await generateOutfitFeedbackResponse(
                text: text,
                persona: persona,
                styleProfile: styleProfile
            )
            
        case .askingQuestion:
            (responseText, suggestedReplies, followUpActions) = await generateQuestionResponse(
                text: text,
                persona: persona,
                context: context
            )
            
        case .expressing:
            (responseText, suggestedReplies, followUpActions) = await generateEmpatheticResponse(
                text: text,
                persona: persona,
                mood: mood
            )
            
        case .requestingSuggestion:
            (responseText, suggestedReplies, followUpActions) = await generateSuggestionResponse(
                text: text,
                persona: persona,
                styleProfile: styleProfile,
                context: context
            )
            
        default:
            (responseText, suggestedReplies, followUpActions) = generateGeneralResponse(
                text: text,
                persona: persona
            )
        }
        
        // Learn from interaction
        await learningEngine.recordInteraction(
            userMessage: text,
            aiResponse: responseText,
            persona: persona,
            context: context
        )
        
        return AIResponse(
            content: .text(responseText),
            suggestedReplies: suggestedReplies,
            confidence: 0.85,
            reasoning: "Generated based on user intent and persona characteristics",
            followUpActions: followUpActions
        )
    }
    
    // MARK: - Image Response Generation
    private func generateImageResponse(
        imageMessage: ImageMessage,
        persona: AIPersona,
        context: ConversationContext,
        styleProfile: StyleProfile
    ) async -> AIResponse {
        
        // Analyze the image for style elements
        let analysis = await styleAnalyzer.analyzeOutfitImage(imageMessage.imageData)
        
        let responseText: String
        var suggestedReplies: [String] = []
        var followUpActions: [String] = []
        
        if imageMessage.isOutfit {
            // Generate outfit feedback
            (responseText, suggestedReplies, followUpActions) = generateOutfitAnalysisResponse(
                analysis: analysis,
                persona: persona,
                styleProfile: styleProfile
            )
        } else {
            // General image response
            responseText = generatePersonalizedImageComment(
                analysis: analysis,
                persona: persona
            )
            suggestedReplies = ["Tell me more", "What do you think?", "Any suggestions?"]
            followUpActions = ["analyze_style", "suggest_similar"]
        }
        
        return AIResponse(
            content: .text(responseText),
            suggestedReplies: suggestedReplies,
            confidence: analysis.confidence,
            reasoning: "Image analysis with style feedback",
            followUpActions: followUpActions
        )
    }
    
    // MARK: - Specialized Response Generators
    
    private func generateAdviceResponse(
        text: String,
        persona: AIPersona,
        styleProfile: StyleProfile,
        mood: UserMood
    ) async -> (String, [String], [String]) {
        
        let advice = await styleAnalyzer.generateAdvice(
            query: text,
            styleProfile: styleProfile,
            persona: persona
        )
        
        let responseText = formatAdviceResponse(advice: advice, persona: persona, mood: mood)
        
        let suggestedReplies: [String] = [
            "That's helpful!",
            "Can you show me examples?",
            "What about colors?",
            "Any specific brands?"
        ]
        
        let followUpActions: [String] = [
            "show_examples",
            "create_mood_board",
            "suggest_shopping"
        ]
        
        return (responseText, suggestedReplies, followUpActions)
    }
    
    private func generateOutfitFeedbackResponse(
        text: String,
        persona: AIPersona,
        styleProfile: StyleProfile
    ) async -> (String, [String], [String]) {
        
        let feedback = await styleAnalyzer.generateOutfitFeedback(
            description: text,
            styleProfile: styleProfile,
            persona: persona
        )
        
        let responseText = formatFeedbackResponse(feedback: feedback, persona: persona)
        
        let suggestedReplies: [String] = [
            "Love it!",
            "What would you change?",
            "Show me similar looks",
            "Save this style"
        ]
        
        let followUpActions: [String] = [
            "save_outfit",
            "find_similar",
            "suggest_improvements"
        ]
        
        return (responseText, suggestedReplies, followUpActions)
    }
    
    private func generateSuggestionResponse(
        text: String,
        persona: AIPersona,
        styleProfile: StyleProfile,
        context: ConversationContext
    ) async -> (String, [String], [String]) {
        
        let suggestions = await styleAnalyzer.generateSuggestions(
            request: text,
            styleProfile: styleProfile,
            context: context,
            persona: persona
        )
        
        let responseText = formatSuggestionsResponse(suggestions: suggestions, persona: persona)
        
        let suggestedReplies: [String] = [
            "Perfect!",
            "Show me more",
            "What about accessories?",
            "Where can I buy this?"
        ]
        
        let followUpActions: [String] = [
            "create_outfit",
            "find_shopping_links",
            "suggest_accessories"
        ]
        
        return (responseText, suggestedReplies, followUpActions)
    }
    
    private func generateEmpatheticResponse(
        text: String,
        persona: AIPersona,
        mood: UserMood
    ) async -> (String, [String], [String]) {
        
        let empathy = EmpatheticResponseGenerator()
        let response = await empathy.generateResponse(
            userExpression: text,
            persona: persona,
            mood: mood
        )
        
        let suggestedReplies: [String] = [
            "Thank you",
            "You're so understanding",
            "That helps a lot",
            "What should I do next?"
        ]
        
        let followUpActions: [String] = [
            "provide_comfort",
            "offer_solutions",
            "suggest_activities"
        ]
        
        return (response, suggestedReplies, followUpActions)
    }
    
    // MARK: - Response Formatting
    
    private func formatAdviceResponse(advice: StyleAdvice, persona: AIPersona, mood: UserMood) -> String {
        let baseResponse = advice.mainAdvice
        
        switch persona.communicationStyle {
        case .casual:
            return "Hey! \(baseResponse) 😊 \(advice.supportingTips.first ?? "")"
            
        case .formal:
            return "I'd recommend \(baseResponse). \(advice.reasoning)"
            
        case .enthusiastic:
            return "Oh, I love this question! ✨ \(baseResponse) This is going to look amazing on you!"
            
        case .direct:
            return baseResponse
            
        case .supportive:
            return "I understand what you're going for! \(baseResponse) You've got great instincts."
        }
    }
    
    private func formatFeedbackResponse(feedback: OutfitFeedback, persona: AIPersona) -> String {
        let compliments = feedback.positives.joined(separator: ", ")
        let suggestions = feedback.suggestions.first ?? ""
        
        switch persona.personality {
        case .friendly:
            return "I love \(compliments)! \(suggestions.isEmpty ? "You look amazing!" : "Maybe try \(suggestions)?")"
            
        case .professional:
            return "This outfit demonstrates \(compliments). \(suggestions.isEmpty ? "Well executed." : "Consider \(suggestions) to enhance the look.")"
            
        case .creative:
            return "What an interesting choice with \(compliments)! \(suggestions.isEmpty ? "So unique!" : "You could totally \(suggestions) to make it even more artistic!")"
            
        case .casual:
            return "Nice! Love the \(compliments). \(suggestions.isEmpty ? "Looks great!" : "\(suggestions) could be cool too!")"
            
        case .expert:
            return "Technically, the \(compliments) work well together. \(suggestions.isEmpty ? "Solid execution." : "From a styling perspective, \(suggestions).")"
        }
    }
    
    private func formatSuggestionsResponse(suggestions: StyleSuggestions, persona: AIPersona) -> String {
        let mainSuggestion = suggestions.primary
        let context = suggestions.context
        
        switch persona.responsePatterns {
        case .encouraging:
            return "You're going to look incredible! I suggest \(mainSuggestion). \(context)"
            
        case .detailed:
            return "Based on your style profile, I recommend \(mainSuggestion). Here's why: \(context). \(suggestions.reasoning)"
            
        case .innovative:
            return "Let's try something fresh! What if you \(mainSuggestion)? \(context) It'll be a total game-changer!"
            
        case .practical:
            return "For your situation, \(mainSuggestion) makes the most sense. \(context)"
            
        case .analytical:
            return "Analyzing your preferences, \(mainSuggestion) scores highest. \(context) Confidence: \(Int(suggestions.confidence * 100))%"
        }
    }
    
    // MARK: - Fallback and Utility Methods
    
    private func generateFallbackResponse(persona: AIPersona) -> AIResponse {
        let responses = getFallbackResponses(for: persona)
        let randomResponse = responses.randomElement() ?? "I'm here to help with your style!"
        
        return AIResponse(
            content: .text(randomResponse),
            suggestedReplies: ["Tell me more", "What do you suggest?", "Help me choose"],
            confidence: 0.6,
            reasoning: "Fallback response for unclear input",
            followUpActions: ["clarify_intent"]
        )
    }
    
    private func getFallbackResponses(for persona: AIPersona) -> [String] {
        switch persona.personality {
        case .friendly:
            return [
                "I'm not sure I understood that completely, but I'm here to help! What are you thinking about?",
                "Tell me more about what you're looking for! 😊",
                "I want to make sure I give you the best advice - can you help me understand?"
            ]
            
        case .professional:
            return [
                "Could you please clarify your request so I can provide the most relevant assistance?",
                "I'd like to better understand your styling needs to offer appropriate recommendations.",
                "Please provide additional context so I can assist you effectively."
            ]
            
        case .creative:
            return [
                "Ooh, intriguing! Tell me more about your vision! ✨",
                "I sense there's something creative brewing - share your ideas!",
                "Let's explore this together - what's inspiring you?"
            ]
            
        case .casual:
            return [
                "Not sure I got that - what's up?",
                "Can you break that down for me?",
                "Help me out - what are you thinking?"
            ]
            
        case .expert:
            return [
                "I need more specific parameters to provide accurate recommendations.",
                "Could you elaborate on the technical requirements?",
                "Additional context would improve the precision of my analysis."
            ]
        }
    }
    
    // MARK: - Utility Methods
    
    private func determineMood(from context: ConversationContext) -> UserMood {
        // Simplified mood analysis - in practice, this would use sentiment analysis
        let recentTopics = context.topics.suffix(5).flatMap { $0 }
        
        if recentTopics.contains(where: { ["love", "amazing", "perfect", "great"].contains($0) }) {
            return .positive
        } else if recentTopics.contains(where: { ["help", "confused", "unsure"].contains($0) }) {
            return .seeking
        } else if recentTopics.contains(where: { ["hate", "terrible", "awful"].contains($0) }) {
            return .negative
        } else {
            return .neutral
        }
    }
    
    private func buildStyleProfile(from outfits: [OutfitMessage]) -> StyleProfile {
        let styles = outfits.map { $0.style }
        let occasions = outfits.map { $0.occasion }
        
        return StyleProfile(
            preferredStyles: Array(Set(styles)),
            commonOccasions: Array(Set(occasions)),
            averageConfidence: outfits.map { $0.confidence }.reduce(0, +) / Float(max(outfits.count, 1)),
            colorPreferences: [], // Would be extracted from outfit analysis
            brandPreferences: []
        )
    }
    
    // MARK: - Voice and Color Responses
    
    private func generateVoiceResponse(
        voiceMessage: VoiceMessage,
        persona: AIPersona,
        context: ConversationContext
    ) async -> AIResponse {
        
        let transcription = voiceMessage.transcription ?? "I heard your voice message"
        let response = "Thanks for the voice message! \(transcription.isEmpty ? "I'm processing what you said." : "I understand you said: '\(transcription)'")"
        
        return AIResponse(
            content: .text(response),
            suggestedReplies: ["That's right!", "Let me clarify", "What do you think?"],
            confidence: 0.75,
            reasoning: "Voice message acknowledgment",
            followUpActions: ["clarify_transcription", "continue_conversation"]
        )
    }
    
    private func generateColorResponse(
        colorMessage: ColorMessage,
        persona: AIPersona,
        styleProfile: StyleProfile
    ) async -> AIResponse {
        
        let colorAnalysis = await styleAnalyzer.analyzeColor(
            colorMessage.color.color,
            in: styleProfile
        )
        
        let response = formatColorAnalysisResponse(
            colorName: colorMessage.colorName,
            analysis: colorAnalysis,
            persona: persona
        )
        
        return AIResponse(
            content: .text(response),
            suggestedReplies: ["Show me outfits", "What colors match?", "Love it!", "Not sure about it"],
            confidence: 0.8,
            reasoning: "Color analysis and style matching",
            followUpActions: ["suggest_matching_colors", "create_color_palette"]
        )
    }
    
    private func generateSketchResponse(
        sketchMessage: SketchMessage,
        persona: AIPersona,
        context: ConversationContext
    ) async -> AIResponse {
        
        let response = generateSketchInterpretationResponse(persona: persona)
        
        return AIResponse(
            content: .text(response),
            suggestedReplies: ["That's right!", "Close!", "Try again", "I love your creativity!"],
            confidence: 0.7,
            reasoning: "Sketch interpretation and creative encouragement",
            followUpActions: ["interpret_sketch", "suggest_similar_items"]
        )
    }
    
    private func formatColorAnalysisResponse(
        colorName: String,
        analysis: ColorAnalysis,
        persona: AIPersona
    ) -> String {
        switch persona.personality {
        case .friendly:
            return "Beautiful \(colorName)! This color \(analysis.characteristics). It would look amazing with \(analysis.suggestions.joined(separator: " or "))!"
            
        case .professional:
            return "The \(colorName) you've selected \(analysis.characteristics). I recommend pairing it with \(analysis.suggestions.joined(separator: ", "))."
            
        case .creative:
            return "Ooh, \(colorName)! What a choice! ✨ This color \(analysis.characteristics) and opens up so many possibilities with \(analysis.suggestions.joined(separator: ", "))!"
            
        default:
            return "Nice \(colorName)! This \(analysis.characteristics) and works well with \(analysis.suggestions.joined(separator: " and "))."
        }
    }
    
    private func generateSketchInterpretationResponse(persona: AIPersona) -> String {
        switch persona.personality {
        case .creative:
            return "I love your artistic vision! ✨ I can see some interesting design elements in your sketch. Are you thinking of a particular garment or style?"
            
        case .friendly:
            return "What a fun sketch! I can see you're being creative. Tell me more about what you're envisioning! 😊"
            
        case .professional:
            return "Thank you for sharing your design concept. Could you elaborate on the specific elements you'd like to incorporate?"
            
        default:
            return "Interesting sketch! I can see some design ideas forming. What were you thinking of creating?"
        }
    }
}

// MARK: - Supporting Data Models and Classes

struct UserIntent: Codable {
    static let askingForAdvice = UserIntent(type: "asking_for_advice", confidence: 0.9)
    static let showingOutfit = UserIntent(type: "showing_outfit", confidence: 0.85)
    static let askingQuestion = UserIntent(type: "asking_question", confidence: 0.8)
    static let expressing = UserIntent(type: "expressing", confidence: 0.75)
    static let requestingSuggestion = UserIntent(type: "requesting_suggestion", confidence: 0.9)
    static let general = UserIntent(type: "general", confidence: 0.6)
    
    let type: String
    let confidence: Float
}

enum UserMood {
    case positive, negative, neutral, seeking, excited, frustrated
}

struct StyleProfile {
    let preferredStyles: [String]
    let commonOccasions: [String]
    let averageConfidence: Float
    let colorPreferences: [String]
    let brandPreferences: [String]
}

struct StyleAdvice {
    let mainAdvice: String
    let supportingTips: [String]
    let reasoning: String
    let confidence: Float
}

struct OutfitFeedback {
    let positives: [String]
    let suggestions: [String]
    let overall: String
    let confidence: Float
}

struct StyleSuggestions {
    let primary: String
    let secondary: [String]
    let context: String
    let reasoning: String
    let confidence: Float
}

struct ColorAnalysis {
    let characteristics: String
    let suggestions: [String]
    let season: String?
    let confidence: Float
}

// MARK: - Helper Classes

class IntentAnalyzer {
    func analyze(message: ChatMessage, context: ConversationContext) async -> UserIntent {
        // Simplified intent analysis - in practice, this would use ML models
        guard case .text(let text) = message.content else {
            return .general
        }
        
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("what should i") || lowercasedText.contains("help me") {
            return .askingForAdvice
        } else if lowercasedText.contains("how does this look") || lowercasedText.contains("what do you think") {
            return .showingOutfit
        } else if lowercasedText.contains("suggest") || lowercasedText.contains("recommend") {
            return .requestingSuggestion
        } else if lowercasedText.contains("?") {
            return .askingQuestion
        } else if lowercasedText.contains("feel") || lowercasedText.contains("love") || lowercasedText.contains("hate") {
            return .expressing
        }
        
        return .general
    }
}

class ContextAnalyzer {
    func analyzeContext(_ context: ConversationContext) -> ContextInsights {
        return ContextInsights(
            dominantTopics: Array(context.topics.suffix(5).flatMap { $0 }.prefix(3)),
            recentActivity: context.lastActivity,
            engagementLevel: determineEngagement(context),
            stylePatterns: extractStylePatterns(context)
        )
    }
    
    private func determineEngagement(_ context: ConversationContext) -> Float {
        let recentMessages = min(context.messageCount, 10)
        return Float(recentMessages) / 10.0
    }
    
    private func extractStylePatterns(_ context: ConversationContext) -> [String] {
        return context.stylePreferences.suffix(3).map { $0 }
    }
}

struct ContextInsights {
    let dominantTopics: [String]
    let recentActivity: Date
    let engagementLevel: Float
    let stylePatterns: [String]
}

class StyleAnalyzer {
    func analyzeOutfitImage(_ imageData: Data) async -> StyleAnalysisResult {
        // Placeholder for image analysis - would integrate with vision APIs
        return StyleAnalysisResult(
            dominantColors: ["blue", "white"],
            style: "casual",
            occasion: "everyday",
            confidence: 0.75,
            recommendations: ["Add a statement accessory", "Try layering"]
        )
    }
    
    func generateAdvice(query: String, styleProfile: StyleProfile, persona: AIPersona) async -> StyleAdvice {
        return StyleAdvice(
            mainAdvice: "Based on your style, I'd suggest trying a more structured approach",
            supportingTips: ["Focus on fit", "Choose quality fabrics", "Add one statement piece"],
            reasoning: "This aligns with your preference for \(styleProfile.preferredStyles.first ?? "classic") styles",
            confidence: 0.8
        )
    }
    
    func generateOutfitFeedback(description: String, styleProfile: StyleProfile, persona: AIPersona) async -> OutfitFeedback {
        return OutfitFeedback(
            positives: ["Great color choice", "Perfect fit"],
            suggestions: ["Try a different shoe", "Add a belt"],
            overall: "This outfit works well for your style goals",
            confidence: 0.85
        )
    }
    
    func generateSuggestions(request: String, styleProfile: StyleProfile, context: ConversationContext, persona: AIPersona) async -> StyleSuggestions {
        return StyleSuggestions(
            primary: "A midi dress in a jewel tone",
            secondary: ["Statement earrings", "Block heel sandals", "Structured blazer"],
            context: "Perfect for your upcoming events",
            reasoning: "Based on your style preferences and recent conversations",
            confidence: 0.9
        )
    }
    
    func analyzeColor(_ color: Color, in styleProfile: StyleProfile) async -> ColorAnalysis {
        return ColorAnalysis(
            characteristics: "brings warmth and energy to your palette",
            suggestions: ["navy blue", "cream", "gold accents"],
            season: "autumn",
            confidence: 0.8
        )
    }
}

struct StyleAnalysisResult {
    let dominantColors: [String]
    let style: String
    let occasion: String
    let confidence: Float
    let recommendations: [String]
}

class EmpatheticResponseGenerator {
    func generateResponse(userExpression: String, persona: AIPersona, mood: UserMood) async -> String {
        let responses = getEmpatheticResponses(for: persona, mood: mood)
        return responses.randomElement() ?? "I understand how you're feeling."
    }
    
    private func getEmpatheticResponses(for persona: AIPersona, mood: UserMood) -> [String] {
        switch (persona.personality, mood) {
        case (.friendly, .positive):
            return ["I'm so happy for you! 😊", "That's wonderful news!", "I love your enthusiasm!"]
        case (.friendly, .negative):
            return ["I'm sorry you're feeling this way 💕", "It's okay to feel frustrated sometimes", "I'm here for you"]
        case (.professional, .seeking):
            return ["I understand your concerns", "Let me help you work through this", "That's a valid point"]
        default:
            return ["I hear you", "Thank you for sharing that with me", "I appreciate your honesty"]
        }
    }
}

class LearningEngine {
    func recordInteraction(
        userMessage: String,
        aiResponse: String,
        persona: AIPersona,
        context: ConversationContext
    ) async {
        // Record interaction for learning - in practice, this would update ML models
        print("Learning from interaction: \(userMessage.prefix(20))... -> \(aiResponse.prefix(20))...")
    }
}

class ResponseGenerator {
    func generateContextualResponse(
        intent: UserIntent,
        persona: AIPersona,
        context: ConversationContext
    ) async -> String {
        // Generate responses based on complex context analysis
        return "This is a contextually generated response based on \(intent.type)"
    }
}