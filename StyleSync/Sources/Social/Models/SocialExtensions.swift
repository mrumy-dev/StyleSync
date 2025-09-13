import Foundation
import SwiftUI
import CoreLocation

// MARK: - Missing Type Definitions
struct StyleColor: Codable, Identifiable {
    let id = UUID()
    let name: String
    let hexValue: String
    let rgbValues: (red: Double, green: Double, blue: Double)
    let season: ColorSeason?
    let mood: ColorMood

    var color: Color {
        Color(red: rgbValues.red, green: rgbValues.green, blue: rgbValues.blue)
    }

    enum ColorMood: String, Codable, CaseIterable {
        case energetic = "energetic"
        case calm = "calm"
        case romantic = "romantic"
        case professional = "professional"
        case playful = "playful"
        case mysterious = "mysterious"
    }
}

struct StyleTag: Codable, Identifiable {
    let id = UUID()
    let name: String
    let category: StyleCategory
    let popularity: Float
    let isUserCreated: Bool = false
}

enum StylePersonality: String, Codable, CaseIterable {
    case classic = "classic"
    case trendy = "trendy"
    case bohemian = "bohemian"
    case edgy = "edgy"
    case romantic = "romantic"
    case minimalist = "minimalist"
    case maximalist = "maximalist"
    case athletic = "athletic"
    case creative = "creative"
    case professional = "professional"

    var description: String {
        switch self {
        case .classic: return "Timeless, elegant pieces that never go out of style"
        case .trendy: return "Always up-to-date with the latest fashion trends"
        case .bohemian: return "Free-spirited, artistic, and unconventional style"
        case .edgy: return "Bold, daring, and fashion-forward choices"
        case .romantic: return "Feminine, soft, and dreamy aesthetic"
        case .minimalist: return "Clean, simple, and effortlessly chic"
        case .maximalist: return "More is more - bold patterns and vibrant colors"
        case .athletic: return "Sporty, comfortable, and performance-oriented"
        case .creative: return "Unique, experimental, and artistic expression"
        case .professional: return "Polished, sophisticated, and workplace-appropriate"
        }
    }
}

enum PriceRange: String, Codable, CaseIterable {
    case budget = "budget"          // $0-50
    case affordable = "affordable"  // $50-150
    case mid = "mid"               // $150-400
    case premium = "premium"        // $400-1000
    case luxury = "luxury"         // $1000+

    var displayName: String {
        switch self {
        case .budget: return "$0 - $50"
        case .affordable: return "$50 - $150"
        case .mid: return "$150 - $400"
        case .premium: return "$400 - $1,000"
        case .luxury: return "$1,000+"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .budget: return 0...50
        case .affordable: return 50...150
        case .mid: return 150...400
        case .premium: return 400...1000
        case .luxury: return 1000...Double.infinity
        }
    }
}

enum FitPreference: String, Codable, CaseIterable {
    case loose = "loose"
    case relaxed = "relaxed"
    case regular = "regular"
    case fitted = "fitted"
    case tight = "tight"
    case oversized = "oversized"
}

enum LifestyleFactor: String, Codable, CaseIterable {
    case workFromHome = "work_from_home"
    case officeJob = "office_job"
    case activeLifestyle = "active_lifestyle"
    case socialButterfly = "social_butterfly"
    case homebody = "homebody"
    case traveler = "traveler"
    case studentLife = "student_life"
    case parenthood = "parenthood"
    case nightlife = "nightlife"
    case minimalistLiving = "minimalist_living"
}

struct ConfidenceMetrics: Codable {
    var overallConfidence: Float
    var colorConfidence: Float
    var styleConfidence: Float
    var fitConfidence: Float
    var occasionConfidence: Float
    var trendConfidence: Float

    init() {
        self.overallConfidence = 0.5
        self.colorConfidence = 0.5
        self.styleConfidence = 0.5
        self.fitConfidence = 0.5
        self.occasionConfidence = 0.5
        self.trendConfidence = 0.5
    }
}

enum MatchingFactor: String, Codable, CaseIterable {
    case stylePersonality = "style_personality"
    case colorPreferences = "color_preferences"
    case bodyType = "body_type"
    case budgetRange = "budget_range"
    case brandAffinities = "brand_affinities"
    case lifestyleFactors = "lifestyle_factors"
    case ageGroup = "age_group"
    case location = "location"
    case interests = "interests"
}

enum TrendingCategory: String, Codable, CaseIterable {
    case outfits = "outfits"
    case styles = "styles"
    case colors = "colors"
    case brands = "brands"
    case hashtags = "hashtags"
    case challenges = "challenges"
    case occasions = "occasions"
    case transformations = "transformations"
}

struct Demographics: Codable {
    let ageRange: AgeRange?
    let location: String?
    let interests: [String]
    let spendingPower: PriceRange?
}

enum AgeRange: String, Codable, CaseIterable {
    case gen_z = "gen_z"         // 16-24
    case millennial = "millennial" // 25-40
    case gen_x = "gen_x"         // 41-56
    case boomer = "boomer"       // 57+

    var displayName: String {
        switch self {
        case .gen_z: return "Gen Z (16-24)"
        case .millennial: return "Millennial (25-40)"
        case .gen_x: return "Gen X (41-56)"
        case .boomer: return "Boomer (57+)"
        }
    }
}

enum TrendingTimeframe: String, Codable, CaseIterable {
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    case season = "season"
    case year = "year"
}

// MARK: - Content Creation Extensions
enum TemplateCategory: String, Codable, CaseIterable {
    case grid = "grid"
    case story = "story"
    case reel = "reel"
    case profile = "profile"
    case highlight = "highlight"
    case collage = "collage"
    case beforeAfter = "before_after"
    case lookbook = "lookbook"
}

struct LayoutData: Codable {
    let type: LayoutType
    let dimensions: CGSize
    let frames: [CGRect]
    let backgroundColor: CodableColor
    let borderStyle: BorderStyle?
}

enum LayoutType: String, Codable, CaseIterable {
    case single = "single"
    case grid2x2 = "grid_2x2"
    case grid3x3 = "grid_3x3"
    case collage = "collage"
    case carousel = "carousel"
    case splitScreen = "split_screen"
    case beforeAfter = "before_after"
}

struct BorderStyle: Codable {
    let width: CGFloat
    let color: CodableColor
    let cornerRadius: CGFloat
    let style: BorderLineStyle
}

enum BorderLineStyle: String, Codable, CaseIterable {
    case solid = "solid"
    case dashed = "dashed"
    case dotted = "dotted"
    case gradient = "gradient"
}

enum FilterCategory: String, Codable, CaseIterable {
    case vintage = "vintage"
    case modern = "modern"
    case dreamy = "dreamy"
    case vibrant = "vibrant"
    case minimal = "minimal"
    case dramatic = "dramatic"
    case natural = "natural"
    case artistic = "artistic"
}

enum StickerCategory: String, Codable, CaseIterable {
    case fashion = "fashion"
    case lifestyle = "lifestyle"
    case mood = "mood"
    case seasonal = "seasonal"
    case branded = "branded"
    case animated = "animated"
    case text = "text"
    case frames = "frames"
}

// MARK: - Video & Story Extensions
enum VideoEffect: String, Codable, CaseIterable {
    case slowMotion = "slow_motion"
    case fastForward = "fast_forward"
    case reverse = "reverse"
    case boomerang = "boomerang"
    case greenScreen = "green_screen"
    case beautyFilter = "beauty_filter"
    case colorGrading = "color_grading"
    case transitions = "transitions"
}

struct VideoTransition: Codable {
    let type: TransitionType
    let duration: TimeInterval
    let startTime: TimeInterval
}

enum TransitionType: String, Codable, CaseIterable {
    case fade = "fade"
    case slide = "slide"
    case zoom = "zoom"
    case spin = "spin"
    case blur = "blur"
    case wipe = "wipe"
}

enum StoryContent: Codable {
    case photo(Data)
    case video(URL)
    case text(StoryText)
    case outfit(OutfitStory)
    case poll(StoryPoll)
    case quiz(StoryQuiz)
    case countdown(StoryCountdown)
}

struct StoryText: Codable {
    let text: String
    let font: String
    let size: CGFloat
    let color: CodableColor
    let backgroundColor: CodableColor
    let alignment: TextAlignment
    let animation: TextAnimation?
}

enum TextAlignment: String, Codable, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"
}

enum TextAnimation: String, Codable, CaseIterable {
    case none = "none"
    case typewriter = "typewriter"
    case bounce = "bounce"
    case glow = "glow"
    case rainbow = "rainbow"
}

struct StorySticker: Identifiable, Codable {
    let id = UUID()
    let type: StickerType
    let position: CGPoint
    let rotation: Double
    let scale: Double
    let data: StickerData
}

enum StickerType: String, Codable, CaseIterable {
    case emoji = "emoji"
    case gif = "gif"
    case mention = "mention"
    case hashtag = "hashtag"
    case location = "location"
    case time = "time"
    case weather = "weather"
    case music = "music"
    case poll = "poll"
    case quiz = "quiz"
    case countdown = "countdown"
}

enum StickerData: Codable {
    case text(String)
    case image(Data)
    case poll(StoryPoll)
    case quiz(StoryQuiz)
    case countdown(StoryCountdown)
}

struct StoryPoll: Codable {
    let question: String
    let options: [String]
    var responses: [String: String] = [:]
    let allowMultipleChoices: Bool = false
}

struct StoryQuiz: Codable {
    let question: String
    let options: [String]
    let correctAnswer: Int
    var responses: [String: Int] = [:]
}

struct StoryCountdown: Codable {
    let title: String
    let targetDate: Date
    let completionMessage: String?
}

struct OutfitStory: Codable {
    let items: [OutfitItem]
    let transitionEffect: TransitionEffect
    let music: MusicTrack?
    let shoppableLinks: [ShoppableLink]
}

enum TransitionEffect: String, Codable, CaseIterable {
    case dissolve = "dissolve"
    case slide = "slide"
    case fade = "fade"
    case zoom = "zoom"
    case spin = "spin"
    case flip = "flip"
}

// MARK: - Specialized Post Types
enum TransformationType: String, Codable, CaseIterable {
    case weightLoss = "weight_loss"
    case styleEvolution = "style_evolution"
    case seasonalTransition = "seasonal_transition"
    case occasionChange = "occasion_change"
    case colorExperiment = "color_experiment"
    case fitImprovement = "fit_improvement"
    case confidenceJourney = "confidence_journey"
    case wardrobeOverhaul = "wardrobe_overhaul"
}

struct ProductReference: Identifiable, Codable {
    let id = UUID()
    let name: String
    let brand: String
    let category: String
    let price: Double?
    let affiliate: Bool = false
    let link: URL?
}

struct ChallengePost: Codable {
    let challengeID: String
    let challengeName: String
    let participationData: ChallengeParticipation
    let submissionDeadline: Date?
    let rules: [String]
    let prizes: [Prize]?
}

struct ChallengeParticipation: Codable {
    let participantCount: Int
    let trending: Bool
    let difficulty: ChallengeDifficulty
    let estimatedTime: TimeInterval?
}

enum ChallengeDifficulty: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
}

struct Prize: Codable {
    let name: String
    let description: String
    let value: Double?
    let sponsor: String?
    let imageData: Data?
}

struct PollPost: Codable {
    let question: String
    let options: [PollOption]
    let allowMultipleChoices: Bool = false
    let expiresAt: Date?
    var totalVotes: Int = 0
    let isAnonymous: Bool = true
}

struct PollOption: Identifiable, Codable {
    let id = UUID()
    let text: String
    let imageData: Data?
    var voteCount: Int = 0
    let voters: Set<String> = []
}

struct CollaborationPost: Codable {
    let collaborators: [String]
    let contributionType: CollaborationType
    let splitType: SplitType
    let permissions: CollaborationPermissions
}

enum CollaborationType: String, Codable, CaseIterable {
    case jointOutfit = "joint_outfit"
    case styleChallenge = "style_challenge"
    case brandPartnership = "brand_partnership"
    case tutorial = "tutorial"
    case comparison = "comparison"
    case duet = "duet"
}

enum SplitType: String, Codable, CaseIterable {
    case equal = "equal"
    case weighted = "weighted"
    case lead = "lead"
    case feature = "feature"
}

struct CollaborationPermissions: Codable {
    let canEdit: Bool
    let canDelete: Bool
    let canPromote: Bool
    let canAddCollaborators: Bool
    let canManageComments: Bool
}

// MARK: - Reel & Advanced Video
enum ReelEffect: String, Codable, CaseIterable {
    case transition = "transition"
    case outfit_change = "outfit_change"
    case before_after = "before_after"
    case speed_ramp = "speed_ramp"
    case color_pop = "color_pop"
    case mirror = "mirror"
    case split_screen = "split_screen"
    case green_screen = "green_screen"
    case ar_try_on = "ar_try_on"
}

// MARK: - Safety & Moderation
enum ReportedContent: Codable {
    case post(UUID)
    case comment(UUID)
    case user(String)
    case message(UUID)
    case story(UUID)
}

enum ModerationFlag: String, Codable, CaseIterable {
    case nudity = "nudity"
    case violence = "violence"
    case harassment = "harassment"
    case spam = "spam"
    case misinformation = "misinformation"
    case copyrightViolation = "copyright_violation"
    case hateSpeech = "hate_speech"
    case underage = "underage"
    case dangerousActs = "dangerous_acts"
    case fraudScam = "fraud_scam"
}

enum AgeRestriction: String, Codable, CaseIterable {
    case none = "none"
    case thirteen_plus = "13+"
    case sixteen_plus = "16+"
    case eighteen_plus = "18+"
}

// MARK: - Messaging Extensions
struct ConversationSettings: Codable {
    var allowMedia: Bool = true
    var allowVoiceMessages: Bool = true
    var allowStickers: Bool = true
    var allowGifs: Bool = true
    var enableReadReceipts: Bool = true
    var enableTypingIndicators: Bool = true
    var autoDeleteMessages: Bool = false
    var deleteAfterDays: Int = 30
    var isEncrypted: Bool = true
    var allowScreenshots: Bool = false
    var allowForwarding: Bool = true
}

struct InteractionMetadata: Codable {
    let location: CLLocationCoordinate2D?
    let duration: TimeInterval?
    let intensity: Float?
    let additionalData: [String: Any]

    init(location: CLLocationCoordinate2D? = nil, duration: TimeInterval? = nil, intensity: Float? = nil, additionalData: [String: Any] = [:]) {
        self.location = location
        self.duration = duration
        self.intensity = intensity
        self.additionalData = [:]
    }
}

// MARK: - Effect System
protocol Effect: Codable {
    var name: String { get }
    var intensity: Float { get set }
    var parameters: [String: Any] { get }
    var isRealTime: Bool { get }
}

struct StandardEffect: Effect, Identifiable {
    let id = UUID()
    let name: String
    var intensity: Float
    let parameters: [String: Any]
    let isRealTime: Bool

    init(name: String, intensity: Float = 1.0, parameters: [String: Any] = [:], isRealTime: Bool = false) {
        self.name = name
        self.intensity = intensity
        self.parameters = [:]
        self.isRealTime = isRealTime
    }
}

// MARK: - Editing Metadata
struct EditingMetadata: Codable {
    let originalImageData: Data?
    let editingSteps: [EditingStep]
    let totalEditingTime: TimeInterval
    let filtersApplied: [PhotoFilter]
    let adjustments: ImageAdjustments
}

struct EditingStep: Codable {
    let action: EditingAction
    let parameters: [String: Any]
    let timestamp: Date

    init(action: EditingAction, parameters: [String: Any] = [:]) {
        self.action = action
        self.parameters = [:]
        self.timestamp = Date()
    }
}

enum EditingAction: String, Codable, CaseIterable {
    case crop = "crop"
    case rotate = "rotate"
    case flip = "flip"
    case adjust_brightness = "adjust_brightness"
    case adjust_contrast = "adjust_contrast"
    case adjust_saturation = "adjust_saturation"
    case apply_filter = "apply_filter"
    case add_text = "add_text"
    case add_sticker = "add_sticker"
    case blur_background = "blur_background"
    case remove_object = "remove_object"
}

struct ImageAdjustments: Codable {
    var brightness: Float = 0
    var contrast: Float = 0
    var saturation: Float = 0
    var warmth: Float = 0
    var highlights: Float = 0
    var shadows: Float = 0
    var vignette: Float = 0
    var sharpness: Float = 0
    var clarity: Float = 0
}