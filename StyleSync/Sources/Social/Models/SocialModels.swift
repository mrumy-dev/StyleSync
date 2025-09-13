import Foundation
import SwiftUI
import CoreData

// MARK: - User Profile Models
struct UserProfile: Identifiable, Codable {
    let id = UUID()
    var anonymousID: String
    var displayName: String
    var username: String
    var bio: String
    var profileImageData: Data?
    var coverImageData: Data?
    var verificationStatus: VerificationStatus
    var followerCount: Int = 0
    var followingCount: Int = 0
    var postCount: Int = 0
    var isPrivateAccount: Bool = false
    var isVerifiedStylist: Bool = false
    var styleMoodBoard: StyleMoodBoard?
    var achievements: [Achievement] = []
    var settings: ProfileSettings
    var createdAt: Date = Date()
    var lastActive: Date = Date()

    // Privacy settings
    var closeFriends: Set<String> = []
    var blockedUsers: Set<String> = []
    var restrictedUsers: Set<String> = []
}

struct StyleMoodBoard: Codable {
    var colors: [StyleColor] = []
    var styles: [StyleTag] = []
    var inspirations: [String] = []
    var preferredBrands: [String] = []
    var bodyType: BodyType?
    var colorSeason: ColorSeason?
    var stylePersonality: StylePersonality?
}

struct Achievement: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let unlockedAt: Date
    let category: AchievementCategory
    let rarity: AchievementRarity
}

enum VerificationStatus: String, Codable, CaseIterable {
    case unverified = "unverified"
    case verified = "verified"
    case stylistVerified = "stylist_verified"
    case brandVerified = "brand_verified"

    var badgeIcon: String {
        switch self {
        case .unverified: return ""
        case .verified: return "checkmark.seal.fill"
        case .stylistVerified: return "scissors.badge.checkmark"
        case .brandVerified: return "building.2.crop.circle.badge.checkmark"
        }
    }

    var badgeColor: Color {
        switch self {
        case .unverified: return .clear
        case .verified: return .blue
        case .stylistVerified: return .purple
        case .brandVerified: return .gold
        }
    }
}

// MARK: - Social Feed Models
struct SocialPost: Identifiable, Codable {
    let id = UUID()
    let authorID: String
    var content: PostContent
    var caption: String
    var hashtags: [String] = []
    var mentions: [String] = []
    var location: PostLocation?
    var visibility: PostVisibility = .public
    var isCloseFriendsOnly: Bool = false
    var allowComments: Bool = true
    var allowRemix: Bool = true
    var allowSaving: Bool = true
    var likeCount: Int = 0
    var commentCount: Int = 0
    var shareCount: Int = 0
    var saveCount: Int = 0
    var viewCount: Int = 0
    var createdAt: Date = Date()
    var editedAt: Date?
    var isSponsored: Bool = false
    var sponsorInfo: SponsorInfo?
}

enum PostContent: Codable {
    case photo(PhotoPost)
    case video(VideoPost)
    case outfit(OutfitPost)
    case story(StoryPost)
    case reel(ReelPost)
    case beforeAfter(TransformationPost)
    case challenge(ChallengePost)
    case poll(PollPost)
    case collaboration(CollaborationPost)
}

struct PhotoPost: Codable {
    let imageData: [Data]
    let filters: [PhotoFilter]
    let layout: LayoutTemplate?
    let aspectRatio: CGFloat
    let editingData: EditingMetadata?
}

struct VideoPost: Codable {
    let videoURL: URL
    let thumbnailData: Data
    let duration: TimeInterval
    let effects: [VideoEffect]
    let musicTrack: MusicTrack?
    let transitions: [VideoTransition]
    let isBoomerang: Bool = false
    let isTimelapse: Bool = false
}

struct OutfitPost: Codable {
    let items: [OutfitItem]
    let style: StyleCategory
    let occasion: String
    let season: Season
    let bodyType: BodyType?
    let priceRange: PriceRange?
    let shoppableLinks: [ShoppableLink]
    let confidence: Float
}

struct StoryPost: Codable {
    let content: StoryContent
    let duration: TimeInterval
    let backgroundColor: CodableColor
    let stickers: [StorySticker]
    let music: MusicTrack?
    let viewersList: [String] = []
    let expiresAt: Date
}

struct ReelPost: Codable {
    let videoURL: URL
    let effects: [ReelEffect]
    let music: MusicTrack
    let captions: [Caption]
    let trending: Bool = false
    let challengeTag: String?
}

struct TransformationPost: Codable {
    let beforeImages: [Data]
    let afterImages: [Data]
    let transformationType: TransformationType
    let timespan: String
    let tips: [String]
    let productsUsed: [ProductReference]
}

// MARK: - Interaction Models
struct SocialInteraction: Identifiable, Codable {
    let id = UUID()
    let type: InteractionType
    let userID: String
    let postID: UUID
    let timestamp: Date = Date()
    var metadata: InteractionMetadata?
}

enum InteractionType: String, Codable, CaseIterable {
    case like = "like"
    case doubleTabLike = "double_tap_like"
    case save = "save"
    case share = "share"
    case comment = "comment"
    case reply = "reply"
    case mention = "mention"
    case follow = "follow"
    case unfollow = "unfollow"
    case block = "block"
    case report = "report"
    case remix = "remix"
    case collaborate = "collaborate"
    case vote = "vote"
    case react = "react"
}

struct Comment: Identifiable, Codable {
    let id = UUID()
    let postID: UUID
    let authorID: String
    var content: String
    var mentions: [String] = []
    var likeCount: Int = 0
    var replyCount: Int = 0
    var replies: [Comment] = []
    let createdAt: Date = Date()
    var editedAt: Date?
    var isDeleted: Bool = false
    var isPinned: Bool = false
    var suggestions: [OutfitSuggestion] = []
}

struct OutfitSuggestion: Identifiable, Codable {
    let id = UUID()
    let items: [OutfitItem]
    let reasoning: String
    let confidence: Float
    let authorID: String
    let likeCount: Int = 0
}

// MARK: - Direct Messaging Models
struct DirectMessage: Identifiable, Codable {
    let id = UUID()
    let conversationID: UUID
    let senderID: String
    let content: MessageContent
    var reactions: [MessageReaction] = []
    let timestamp: Date = Date()
    var status: MessageStatus = .sent
    var isDeleted: Bool = false
    var expiresAt: Date?
}

struct Conversation: Identifiable, Codable {
    let id = UUID()
    var participants: [String]
    var messages: [DirectMessage] = []
    var lastMessage: DirectMessage?
    var isGroupChat: Bool = false
    var groupName: String?
    var groupImageData: Data?
    var adminIDs: Set<String> = []
    var settings: ConversationSettings
    let createdAt: Date = Date()
    var lastActivity: Date = Date()
    var isArchived: Bool = false
    var isMuted: Bool = false
}

// MARK: - Content Creation Models
struct ContentTemplate: Identifiable, Codable {
    let id = UUID()
    let name: String
    let category: TemplateCategory
    let layout: LayoutData
    let filters: [PhotoFilter]
    let effects: [Effect]
    let isPremium: Bool = false
    let usageCount: Int = 0
    let rating: Float = 0.0
}

struct PhotoFilter: Identifiable, Codable {
    let id = UUID()
    let name: String
    let intensity: Float
    let parameters: [String: Any]
    let category: FilterCategory
    let isPremium: Bool = false
    let price: Double?
    let previewImageData: Data?

    init(id: UUID = UUID(), name: String, intensity: Float, parameters: [String: Any], category: FilterCategory, isPremium: Bool = false, price: Double? = nil, previewImageData: Data? = nil) {
        self.id = id
        self.name = name
        self.intensity = intensity
        self.parameters = [:]
        self.category = category
        self.isPremium = isPremium
        self.price = price
        self.previewImageData = previewImageData
    }
}

struct StickerPack: Identifiable, Codable {
    let id = UUID()
    let name: String
    let stickers: [Sticker]
    let category: StickerCategory
    let isPremium: Bool = false
    let price: Double?
    let creatorID: String?
}

struct Sticker: Identifiable, Codable {
    let id = UUID()
    let imageData: Data
    let isAnimated: Bool = false
    let animationData: Data?
    let tags: [String]
}

// MARK: - Discovery & Matching Models
struct StyleDNA: Codable {
    let userID: String
    var colorPreferences: [StyleColor]
    var styleCategories: [StyleCategory]
    var bodyType: BodyType?
    var preferredFit: FitPreference?
    var budgetRange: PriceRange?
    var brandAffinities: [String]
    var seasonalPreferences: [Season]
    var lifestyleFactors: [LifestyleFactor]
    var confidenceMetrics: ConfidenceMetrics
    var lastUpdated: Date = Date()
}

struct SimilarUser: Identifiable, Codable {
    let id = UUID()
    let userID: String
    let similarityScore: Float
    let sharedInterests: [String]
    let matchingFactors: [MatchingFactor]
    let discoveredAt: Date = Date()
}

struct TrendingContent: Identifiable, Codable {
    let id = UUID()
    let contentID: UUID
    let trendingScore: Float
    let category: TrendingCategory
    let location: String?
    val hashtags: [String]
    let demographics: Demographics?
    let timeframe: TrendingTimeframe
}

// MARK: - Privacy & Safety Models
struct SafetyReport: Identifiable, Codable {
    let id = UUID()
    let reporterID: String
    let reportedContent: ReportedContent
    let reason: ReportReason
    let description: String?
    let evidence: [Data]
    let status: ReportStatus = .pending
    let createdAt: Date = Date()
    var reviewedAt: Date?
    var reviewerID: String?
    var resolution: String?
}

struct ContentModerationResult: Codable {
    let contentID: UUID
    let isApproved: Bool
    let flaggedReasons: [ModerationFlag]
    let confidenceScore: Float
    let reviewRequired: Bool
    let restrictedRegions: [String]
    let ageRestriction: AgeRestriction?
}

// MARK: - Supporting Enums & Types
enum PostVisibility: String, Codable, CaseIterable {
    case public = "public"
    case followers = "followers"
    case closeFriends = "close_friends"
    case private = "private"
    case unlisted = "unlisted"
}

enum StyleCategory: String, Codable, CaseIterable {
    case casual = "casual"
    case formal = "formal"
    case business = "business"
    case evening = "evening"
    case athleisure = "athleisure"
    case vintage = "vintage"
    case bohemian = "bohemian"
    case minimalist = "minimalist"
    case maximalist = "maximalist"
    case streetwear = "streetwear"
    case preppy = "preppy"
    case gothic = "gothic"
    case romantic = "romantic"
    case edgy = "edgy"
}

enum Season: String, Codable, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"
    case allSeason = "all_season"
}

enum BodyType: String, Codable, CaseIterable {
    case hourglass = "hourglass"
    case pear = "pear"
    case apple = "apple"
    case rectangle = "rectangle"
    case invertedTriangle = "inverted_triangle"
    case athletic = "athletic"
    case petite = "petite"
    case tall = "tall"
    case plus = "plus"
}

enum AchievementCategory: String, Codable, CaseIterable {
    case styling = "styling"
    case social = "social"
    case engagement = "engagement"
    case creativity = "creativity"
    case consistency = "consistency"
    case trendsetting = "trendsetting"
}

enum AchievementRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
}

enum ReportReason: String, Codable, CaseIterable {
    case inappropriateContent = "inappropriate_content"
    case harassment = "harassment"
    case spam = "spam"
    case falseMisleading = "false_misleading"
    case copyrightViolation = "copyright_violation"
    case hateSpeech = "hate_speech"
    case violence = "violence"
    case nudity = "nudity"
    case selfHarm = "self_harm"
    case other = "other"
}

enum ReportStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case reviewing = "reviewing"
    case resolved = "resolved"
    case dismissed = "dismissed"
    case escalated = "escalated"
}

// MARK: - Settings & Configurations
struct ProfileSettings: Codable {
    var isPrivate: Bool = false
    var showActivityStatus: Bool = true
    var allowTagging: Bool = true
    var allowMentions: Bool = true
    var allowDirectMessages: Bool = true
    var allowPhotoDownloads: Bool = false
    var showFollowerCount: Bool = true
    var showFollowingCount: Bool = true
    var showPostCount: Bool = true
    var contentLanguage: String = "en"
    var timeZone: String = TimeZone.current.identifier
    var notificationSettings: NotificationSettings = NotificationSettings()
    var privacySettings: SocialPrivacySettings = SocialPrivacySettings()
}

struct NotificationSettings: Codable {
    var likes: Bool = true
    var comments: Bool = true
    var mentions: Bool = true
    var followers: Bool = true
    var directMessages: Bool = true
    var challenges: Bool = true
    var trends: Bool = false
    var marketingEmails: Bool = false
    var weeklyDigest: Bool = true
}

struct SocialPrivacySettings: Codable {
    var hideLikedPosts: Bool = false
    var hideFollowerList: Bool = false
    var hideFollowingList: Bool = false
    var allowStoryScreenshots: Bool = false
    var allowStoryResharing: Bool = true
    var restrictComments: CommentRestriction = .none
    var restrictDirectMessages: DMRestriction = .none
    var blockedWords: [String] = []
    var sensitiveContentWarning: Bool = true
}

enum CommentRestriction: String, Codable, CaseIterable {
    case none = "none"
    case followersOnly = "followers_only"
    case mutualFollowersOnly = "mutual_followers_only"
    case off = "off"
}

enum DMRestriction: String, Codable, CaseIterable {
    case everyone = "everyone"
    case followersOnly = "followers_only"
    case mutualFollowersOnly = "mutual_followers_only"
    case contactsOnly = "contacts_only"
    case off = "off"
}

// MARK: - Additional Supporting Types
struct PostLocation: Codable {
    let name: String
    let coordinates: CLLocationCoordinate2D?
    let city: String?
    let country: String?
}

struct SponsorInfo: Codable {
    let brandName: String
    let brandID: String
    let campaignID: String
    let disclosureText: String
    let isPaidPartnership: Bool
}

struct MusicTrack: Codable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let genre: String?
}

struct ShoppableLink: Identifiable, Codable {
    let id = UUID()
    let productName: String
    let brand: String
    let price: Double
    let currency: String
    let url: URL
    let imageData: Data?
    let category: String
}

struct Caption: Codable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let style: CaptionStyle
}

struct CaptionStyle: Codable {
    let fontName: String
    let fontSize: CGFloat
    let color: CodableColor
    let backgroundColor: CodableColor
    let animation: CaptionAnimation?
}

enum CaptionAnimation: String, Codable, CaseIterable {
    case none = "none"
    case fadeIn = "fade_in"
    case slideUp = "slide_up"
    case typewriter = "typewriter"
    case bounce = "bounce"
}

// MARK: - Core Data Extensions
extension UserProfile {
    func toManagedObject(context: NSManagedObjectContext) -> NSManagedObject {
        // Core Data implementation would go here
        return NSManagedObject()
    }
}

extension SocialPost {
    func toManagedObject(context: NSManagedObjectContext) -> NSManagedObject {
        // Core Data implementation would go here
        return NSManagedObject()
    }
}

// MARK: - Color Extensions
extension Color {
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.0)
}

// MARK: - CLLocationCoordinate2D Codable Extension
extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}