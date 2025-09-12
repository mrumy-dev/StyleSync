import Foundation
import SwiftUI

// MARK: - Chat Message Models
struct ChatMessage: Identifiable, Codable, Hashable {
    let id = UUID()
    let content: MessageContent
    let sender: MessageSender
    let timestamp: Date
    var status: MessageStatus
    var reactions: [MessageReaction]
    var threadId: UUID?
    var replyTo: UUID?
    
    init(
        content: MessageContent,
        sender: MessageSender,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        reactions: [MessageReaction] = [],
        threadId: UUID? = nil,
        replyTo: UUID? = nil
    ) {
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.status = status
        self.reactions = reactions
        self.threadId = threadId
        self.replyTo = replyTo
    }
}

// MARK: - Message Content
enum MessageContent: Codable, Hashable {
    case text(String)
    case voice(VoiceMessage)
    case image(ImageMessage)
    case outfit(OutfitMessage)
    case sketch(SketchMessage)
    case color(ColorMessage)
    case suggestion(SuggestionMessage)
    case analysis(AnalysisMessage)
    
    var displayText: String {
        switch self {
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
        case .suggestion:
            return "💡 Suggestion"
        case .analysis:
            return "🔍 Analysis"
        }
    }
}

// MARK: - Message Sender
enum MessageSender: Codable, Hashable {
    case user
    case ai(persona: AIPersona)
    
    var isAI: Bool {
        switch self {
        case .user: return false
        case .ai: return true
        }
    }
    
    var displayName: String {
        switch self {
        case .user: return "You"
        case .ai(let persona): return persona.name
        }
    }
    
    var avatar: String {
        switch self {
        case .user: return "person.circle.fill"
        case .ai(let persona): return persona.avatar
        }
    }
}

// MARK: - Message Status
enum MessageStatus: Codable, Hashable {
    case sending
    case sent
    case delivered
    case read
    case failed
    
    var icon: String {
        switch self {
        case .sending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Message Reaction
struct MessageReaction: Identifiable, Codable, Hashable {
    let id = UUID()
    let emoji: String
    let sender: MessageSender
    let timestamp: Date
    
    static let available = ["❤️", "👍", "👎", "😂", "😮", "😢", "🔥", "💯", "👗", "✨"]
}

// MARK: - Specialized Message Types
struct VoiceMessage: Codable, Hashable {
    let audioURL: URL
    let duration: TimeInterval
    let waveform: [Float]
    let transcription: String?
    let isTranscribing: Bool
}

struct ImageMessage: Codable, Hashable {
    let imageData: Data
    let caption: String?
    let isOutfit: Bool
    let analysisResults: VisualAnalysisResult?
}

struct OutfitMessage: Codable, Hashable {
    let items: [OutfitItem]
    let style: String
    let occasion: String
    let confidence: Float
}

struct SketchMessage: Codable, Hashable {
    let drawingData: Data
    let strokes: [DrawingStroke]
    let description: String?
}

struct ColorMessage: Codable, Hashable {
    let color: CodableColor
    let colorName: String
    let season: ColorSeason?
    let suggestions: [String]
}

struct SuggestionMessage: Codable, Hashable {
    let title: String
    let description: String
    let actionType: SuggestionAction
    let confidence: Float
    let attachedItems: [String]
}

struct AnalysisMessage: Codable, Hashable {
    let analysisType: AnalysisType
    let results: [AnalysisResult]
    let confidence: Float
    let recommendations: [String]
}

// MARK: - AI Persona System
struct AIPersona: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let avatar: String
    let personality: PersonalityType
    let expertise: [ExpertiseArea]
    let communicationStyle: CommunicationStyle
    let responsePatterns: ResponsePattern
    
    static let available: [AIPersona] = [
        AIPersona(
            name: "Sophia",
            avatar: "person.crop.circle.badge.checkmark",
            personality: .friendly,
            expertise: [.styling, .colors, .trends],
            communicationStyle: .casual,
            responsePatterns: .encouraging
        ),
        AIPersona(
            name: "Alexander",
            avatar: "person.crop.circle.badge.clock",
            personality: .professional,
            expertise: [.formalWear, .business, .luxury],
            communicationStyle: .formal,
            responsePatterns: .detailed
        ),
        AIPersona(
            name: "Maya",
            avatar: "person.crop.circle.badge.plus",
            personality: .creative,
            expertise: [.artistic, .experimental, .vintage],
            communicationStyle: .enthusiastic,
            responsePatterns: .innovative
        )
    ]
}

// MARK: - Supporting Enums
enum PersonalityType: String, Codable, CaseIterable {
    case friendly = "friendly"
    case professional = "professional"
    case creative = "creative"
    case casual = "casual"
    case expert = "expert"
}

enum ExpertiseArea: String, Codable, CaseIterable {
    case styling = "styling"
    case colors = "colors"
    case trends = "trends"
    case formalWear = "formalWear"
    case business = "business"
    case luxury = "luxury"
    case artistic = "artistic"
    case experimental = "experimental"
    case vintage = "vintage"
    case bodyType = "bodyType"
    case seasons = "seasons"
}

enum CommunicationStyle: String, Codable, CaseIterable {
    case casual = "casual"
    case formal = "formal"
    case enthusiastic = "enthusiastic"
    case direct = "direct"
    case supportive = "supportive"
}

enum ResponsePattern: String, Codable, CaseIterable {
    case encouraging = "encouraging"
    case detailed = "detailed"
    case innovative = "innovative"
    case practical = "practical"
    case analytical = "analytical"
}

enum SuggestionAction: String, Codable, CaseIterable {
    case tryOutfit = "tryOutfit"
    case shopItem = "shopItem"
    case saveStyle = "saveStyle"
    case scheduleReminder = "scheduleReminder"
    case analyzeMore = "analyzeMore"
}

enum AnalysisType: String, Codable, CaseIterable {
    case bodyShape = "bodyShape"
    case colorSeason = "colorSeason"
    case stylePersonality = "stylePersonality"
    case outfitFeedback = "outfitFeedback"
    case wardrobe = "wardrobe"
}

struct AnalysisResult: Codable, Hashable {
    let category: String
    let score: Float
    let description: String
    let recommendations: [String]
}

struct VisualAnalysisResult: Codable, Hashable {
    let bodyShape: String?
    let colorSeason: String?
    let styleNotes: [String]
    let confidence: Float
}

// MARK: - Chat Session
struct ChatSession: Identifiable, Codable {
    let id = UUID()
    var messages: [ChatMessage]
    var participants: [MessageSender]
    let createdAt: Date
    var lastActivity: Date
    var title: String
    var isArchived: Bool
    var settings: ChatSettings
    
    init(
        participants: [MessageSender] = [.user, .ai(persona: AIPersona.available[0])],
        title: String = "Style Chat",
        settings: ChatSettings = ChatSettings()
    ) {
        self.messages = []
        self.participants = participants
        self.createdAt = Date()
        self.lastActivity = Date()
        self.title = title
        self.isArchived = false
        self.settings = settings
    }
}

struct ChatSettings: Codable {
    var isEncrypted: Bool = true
    var autoDeleteAfterDays: Int? = nil
    var enableReadReceipts: Bool = true
    var enableTypingIndicators: Bool = true
    var enableSounds: Bool = true
    var enableVibration: Bool = true
    var blurImagesBeforeSending: Bool = true
    var enableLocalProcessing: Bool = true
    var currentPersona: AIPersona = AIPersona.available[0]
}

// MARK: - Helper Extensions
extension CodableColor: Codable, Hashable {
    struct CodableColor {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        
        var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }
        
        init(color: Color) {
            // Note: This is a simplified implementation
            // In practice, you'd need proper color space conversion
            self.red = 0.5
            self.green = 0.5 
            self.blue = 0.5
            self.alpha = 1.0
        }
    }
}

enum ColorSeason: String, Codable, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
}

struct OutfitItem: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    let color: CodableColor
    let brand: String?
    let price: Double?
    let imageURL: URL?
}

struct DrawingStroke: Codable, Hashable {
    let points: [CGPoint]
    let color: CodableColor
    let width: CGFloat
    let timestamp: Date
}

// MARK: - CGPoint Codable Extension
extension CGPoint: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    private enum CodingKeys: String, CodingKey {
        case x, y
    }
}