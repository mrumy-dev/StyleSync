import Foundation
import SwiftUI
import Combine
import LocalAuthentication
import CryptoKit

@MainActor
class PrivacyManager: ObservableObject {
    static let shared = PrivacyManager()

    @Published var privacySettings: PrivacySettings
    @Published var blockedUsers: Set<String> = []
    @Published var restrictedUsers: Set<String> = []
    @Published var reportedContent: Set<String> = []
    @Published var contentFilters: ContentFilters
    @Published var safetyMode: SafetyMode = .standard
    @Published var isPrivateAccount = false
    @Published var hideLikeCounts = false
    @Published var hideActivityStatus = false
    @Published var allowScreenshots = true

    private let keychain = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.privacySettings = PrivacySettings()
        self.contentFilters = ContentFilters()
        loadPrivacySettings()
        setupAutoSave()
    }

    // MARK: - Account Privacy

    func setAccountPrivacy(_ isPrivate: Bool) {
        isPrivateAccount = isPrivate
        savePrivacySettings()

        HapticManager.shared.impact(.medium)
        NotificationCenter.default.post(
            name: .privacySettingsChanged,
            object: nil,
            userInfo: ["accountPrivacy": isPrivate]
        )
    }

    func toggleHideLikeCounts() {
        hideLikeCounts.toggle()
        savePrivacySettings()
        HapticManager.shared.impact(.light)
    }

    func toggleActivityStatus() {
        hideActivityStatus.toggle()
        savePrivacySettings()
        HapticManager.shared.impact(.light)
    }

    func toggleScreenshotPermissions() {
        allowScreenshots.toggle()
        savePrivacySettings()
        HapticManager.shared.impact(.medium)
    }

    // MARK: - Content Filtering

    func updateContentFilters(_ filters: ContentFilters) {
        contentFilters = filters
        savePrivacySettings()

        Task {
            await applyContentFilters()
        }
    }

    func setSafetyMode(_ mode: SafetyMode) {
        safetyMode = mode
        updateContentFiltersForSafetyMode(mode)
        savePrivacySettings()
        HapticManager.shared.impact(.medium)
    }

    private func updateContentFiltersForSafetyMode(_ mode: SafetyMode) {
        switch mode {
        case .strict:
            contentFilters.filterAdultContent = true
            contentFilters.filterViolence = true
            contentFilters.filterProfanity = true
            contentFilters.filterSensitiveTopics = true
            contentFilters.requireContentWarnings = true

        case .standard:
            contentFilters.filterAdultContent = true
            contentFilters.filterViolence = true
            contentFilters.filterProfanity = false
            contentFilters.filterSensitiveTopics = false
            contentFilters.requireContentWarnings = true

        case .minimal:
            contentFilters.filterAdultContent = false
            contentFilters.filterViolence = false
            contentFilters.filterProfanity = false
            contentFilters.filterSensitiveTopics = false
            contentFilters.requireContentWarnings = false
        }
    }

    private func applyContentFilters() async {
        NotificationCenter.default.post(
            name: .contentFiltersUpdated,
            object: nil,
            userInfo: ["filters": contentFilters]
        )
    }

    // MARK: - User Management

    func blockUser(_ userID: String) async {
        blockedUsers.insert(userID)
        restrictedUsers.remove(userID)

        await removeUserContent(userID)
        savePrivacySettings()

        HapticManager.shared.impact(.heavy)
        NotificationCenter.default.post(
            name: .userBlocked,
            object: nil,
            userInfo: ["userID": userID]
        )
    }

    func unblockUser(_ userID: String) {
        blockedUsers.remove(userID)
        savePrivacySettings()

        HapticManager.shared.impact(.light)
        NotificationCenter.default.post(
            name: .userUnblocked,
            object: nil,
            userInfo: ["userID": userID]
        )
    }

    func restrictUser(_ userID: String) {
        restrictedUsers.insert(userID)
        savePrivacySettings()

        HapticManager.shared.impact(.medium)
        NotificationCenter.default.post(
            name: .userRestricted,
            object: nil,
            userInfo: ["userID": userID]
        )
    }

    func unrestrict(_ userID: String) {
        restrictedUsers.remove(userID)
        savePrivacySettings()
        HapticManager.shared.impact(.light)
    }

    func isUserBlocked(_ userID: String) -> Bool {
        return blockedUsers.contains(userID)
    }

    func isUserRestricted(_ userID: String) -> Bool {
        return restrictedUsers.contains(userID)
    }

    private func removeUserContent(_ userID: String) async {
        NotificationCenter.default.post(
            name: .removeUserContent,
            object: nil,
            userInfo: ["userID": userID]
        )
    }

    // MARK: - Reporting System

    func reportContent(_ contentID: String, reason: ReportReason, details: String?) async {
        let report = ContentReport(
            id: UUID().uuidString,
            contentID: contentID,
            reporterID: "current_user",
            reason: reason,
            details: details,
            timestamp: Date(),
            status: .pending
        )

        reportedContent.insert(contentID)

        await submitReport(report)
        savePrivacySettings()

        HapticManager.shared.impact(.medium)
    }

    func reportUser(_ userID: String, reason: ReportReason, details: String?) async {
        let report = UserReport(
            id: UUID().uuidString,
            reportedUserID: userID,
            reporterID: "current_user",
            reason: reason,
            details: details,
            timestamp: Date(),
            status: .pending
        )

        await submitUserReport(report)
        HapticManager.shared.impact(.medium)
    }

    private func submitReport(_ report: ContentReport) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let reportData = try encoder.encode(report)

            try await keychain.store(reportData, forKey: "report_\(report.id)")

            NotificationCenter.default.post(
                name: .contentReported,
                object: nil,
                userInfo: ["report": report]
            )

        } catch {
            print("Failed to submit report: \(error)")
        }
    }

    private func submitUserReport(_ report: UserReport) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let reportData = try encoder.encode(report)

            try await keychain.store(reportData, forKey: "user_report_\(report.id)")

            NotificationCenter.default.post(
                name: .userReported,
                object: nil,
                userInfo: ["report": report]
            )

        } catch {
            print("Failed to submit user report: \(error)")
        }
    }

    func isContentReported(_ contentID: String) -> Bool {
        return reportedContent.contains(contentID)
    }

    // MARK: - Data Protection

    func enableDisappearingMessages(for conversationID: String, duration: TimeInterval) async {
        privacySettings.disappearingMessages[conversationID] = duration
        savePrivacySettings()

        NotificationCenter.default.post(
            name: .disappearingMessagesEnabled,
            object: nil,
            userInfo: ["conversationID": conversationID, "duration": duration]
        )
    }

    func disableDisappearingMessages(for conversationID: String) {
        privacySettings.disappearingMessages.removeValue(forKey: conversationID)
        savePrivacySettings()

        NotificationCenter.default.post(
            name: .disappearingMessagesDisabled,
            object: nil,
            userInfo: ["conversationID": conversationID]
        )
    }

    func scheduleDataDeletion(after days: Int) {
        privacySettings.dataRetentionDays = days
        savePrivacySettings()

        scheduleAutomaticCleanup()
    }

    private func scheduleAutomaticCleanup() {
        guard privacySettings.dataRetentionDays > 0 else { return }

        let cleanupDate = Calendar.current.date(
            byAdding: .day,
            value: privacySettings.dataRetentionDays,
            to: Date()
        )!

        NotificationCenter.default.post(
            name: .dataCleanupScheduled,
            object: nil,
            userInfo: ["cleanupDate": cleanupDate]
        )
    }

    // MARK: - Biometric Protection

    func enableBiometricProtection(for feature: ProtectedFeature) async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw PrivacyError.biometricNotAvailable
        }

        let reason = "Protect your \(feature.rawValue) with biometric authentication"
        let result = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        if result {
            privacySettings.biometricProtection.insert(feature)
            savePrivacySettings()
            HapticManager.shared.success()
        }
    }

    func disableBiometricProtection(for feature: ProtectedFeature) async throws {
        let context = LAContext()
        let reason = "Remove biometric protection from \(feature.rawValue)"

        let result = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        if result {
            privacySettings.biometricProtection.remove(feature)
            savePrivacySettings()
            HapticManager.shared.success()
        }
    }

    func isBiometricProtected(_ feature: ProtectedFeature) -> Bool {
        return privacySettings.biometricProtection.contains(feature)
    }

    func authenticateForFeature(_ feature: ProtectedFeature) async throws -> Bool {
        guard isBiometricProtected(feature) else { return true }

        let context = LAContext()
        let reason = "Authenticate to access \(feature.rawValue)"

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    // MARK: - Persistence

    private func setupAutoSave() {
        Publishers.CombineLatest4(
            $blockedUsers,
            $restrictedUsers,
            $isPrivateAccount,
            $hideLikeCounts
        )
        .debounce(for: .seconds(1), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.savePrivacySettings()
        }
        .store(in: &cancellables)
    }

    private func savePrivacySettings() {
        do {
            let encoder = JSONEncoder()
            let settingsData = try encoder.encode(privacySettings)
            try keychain.store(settingsData, forKey: "privacy_settings")

            let blockedData = try encoder.encode(Array(blockedUsers))
            try keychain.store(blockedData, forKey: "blocked_users")

            let restrictedData = try encoder.encode(Array(restrictedUsers))
            try keychain.store(restrictedData, forKey: "restricted_users")

            let reportedData = try encoder.encode(Array(reportedContent))
            try keychain.store(reportedData, forKey: "reported_content")

        } catch {
            print("Failed to save privacy settings: \(error)")
        }
    }

    private func loadPrivacySettings() {
        do {
            let decoder = JSONDecoder()

            if let settingsData = try? keychain.retrieve(forKey: "privacy_settings") {
                privacySettings = try decoder.decode(PrivacySettings.self, from: settingsData)
            }

            if let blockedData = try? keychain.retrieve(forKey: "blocked_users") {
                let blocked = try decoder.decode([String].self, from: blockedData)
                blockedUsers = Set(blocked)
            }

            if let restrictedData = try? keychain.retrieve(forKey: "restricted_users") {
                let restricted = try decoder.decode([String].self, from: restrictedData)
                restrictedUsers = Set(restricted)
            }

            if let reportedData = try? keychain.retrieve(forKey: "reported_content") {
                let reported = try decoder.decode([String].self, from: reportedData)
                reportedContent = Set(reported)
            }

        } catch {
            print("Failed to load privacy settings: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct PrivacySettings: Codable {
    var whoCanMessage: MessagePermission = .everyone
    var whoCanSeeProfile: ProfileVisibility = .everyone
    var whoCanTagYou: TagPermission = .everyone
    var allowReadReceipts = true
    var allowTypingIndicators = true
    var allowLastSeenStatus = true
    var biometricProtection: Set<ProtectedFeature> = []
    var disappearingMessages: [String: TimeInterval] = [:]
    var dataRetentionDays: Int = 0
    var autoDeleteMedia = false
    var allowDataCollection = false
    var allowPersonalizedAds = false
}

struct ContentFilters: Codable {
    var filterAdultContent = true
    var filterViolence = true
    var filterProfanity = false
    var filterSensitiveTopics = false
    var requireContentWarnings = true
    var customKeywords: [String] = []
    var allowedAgeRating: AgeRating = .mature
}

enum SafetyMode: String, Codable, CaseIterable {
    case strict = "Strict"
    case standard = "Standard"
    case minimal = "Minimal"

    var description: String {
        switch self {
        case .strict:
            return "Maximum safety with strict content filtering"
        case .standard:
            return "Balanced safety with moderate filtering"
        case .minimal:
            return "Minimal filtering for mature users"
        }
    }
}

enum MessagePermission: String, Codable, CaseIterable {
    case everyone = "Everyone"
    case mutualFollows = "Mutual Follows"
    case followers = "Followers"
    case nobody = "Nobody"
}

enum ProfileVisibility: String, Codable, CaseIterable {
    case everyone = "Everyone"
    case mutualFollows = "Mutual Follows"
    case followers = "Followers"
    case nobody = "Nobody"
}

enum TagPermission: String, Codable, CaseIterable {
    case everyone = "Everyone"
    case mutualFollows = "Mutual Follows"
    case followers = "Followers"
    case nobody = "Nobody"
}

enum ProtectedFeature: String, Codable, CaseIterable {
    case directMessages = "Direct Messages"
    case profile = "Profile"
    case settings = "Settings"
    case wallet = "Wallet"
    case purchases = "Purchases"
}

enum AgeRating: String, Codable, CaseIterable {
    case everyone = "Everyone"
    case teen = "Teen (13+)"
    case mature = "Mature (17+)"
    case adult = "Adult (18+)"
}

enum ReportReason: String, Codable, CaseIterable {
    case spam = "Spam"
    case harassment = "Harassment"
    case inappropriateContent = "Inappropriate Content"
    case impersonation = "Impersonation"
    case copyrightViolation = "Copyright Violation"
    case violence = "Violence"
    case selfHarm = "Self Harm"
    case hateSpeech = "Hate Speech"
    case other = "Other"

    var description: String {
        switch self {
        case .spam:
            return "Unwanted or repetitive content"
        case .harassment:
            return "Bullying or targeted harassment"
        case .inappropriateContent:
            return "Adult or offensive content"
        case .impersonation:
            return "Pretending to be someone else"
        case .copyrightViolation:
            return "Unauthorized use of content"
        case .violence:
            return "Violent or graphic content"
        case .selfHarm:
            return "Content promoting self-harm"
        case .hateSpeech:
            return "Discriminatory language or symbols"
        case .other:
            return "Other violation"
        }
    }
}

struct ContentReport: Codable {
    let id: String
    let contentID: String
    let reporterID: String
    let reason: ReportReason
    let details: String?
    let timestamp: Date
    var status: ReportStatus
}

struct UserReport: Codable {
    let id: String
    let reportedUserID: String
    let reporterID: String
    let reason: ReportReason
    let details: String?
    let timestamp: Date
    var status: ReportStatus
}

enum ReportStatus: String, Codable {
    case pending = "Pending"
    case underReview = "Under Review"
    case resolved = "Resolved"
    case dismissed = "Dismissed"
}

enum PrivacyError: Error {
    case biometricNotAvailable
    case authenticationFailed
    case settingsNotFound
    case encryptionFailed
}

// MARK: - Notifications

extension Notification.Name {
    static let privacySettingsChanged = Notification.Name("privacySettingsChanged")
    static let contentFiltersUpdated = Notification.Name("contentFiltersUpdated")
    static let userBlocked = Notification.Name("userBlocked")
    static let userUnblocked = Notification.Name("userUnblocked")
    static let userRestricted = Notification.Name("userRestricted")
    static let removeUserContent = Notification.Name("removeUserContent")
    static let contentReported = Notification.Name("contentReported")
    static let userReported = Notification.Name("userReported")
    static let disappearingMessagesEnabled = Notification.Name("disappearingMessagesEnabled")
    static let disappearingMessagesDisabled = Notification.Name("disappearingMessagesDisabled")
    static let dataCleanupScheduled = Notification.Name("dataCleanupScheduled")
}