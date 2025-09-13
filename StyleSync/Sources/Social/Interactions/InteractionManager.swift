import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - Interaction Manager
@MainActor
final class InteractionManager: ObservableObject {
    static let shared = InteractionManager()

    // MARK: - Published Properties
    @Published var recentInteractions: [SocialInteraction] = []
    @Published var isProcessingInteraction = false
    @Published var interactionError: InteractionError?
    @Published var unreadNotifications: Int = 0

    // MARK: - Private Properties
    private let privacyManager = PrivacyControlsManager.shared
    private let profileManager = ProfileManager.shared
    private let hapticManager = HapticFeedbackManager()
    private let soundManager = SoundDesignManager()
    private let cryptoEngine = CryptoEngine.shared
    private let storageManager = SandboxedStorageManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Local Storage
    private var likedPosts: Set<UUID> = []
    private var savedPosts: Set<UUID> = []
    private var followedUsers: Set<String> = []
    private var blockedUsers: Set<String> = []

    // MARK: - Constants
    private enum Constants {
        static let interactionsCacheKey = "interactions_cache"
        static let likedPostsKey = "liked_posts"
        static let savedPostsKey = "saved_posts"
        static let followedUsersKey = "followed_users"
        static let maxInteractionsCache = 1000
        static let interactionTimeout: TimeInterval = 5.0
    }

    private init() {
        setupInteractionMonitoring()
        loadCachedData()
    }

    // MARK: - Like Interactions
    func likePost(_ postId: UUID, type: InteractionType = .like) {
        guard !likedPosts.contains(postId) else { return }

        Task {
            await processLikeInteraction(postId: postId, type: type)
        }
    }

    func unlikePost(_ postId: UUID) {
        guard likedPosts.contains(postId) else { return }

        Task {
            await processUnlikeInteraction(postId: postId)
        }
    }

    private func processLikeInteraction(postId: UUID, type: InteractionType) async {
        isProcessingInteraction = true

        do {
            // Create interaction
            let interaction = SocialInteraction(
                type: type,
                userID: await getCurrentUserID(),
                postID: postId,
                metadata: InteractionMetadata(
                    duration: type == .doubleTabLike ? 0.5 : nil,
                    intensity: type == .doubleTabLike ? 1.0 : 0.8
                )
            )

            // Add to liked posts
            likedPosts.insert(postId)

            // Add to recent interactions
            recentInteractions.insert(interaction, at: 0)
            if recentInteractions.count > Constants.maxInteractionsCache {
                recentInteractions.removeLast()
            }

            // Trigger haptic feedback
            await triggerHapticFeedback(for: type)

            // Play sound effect
            await playSoundEffect(for: type)

            // Save to cache
            await saveInteractionData()

            // Send notification to post author (if not own post)
            await sendInteractionNotification(interaction)

            isProcessingInteraction = false

        } catch {
            interactionError = InteractionError.operationFailed(error)
            isProcessingInteraction = false
        }
    }

    private func processUnlikeInteraction(postId: UUID) async {
        likedPosts.remove(postId)

        // Remove from recent interactions
        recentInteractions.removeAll {
            $0.postID == postId && ($0.type == .like || $0.type == .doubleTabLike)
        }

        await saveInteractionData()
    }

    // MARK: - Save Interactions
    func savePost(_ postId: UUID) {
        if savedPosts.contains(postId) {
            unsavePost(postId)
        } else {
            Task {
                await processSaveInteraction(postId: postId)
            }
        }
    }

    func unsavePost(_ postId: UUID) {
        savedPosts.remove(postId)

        Task {
            await saveInteractionData()
        }
    }

    private func processSaveInteraction(postId: UUID) async {
        let interaction = SocialInteraction(
            type: .save,
            userID: await getCurrentUserID(),
            postID: postId
        )

        savedPosts.insert(postId)
        recentInteractions.insert(interaction, at: 0)

        await triggerHapticFeedback(for: .save)
        await saveInteractionData()
    }

    // MARK: - Comment Interactions
    func addComment(to postId: UUID, content: String, mentions: [String] = []) async throws -> Comment {
        isProcessingInteraction = true
        defer { isProcessingInteraction = false }

        // Validate comment content
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InteractionError.invalidComment("Comment cannot be empty")
        }

        guard content.count <= 500 else {
            throw InteractionError.invalidComment("Comment too long")
        }

        // Create comment
        let comment = Comment(
            postID: postId,
            authorID: await getCurrentUserID(),
            content: content,
            mentions: mentions
        )

        // Create interaction
        let interaction = SocialInteraction(
            type: .comment,
            userID: comment.authorID,
            postID: postId
        )

        recentInteractions.insert(interaction, at: 0)
        await saveInteractionData()

        // Send notification for mentions
        for mention in mentions {
            await sendMentionNotification(mentionedUserId: mention, comment: comment)
        }

        return comment
    }

    func likeComment(_ commentId: UUID) async {
        let interaction = SocialInteraction(
            type: .like,
            userID: await getCurrentUserID(),
            postID: UUID() // Would be the comment's post ID
        )

        recentInteractions.insert(interaction, at: 0)
        await triggerHapticFeedback(for: .like)
        await saveInteractionData()
    }

    func replyToComment(_ commentId: UUID, content: String) async throws -> Comment {
        return try await addComment(to: UUID(), content: content) // Would use proper post ID
    }

    // MARK: - Follow Interactions
    func followUser(_ userId: String) {
        guard !followedUsers.contains(userId) else { return }

        Task {
            await processFollowInteraction(userId: userId)
        }
    }

    func unfollowUser(_ userId: String) {
        followedUsers.remove(userId)

        Task {
            recentInteractions.removeAll { $0.userID == userId && $0.type == .follow }
            await saveInteractionData()
        }
    }

    private func processFollowInteraction(userId: String) async {
        let interaction = SocialInteraction(
            type: .follow,
            userID: await getCurrentUserID(),
            postID: UUID() // Not applicable for follow
        )

        followedUsers.insert(userId)
        recentInteractions.insert(interaction, at: 0)

        await triggerHapticFeedback(for: .follow)
        await playSoundEffect(for: .follow)
        await saveInteractionData()

        // Send follow notification
        await sendFollowNotification(followedUserId: userId)
    }

    // MARK: - Share Interactions
    func sharePost(_ postId: UUID, method: ShareMethod) async throws {
        let interaction = SocialInteraction(
            type: .share,
            userID: await getCurrentUserID(),
            postID: postId,
            metadata: InteractionMetadata(
                additionalData: ["method": method.rawValue]
            )
        )

        recentInteractions.insert(interaction, at: 0)
        await triggerHapticFeedback(for: .share)
        await saveInteractionData()

        // Track sharing analytics (if permitted)
        await trackSharingAnalytics(postId: postId, method: method)
    }

    // MARK: - Block and Report
    func blockUser(_ userId: String) async {
        blockedUsers.insert(userId)

        // Remove all interactions with blocked user
        recentInteractions.removeAll { $0.userID == userId }

        // Unfollow if following
        followedUsers.remove(userId)

        let interaction = SocialInteraction(
            type: .block,
            userID: await getCurrentUserID(),
            postID: UUID()
        )

        recentInteractions.insert(interaction, at: 0)
        await saveInteractionData()

        // Update privacy settings
        if var profile = profileManager.currentProfile {
            profile.blockedUsers.insert(userId)
            try? await profileManager.updateProfile(
                ProfileUpdate(
                    displayName: nil,
                    bio: nil,
                    profileImage: nil,
                    coverImage: nil,
                    settings: profile.settings,
                    styleMoodBoard: nil
                )
            )
        }
    }

    func reportContent(_ contentId: UUID, reason: ReportReason, description: String?) async throws {
        let report = SafetyReport(
            reporterID: await getCurrentUserID(),
            reportedContent: .post(contentId),
            reason: reason,
            description: description,
            evidence: []
        )

        // Submit report (would send to moderation system)
        await submitSafetyReport(report)

        let interaction = SocialInteraction(
            type: .report,
            userID: await getCurrentUserID(),
            postID: contentId
        )

        recentInteractions.insert(interaction, at: 0)
        await saveInteractionData()
    }

    // MARK: - Voting (for polls, challenges, etc.)
    func vote(on postId: UUID, option: UUID) async {
        let interaction = SocialInteraction(
            type: .vote,
            userID: await getCurrentUserID(),
            postID: postId,
            metadata: InteractionMetadata(
                additionalData: ["option": option.uuidString]
            )
        )

        recentInteractions.insert(interaction, at: 0)
        await triggerHapticFeedback(for: .vote)
        await saveInteractionData()
    }

    // MARK: - Reactions (emoji reactions)
    func addReaction(to postId: UUID, emoji: String) async {
        let interaction = SocialInteraction(
            type: .react,
            userID: await getCurrentUserID(),
            postID: postId,
            metadata: InteractionMetadata(
                additionalData: ["emoji": emoji]
            )
        )

        recentInteractions.insert(interaction, at: 0)
        await triggerHapticFeedback(for: .react)
        await saveInteractionData()
    }

    // MARK: - Utility Methods
    func isPostLiked(_ postId: UUID) -> Bool {
        return likedPosts.contains(postId)
    }

    func isPostSaved(_ postId: UUID) -> Bool {
        return savedPosts.contains(postId)
    }

    func isUserFollowed(_ userId: String) -> Bool {
        return followedUsers.contains(userId)
    }

    func isUserBlocked(_ userId: String) -> Bool {
        return blockedUsers.contains(userId)
    }

    func getInteractionCount(for type: InteractionType, postId: UUID) -> Int {
        return recentInteractions.filter {
            $0.type == type && $0.postID == postId
        }.count
    }

    // MARK: - Feedback Effects
    private func triggerHapticFeedback(for type: InteractionType) async {
        switch type {
        case .like, .doubleTabLike:
            await hapticManager.playHaptic(.impact(.medium))
        case .save:
            await hapticManager.playHaptic(.impact(.light))
        case .follow:
            await hapticManager.playHaptic(.notification(.success))
        case .share:
            await hapticManager.playHaptic(.impact(.light))
        case .vote:
            await hapticManager.playHaptic(.selection)
        case .react:
            await hapticManager.playHaptic(.impact(.light))
        default:
            await hapticManager.playHaptic(.impact(.light))
        }
    }

    private func playSoundEffect(for type: InteractionType) async {
        guard await soundManager.isSoundEnabled else { return }

        switch type {
        case .like, .doubleTabLike:
            await soundManager.playSound(.success)
        case .follow:
            await soundManager.playSound(.notification)
        case .save:
            await soundManager.playSound(.pop)
        default:
            break
        }
    }

    // MARK: - Notifications
    private func sendInteractionNotification(_ interaction: SocialInteraction) async {
        // Send push notification to post author
        // This would integrate with your notification system
        print("Sending notification for interaction: \(interaction.type)")
    }

    private func sendMentionNotification(mentionedUserId: String, comment: Comment) async {
        // Send notification to mentioned user
        print("Sending mention notification to: \(mentionedUserId)")
    }

    private func sendFollowNotification(followedUserId: String) async {
        // Send notification to followed user
        print("Sending follow notification to: \(followedUserId)")
    }

    // MARK: - Safety and Moderation
    private func submitSafetyReport(_ report: SafetyReport) async {
        // Submit to moderation system
        print("Submitting safety report: \(report.reason)")
    }

    // MARK: - Analytics
    private func trackSharingAnalytics(postId: UUID, method: ShareMethod) async {
        guard await privacyManager.permissionsGranted.contains(.analytics) else { return }

        // Track sharing for recommendation algorithms
        print("Tracking share: \(postId) via \(method)")
    }

    // MARK: - Data Management
    private func saveInteractionData() async {
        do {
            let interactionData = InteractionCacheData(
                likedPosts: likedPosts,
                savedPosts: savedPosts,
                followedUsers: followedUsers,
                blockedUsers: blockedUsers,
                recentInteractions: recentInteractions,
                timestamp: Date()
            )

            let encodedData = try JSONEncoder().encode(interactionData)
            let encryptedData = try cryptoEngine.encrypt(data: encodedData)

            try await storageManager.storeSecurely(
                data: try JSONEncoder().encode(encryptedData),
                at: Constants.interactionsCacheKey
            )
        } catch {
            print("Failed to save interaction data: \(error)")
        }
    }

    private func loadCachedData() {
        Task {
            do {
                let encryptedData = try await storageManager.loadSecurely(from: Constants.interactionsCacheKey)
                let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
                let interactionData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
                let cacheData = try JSONDecoder().decode(InteractionCacheData.self, from: interactionData)

                likedPosts = cacheData.likedPosts
                savedPosts = cacheData.savedPosts
                followedUsers = cacheData.followedUsers
                blockedUsers = cacheData.blockedUsers
                recentInteractions = cacheData.recentInteractions

            } catch {
                print("Failed to load cached interaction data: \(error)")
            }
        }
    }

    // MARK: - Monitoring
    private func setupInteractionMonitoring() {
        // Monitor for privacy changes
        privacyManager.$privacyLevel
            .sink { [weak self] newLevel in
                Task {
                    await self?.handlePrivacyLevelChange(newLevel)
                }
            }
            .store(in: &cancellables)
    }

    private func handlePrivacyLevelChange(_ newLevel: PrivacyLevel) async {
        switch newLevel {
        case .maximum:
            // Clear some interaction history for maximum privacy
            let cutoffDate = Date().addingTimeInterval(-86400) // Last 24 hours only
            recentInteractions = recentInteractions.filter { $0.timestamp > cutoffDate }

        case .high:
            // Keep last 7 days
            let cutoffDate = Date().addingTimeInterval(-86400 * 7)
            recentInteractions = recentInteractions.filter { $0.timestamp > cutoffDate }

        default:
            break
        }

        await saveInteractionData()
    }

    // MARK: - Helper Methods
    private func getCurrentUserID() async -> String {
        return await profileManager.currentProfile?.anonymousID ?? "anonymous"
    }
}

// MARK: - Supporting Types
struct InteractionCacheData: Codable {
    let likedPosts: Set<UUID>
    let savedPosts: Set<UUID>
    let followedUsers: Set<String>
    let blockedUsers: Set<String>
    let recentInteractions: [SocialInteraction]
    let timestamp: Date
}

enum ShareMethod: String, Codable, CaseIterable {
    case directMessage = "direct_message"
    case story = "story"
    case externalShare = "external_share"
    case link = "link"
    case embed = "embed"
}

// MARK: - Interaction Errors
enum InteractionError: LocalizedError {
    case operationFailed(Error)
    case invalidComment(String)
    case permissionDenied
    case userBlocked
    case contentNotFound
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .operationFailed(let error):
            return "Operation failed: \(error.localizedDescription)"
        case .invalidComment(let message):
            return message
        case .permissionDenied:
            return "Permission denied for this interaction"
        case .userBlocked:
            return "Cannot interact with blocked user"
        case .contentNotFound:
            return "Content not found"
        case .rateLimitExceeded:
            return "Too many interactions. Please wait and try again."
        }
    }
}

// MARK: - UUID Codable Extension
extension UUID: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uuidString)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuidString = try container.decode(String.self)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid UUID string")
        }
        self = uuid
    }
}