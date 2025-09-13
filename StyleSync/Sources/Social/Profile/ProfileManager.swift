import Foundation
import SwiftUI
import Combine

// MARK: - Profile Manager
@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    // MARK: - Published Properties
    @Published var currentProfile: UserProfile?
    @Published var isLoadingProfile = false
    @Published var profileError: ProfileError?
    @Published var achievements: [Achievement] = []
    @Published var profileAnalytics: ProfileAnalytics?

    // MARK: - Private Properties
    private let privacyManager = PrivacyControlsManager.shared
    private let anonymousIdentity = AnonymousIdentityManager.shared
    private let storageManager = SandboxedStorageManager.shared
    private let cryptoEngine = CryptoEngine.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants
    private enum Constants {
        static let profileCacheKey = "user_profile_cache"
        static let achievementsCacheKey = "user_achievements_cache"
        static let profileImagePath = "profile_images"
        static let coverImagePath = "cover_images"
        static let maxImageSize: CGFloat = 1024
        static let compressionQuality: CGFloat = 0.8
    }

    private init() {
        loadCachedProfile()
        setupProfileMonitoring()
    }

    // MARK: - Profile Creation & Setup
    func createProfile(
        displayName: String,
        username: String,
        bio: String,
        profileImage: UIImage?,
        coverImage: UIImage?
    ) async throws {
        isLoadingProfile = true
        profileError = nil

        do {
            // Generate anonymous identity
            let anonymousID = await anonymousIdentity.generateAnonymousIdentity()

            // Process and encrypt images
            var profileImageData: Data?
            var coverImageData: Data?

            if let profileImage = profileImage {
                profileImageData = try await processAndEncryptImage(profileImage, type: .profile)
            }

            if let coverImage = coverImage {
                coverImageData = try await processAndEncryptImage(coverImage, type: .cover)
            }

            // Create profile with privacy-first approach
            let profile = UserProfile(
                anonymousID: anonymousID,
                displayName: displayName,
                username: username.lowercased(),
                bio: bio,
                profileImageData: profileImageData,
                coverImageData: coverImageData,
                verificationStatus: .unverified,
                settings: ProfileSettings(),
                styleMoodBoard: nil
            )

            // Validate profile data
            try validateProfile(profile)

            // Save encrypted profile
            try await saveProfile(profile)

            currentProfile = profile

            // Initialize achievements
            await initializeAchievements()

            isLoadingProfile = false

        } catch {
            isLoadingProfile = false
            profileError = ProfileError.creationFailed(error)
            throw error
        }
    }

    // MARK: - Profile Updates
    func updateProfile(_ updates: ProfileUpdate) async throws {
        guard var profile = currentProfile else {
            throw ProfileError.noCurrentProfile
        }

        isLoadingProfile = true
        profileError = nil

        do {
            // Apply updates
            if let displayName = updates.displayName {
                profile.displayName = displayName
            }

            if let bio = updates.bio {
                profile.bio = bio
            }

            if let profileImage = updates.profileImage {
                profile.profileImageData = try await processAndEncryptImage(profileImage, type: .profile)
            }

            if let coverImage = updates.coverImage {
                profile.coverImageData = try await processAndEncryptImage(coverImage, type: .cover)
            }

            if let settings = updates.settings {
                profile.settings = settings
            }

            if let moodBoard = updates.styleMoodBoard {
                profile.styleMoodBoard = moodBoard
            }

            // Update timestamps
            profile.lastActive = Date()

            // Validate updated profile
            try validateProfile(profile)

            // Save updated profile
            try await saveProfile(profile)

            currentProfile = profile

            // Check for new achievements
            await checkAchievements(for: profile)

            isLoadingProfile = false

        } catch {
            isLoadingProfile = false
            profileError = ProfileError.updateFailed(error)
            throw error
        }
    }

    // MARK: - Profile Verification
    func requestVerification(type: VerificationRequest) async throws {
        guard var profile = currentProfile else {
            throw ProfileError.noCurrentProfile
        }

        // Submit verification request based on type
        switch type {
        case .personal:
            try await submitPersonalVerification(profile)
        case .stylist(let credentials):
            try await submitStylistVerification(profile, credentials: credentials)
        case .brand(let businessInfo):
            try await submitBrandVerification(profile, businessInfo: businessInfo)
        }

        // Update profile to show verification pending
        profile.verificationStatus = .unverified // Would be .pending in real implementation
        currentProfile = profile

        try await saveProfile(profile)
    }

    // MARK: - Style DNA Analysis
    func updateStyleDNA(_ styleDNA: StyleDNA) async throws {
        guard var profile = currentProfile else {
            throw ProfileError.noCurrentProfile
        }

        // Create or update mood board based on style DNA
        let moodBoard = StyleMoodBoard(
            colors: styleDNA.colorPreferences,
            styles: styleDNA.styleCategories.map { category in
                StyleTag(
                    name: category.rawValue.capitalized,
                    category: category,
                    popularity: 1.0
                )
            },
            inspirations: [],
            preferredBrands: styleDNA.brandAffinities,
            bodyType: styleDNA.bodyType,
            colorSeason: nil, // Would be determined by color analysis
            stylePersonality: determineStylePersonality(from: styleDNA)
        )

        profile.styleMoodBoard = moodBoard

        try await saveProfile(profile)
        currentProfile = profile

        // Check for style-related achievements
        await checkStyleAchievements(styleDNA)
    }

    // MARK: - Privacy & Security
    func updatePrivacySettings(_ settings: SocialPrivacySettings) async throws {
        guard var profile = currentProfile else {
            throw ProfileError.noCurrentProfile
        }

        profile.settings.privacySettings = settings

        try await saveProfile(profile)
        currentProfile = profile
    }

    func generateShareableProfile() async throws -> ShareableProfile {
        guard let profile = currentProfile else {
            throw ProfileError.noCurrentProfile
        }

        // Create privacy-safe shareable version
        return ShareableProfile(
            displayName: profile.displayName,
            username: profile.username,
            bio: profile.bio,
            publicStats: PublicStats(
                postCount: profile.settings.showPostCount ? profile.postCount : nil,
                followerCount: profile.settings.showFollowerCount ? profile.followerCount : nil,
                followingCount: profile.settings.showFollowingCount ? profile.followingCount : nil
            ),
            verificationStatus: profile.verificationStatus,
            styleSummary: generateStyleSummary(from: profile.styleMoodBoard)
        )
    }

    // MARK: - Achievement System
    private func initializeAchievements() async {
        // Initialize basic achievements
        let welcomeAchievement = Achievement(
            title: "Welcome to StyleSync",
            description: "Created your first profile",
            iconName: "person.crop.circle.badge.checkmark",
            unlockedAt: Date(),
            category: .social,
            rarity: .common
        )

        achievements = [welcomeAchievement]
        await saveAchievements()
    }

    private func checkAchievements(for profile: UserProfile) async {
        var newAchievements: [Achievement] = []

        // Check profile completion achievements
        if !profile.bio.isEmpty && achievements.first(where: { $0.title == "Profile Complete" }) == nil {
            newAchievements.append(
                Achievement(
                    title: "Profile Complete",
                    description: "Added a bio to your profile",
                    iconName: "text.alignleft",
                    unlockedAt: Date(),
                    category: .social,
                    rarity: .common
                )
            )
        }

        // Check verification achievements
        if profile.verificationStatus != .unverified && achievements.first(where: { $0.title == "Verified" }) == nil {
            newAchievements.append(
                Achievement(
                    title: "Verified",
                    description: "Successfully verified your account",
                    iconName: "checkmark.seal.fill",
                    unlockedAt: Date(),
                    category: .social,
                    rarity: .uncommon
                )
            )
        }

        // Add new achievements
        if !newAchievements.isEmpty {
            achievements.append(contentsOf: newAchievements)
            await saveAchievements()
        }
    }

    private func checkStyleAchievements(_ styleDNA: StyleDNA) async {
        var newAchievements: [Achievement] = []

        // Style DNA completion
        if achievements.first(where: { $0.title == "Style DNA Complete" }) == nil {
            newAchievements.append(
                Achievement(
                    title: "Style DNA Complete",
                    description: "Completed your style profile",
                    iconName: "dna",
                    unlockedAt: Date(),
                    category: .styling,
                    rarity: .uncommon
                )
            )
        }

        // Color confidence achievements
        if styleDNA.confidenceMetrics.colorConfidence > 0.8 && achievements.first(where: { $0.title == "Color Confident" }) == nil {
            newAchievements.append(
                Achievement(
                    title: "Color Confident",
                    description: "Achieved high color confidence",
                    iconName: "paintpalette.fill",
                    unlockedAt: Date(),
                    category: .styling,
                    rarity: .rare
                )
            )
        }

        if !newAchievements.isEmpty {
            achievements.append(contentsOf: newAchievements)
            await saveAchievements()
        }
    }

    // MARK: - Analytics
    func updateProfileAnalytics() async {
        guard let profile = currentProfile else { return }

        let analytics = ProfileAnalytics(
            profileViews: 0, // Would be tracked
            searchAppearances: 0,
            averageEngagement: 0.0,
            topHashtags: [],
            styleInfluenceScore: calculateStyleInfluence(profile),
            lastUpdated: Date()
        )

        profileAnalytics = analytics
    }

    // MARK: - Image Processing
    private func processAndEncryptImage(_ image: UIImage, type: ImageType) async throws -> Data {
        // Resize image
        let resizedImage = try await resizeImage(image, maxSize: Constants.maxImageSize)

        // Convert to data
        guard let imageData = resizedImage.jpegData(compressionQuality: Constants.compressionQuality) else {
            throw ProfileError.imageProcessingFailed
        }

        // Encrypt image data
        let encryptedData = try cryptoEngine.encrypt(data: imageData)
        let encryptedImageData = try JSONEncoder().encode(encryptedData)

        // Save to secure storage
        let imagePath = type == .profile ? Constants.profileImagePath : Constants.coverImagePath
        try await storageManager.storeSecurely(
            data: encryptedImageData,
            at: "\(imagePath)/\(UUID().uuidString).enc"
        )

        return encryptedImageData
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) async throws -> UIImage {
        return await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let size = image.size
                let ratio = min(maxSize / size.width, maxSize / size.height)

                if ratio >= 1.0 {
                    continuation.resume(returning: image)
                    return
                }

                let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

                UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                if let resizedImage = resizedImage {
                    continuation.resume(returning: resizedImage)
                } else {
                    continuation.resume(throwing: ProfileError.imageProcessingFailed)
                }
            }
        }
    }

    // MARK: - Validation
    private func validateProfile(_ profile: UserProfile) throws {
        if profile.displayName.isEmpty {
            throw ProfileError.invalidDisplayName
        }

        if profile.username.isEmpty || profile.username.count < 3 {
            throw ProfileError.invalidUsername
        }

        if !isValidUsername(profile.username) {
            throw ProfileError.invalidUsername
        }

        if profile.bio.count > 500 {
            throw ProfileError.bioTooLong
        }
    }

    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }

    // MARK: - Storage Operations
    private func saveProfile(_ profile: UserProfile) async throws {
        let profileData = try JSONEncoder().encode(profile)
        let encryptedData = try cryptoEngine.encrypt(data: profileData)

        try await storageManager.storeSecurely(
            data: try JSONEncoder().encode(encryptedData),
            at: Constants.profileCacheKey
        )
    }

    private func loadCachedProfile() {
        Task {
            do {
                let encryptedData = try await storageManager.loadSecurely(from: Constants.profileCacheKey)
                let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
                let profileData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
                let profile = try JSONDecoder().decode(UserProfile.self, from: profileData)

                await MainActor.run {
                    self.currentProfile = profile
                }

                await loadCachedAchievements()

            } catch {
                // Profile doesn't exist yet or failed to load
                await MainActor.run {
                    self.currentProfile = nil
                }
            }
        }
    }

    private func saveAchievements() async {
        do {
            let achievementsData = try JSONEncoder().encode(achievements)
            let encryptedData = try cryptoEngine.encrypt(data: achievementsData)

            try await storageManager.storeSecurely(
                data: try JSONEncoder().encode(encryptedData),
                at: Constants.achievementsCacheKey
            )
        } catch {
            print("Failed to save achievements: \(error)")
        }
    }

    private func loadCachedAchievements() async {
        do {
            let encryptedData = try await storageManager.loadSecurely(from: Constants.achievementsCacheKey)
            let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
            let achievementsData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
            let loadedAchievements = try JSONDecoder().decode([Achievement].self, from: achievementsData)

            await MainActor.run {
                self.achievements = loadedAchievements
            }
        } catch {
            // Achievements don't exist yet or failed to load
            await MainActor.run {
                self.achievements = []
            }
        }
    }

    // MARK: - Verification Implementations
    private func submitPersonalVerification(_ profile: UserProfile) async throws {
        // Implementation would submit personal verification request
        // This would involve ID verification, phone number verification, etc.
    }

    private func submitStylistVerification(_ profile: UserProfile, credentials: StylistCredentials) async throws {
        // Implementation would submit stylist verification with credentials
    }

    private func submitBrandVerification(_ profile: UserProfile, businessInfo: BusinessInfo) async throws {
        // Implementation would submit brand verification with business information
    }

    // MARK: - Helper Functions
    private func determineStylePersonality(from styleDNA: StyleDNA) -> StylePersonality? {
        // Logic to determine style personality based on preferences
        let styleCategories = styleDNA.styleCategories

        if styleCategories.contains(.minimalist) {
            return .minimalist
        } else if styleCategories.contains(.bohemian) {
            return .bohemian
        } else if styleCategories.contains(.edgy) {
            return .edgy
        } else if styleCategories.contains(.formal) {
            return .professional
        } else if styleCategories.contains(.casual) {
            return .casual
        }

        return .classic
    }

    private func generateStyleSummary(from moodBoard: StyleMoodBoard?) -> String? {
        guard let moodBoard = moodBoard else { return nil }

        var summary = ""

        if let personality = moodBoard.stylePersonality {
            summary = personality.description
        }

        if !moodBoard.styles.isEmpty {
            let topStyles = moodBoard.styles.prefix(3).map { $0.name }.joined(separator: ", ")
            summary += summary.isEmpty ? topStyles : " | \(topStyles)"
        }

        return summary.isEmpty ? nil : summary
    }

    private func calculateStyleInfluence(_ profile: UserProfile) -> Float {
        // Calculate influence based on various factors
        var influence: Float = 0.0

        influence += Float(profile.followerCount) * 0.001
        influence += Float(profile.postCount) * 0.1
        influence += profile.verificationStatus != .unverified ? 10.0 : 0.0

        return min(influence, 100.0)
    }

    // MARK: - Profile Monitoring
    private func setupProfileMonitoring() {
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
        guard var profile = currentProfile else { return }

        // Adjust profile visibility based on privacy level
        switch newLevel {
        case .maximum:
            profile.isPrivateAccount = true
            profile.settings.showActivityStatus = false
            profile.settings.showFollowerCount = false
            profile.settings.showFollowingCount = false

        case .high:
            profile.isPrivateAccount = true
            profile.settings.showActivityStatus = false

        case .balanced:
            profile.settings.allowTagging = true
            profile.settings.allowMentions = true

        case .minimal:
            profile.settings.showPostCount = true
            profile.settings.allowDirectMessages = true
        }

        do {
            try await saveProfile(profile)
            currentProfile = profile
        } catch {
            profileError = ProfileError.updateFailed(error)
        }
    }
}

// MARK: - Supporting Types
enum ImageType {
    case profile
    case cover
}

struct ProfileUpdate {
    let displayName: String?
    let bio: String?
    let profileImage: UIImage?
    let coverImage: UIImage?
    let settings: ProfileSettings?
    let styleMoodBoard: StyleMoodBoard?
}

enum VerificationRequest {
    case personal
    case stylist(StylistCredentials)
    case brand(BusinessInfo)
}

struct StylistCredentials {
    let certification: Data?
    let portfolio: [Data]
    let yearsOfExperience: Int
    let specializations: [String]
}

struct BusinessInfo {
    let businessName: String
    let registrationNumber: String
    let businessType: String
    let website: String?
    let verificationDocuments: [Data]
}

struct ShareableProfile {
    let displayName: String
    let username: String
    let bio: String
    let publicStats: PublicStats
    let verificationStatus: VerificationStatus
    let styleSummary: String?
}

struct PublicStats {
    let postCount: Int?
    let followerCount: Int?
    let followingCount: Int?
}

struct ProfileAnalytics {
    let profileViews: Int
    let searchAppearances: Int
    let averageEngagement: Double
    let topHashtags: [String]
    let styleInfluenceScore: Float
    let lastUpdated: Date
}

// MARK: - Profile Errors
enum ProfileError: LocalizedError {
    case noCurrentProfile
    case creationFailed(Error)
    case updateFailed(Error)
    case invalidDisplayName
    case invalidUsername
    case bioTooLong
    case imageProcessingFailed
    case verificationFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .noCurrentProfile:
            return "No current profile available"
        case .creationFailed(let error):
            return "Profile creation failed: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Profile update failed: \(error.localizedDescription)"
        case .invalidDisplayName:
            return "Display name cannot be empty"
        case .invalidUsername:
            return "Username must be at least 3 characters and contain only letters, numbers, and underscores"
        case .bioTooLong:
            return "Bio cannot exceed 500 characters"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .verificationFailed:
            return "Account verification failed"
        case .networkError:
            return "Network error occurred"
        }
    }
}