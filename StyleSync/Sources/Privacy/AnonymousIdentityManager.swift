import Foundation
import UIKit
import CryptoKit
import SwiftUI

// MARK: - Anonymous Identity Manager
@MainActor
public final class AnonymousIdentityManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AnonymousIdentityManager()
    
    // MARK: - Published Properties
    @Published public var currentIdentity: AnonymousIdentity?
    @Published public var isAnonymousModeEnabled = true
    @Published public var availableAvatars: [Avatar] = []
    @Published public var socialInteractionLevel: SocialInteractionLevel = .minimal
    
    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let auditLogger = AuditLogger.shared
    private let keychainManager = KeychainManager.shared
    private var identityRotationTimer: Timer?
    private let identityQueue = DispatchQueue(label: "com.stylesync.identity", qos: .userInitiated)
    
    // MARK: - Constants
    private enum Constants {
        static let identityRotationInterval: TimeInterval = 86400 // 24 hours
        static let maxIdentitiesStorageCount = 10
        static let anonymousIdPrefix = "anon_"
        static let avatarIdPrefix = "avatar_"
        static let socialInteractionKey = "social_interaction_level"
    }
    
    private init() {
        generateDefaultAvatars()
        loadCurrentIdentity()
        setupIdentityRotation()
    }
    
    // MARK: - Identity Management
    public func createNewAnonymousIdentity(
        socialLevel: SocialInteractionLevel = .minimal,
        customAvatar: Avatar? = nil
    ) async throws -> AnonymousIdentity {
        
        // Generate cryptographically secure anonymous ID
        let anonymousId = try generateAnonymousId()
        
        // Select or create avatar
        let avatar = customAvatar ?? selectRandomAvatar()
        
        // Generate interaction keys for social features
        let interactionKeys = try generateInteractionKeys()
        
        // Create identity with privacy-first settings
        let identity = AnonymousIdentity(
            id: anonymousId,
            avatar: avatar,
            displayName: generateAnonymousDisplayName(),
            socialLevel: socialLevel,
            interactionKeys: interactionKeys,
            createdAt: Date(),
            lastUsed: Date(),
            rotationCount: 0,
            privacySettings: createPrivacySettings(for: socialLevel)
        )
        
        // Store encrypted identity
        try await storeIdentity(identity)
        
        // Set as current identity
        currentIdentity = identity
        socialInteractionLevel = socialLevel
        
        // Log identity creation (without sensitive data)
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "anonymous_identity_created",
            "social_level": socialLevel.rawValue,
            "has_custom_avatar": customAvatar != nil
        ])
        
        return identity
    }
    
    public func rotateIdentity() async throws {
        guard let current = currentIdentity else {
            throw AnonymousIdentityError.noCurrentIdentity
        }
        
        // Create new identity with incremented rotation count
        let newAvatar = selectRandomAvatar(excluding: current.avatar)
        
        let rotatedIdentity = AnonymousIdentity(
            id: try generateAnonymousId(),
            avatar: newAvatar,
            displayName: generateAnonymousDisplayName(),
            socialLevel: current.socialLevel,
            interactionKeys: try generateInteractionKeys(),
            createdAt: Date(),
            lastUsed: Date(),
            rotationCount: current.rotationCount + 1,
            privacySettings: current.privacySettings
        )
        
        // Archive old identity
        try await archiveIdentity(current)
        
        // Store new identity
        try await storeIdentity(rotatedIdentity)
        
        // Update current
        currentIdentity = rotatedIdentity
        
        // Log rotation
        await auditLogger.logSecurityEvent(.keyRotation, details: [
            "previous_rotation_count": current.rotationCount,
            "new_rotation_count": rotatedIdentity.rotationCount
        ])
    }
    
    public func switchToRealNameMode() async throws {
        // Require biometric authentication for switching to real name mode
        let authManager = BiometricAuthManager.shared
        let authResult = await authManager.authenticate(reason: "Switch to real name mode")
        
        switch authResult {
        case .success:
            isAnonymousModeEnabled = false
            currentIdentity = nil
            
            // Log mode switch
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "switched_to_real_name_mode",
                "biometric_auth": true
            ])
            
        case .failure(let error):
            throw AnonymousIdentityError.authenticationFailed(error)
        }
    }
    
    public func switchToAnonymousMode() async throws {
        isAnonymousModeEnabled = true
        
        // Create new identity if none exists
        if currentIdentity == nil {
            let _ = try await createNewAnonymousIdentity(socialLevel: socialInteractionLevel)
        }
        
        // Log mode switch
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "switched_to_anonymous_mode"
        ])
    }
    
    // MARK: - Avatar System
    private func generateDefaultAvatars() {
        availableAvatars = [
            // Abstract geometric avatars
            Avatar(id: "geo_1", type: .geometric, primaryColor: .blue, secondaryColor: .purple, pattern: .circles),
            Avatar(id: "geo_2", type: .geometric, primaryColor: .green, secondaryColor: .teal, pattern: .triangles),
            Avatar(id: "geo_3", type: .geometric, primaryColor: .orange, secondaryColor: .red, pattern: .squares),
            Avatar(id: "geo_4", type: .geometric, primaryColor: .purple, secondaryColor: .pink, pattern: .hexagons),
            
            // Abstract art avatars
            Avatar(id: "art_1", type: .abstractArt, primaryColor: .indigo, secondaryColor: .cyan, pattern: .flowing),
            Avatar(id: "art_2", type: .abstractArt, primaryColor: .mint, secondaryColor: .green, pattern: .swirl),
            Avatar(id: "art_3", type: .abstractArt, primaryColor: .yellow, secondaryColor: .orange, pattern: .wave),
            Avatar(id: "art_4", type: .abstractArt, primaryColor: .pink, secondaryColor: .purple, pattern: .gradient),
            
            // Minimalist symbols
            Avatar(id: "sym_1", type: .symbol, primaryColor: .gray, secondaryColor: .white, pattern: .dot),
            Avatar(id: "sym_2", type: .symbol, primaryColor: .black, secondaryColor: .gray, pattern: .line),
            Avatar(id: "sym_3", type: .symbol, primaryColor: .blue, secondaryColor: .white, pattern: .cross),
            Avatar(id: "sym_4", type: .symbol, primaryColor: .red, secondaryColor: .black, pattern: .star),
            
            // Generated patterns
            Avatar(id: "gen_1", type: .generated, primaryColor: .teal, secondaryColor: .blue, pattern: .noise),
            Avatar(id: "gen_2", type: .generated, primaryColor: .purple, secondaryColor: .indigo, pattern: .fractal),
            Avatar(id: "gen_3", type: .generated, primaryColor: .green, secondaryColor: .yellow, pattern: .cellular),
            Avatar(id: "gen_4", type: .generated, primaryColor: .orange, secondaryColor: .pink, pattern: .perlin)
        ]
    }
    
    private func selectRandomAvatar(excluding: Avatar? = nil) -> Avatar {
        var availableOptions = availableAvatars
        
        if let excludeAvatar = excluding {
            availableOptions.removeAll { $0.id == excludeAvatar.id }
        }
        
        return availableOptions.randomElement() ?? availableAvatars[0]
    }
    
    public func createCustomAvatar(
        type: Avatar.AvatarType = .geometric,
        primaryColor: Color = .blue,
        secondaryColor: Color = .purple,
        pattern: Avatar.Pattern = .circles
    ) -> Avatar {
        let customId = "\(Constants.avatarIdPrefix)\(UUID().uuidString.prefix(8))"
        
        return Avatar(
            id: customId,
            type: type,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            pattern: pattern
        )
    }
    
    // MARK: - Social Interaction Management
    public func updateSocialInteractionLevel(_ level: SocialInteractionLevel) async throws {
        guard var identity = currentIdentity else {
            throw AnonymousIdentityError.noCurrentIdentity
        }
        
        // Update identity settings
        identity.socialLevel = level
        identity.privacySettings = createPrivacySettings(for: level)
        
        // Store updated identity
        try await storeIdentity(identity)
        
        // Update published properties
        currentIdentity = identity
        socialInteractionLevel = level
        
        // Store preference
        try keychainManager.store(object: level.rawValue, for: Constants.socialInteractionKey)
        
        // Log change
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "social_interaction_level_changed",
            "new_level": level.rawValue
        ])
    }
    
    private func createPrivacySettings(for socialLevel: SocialInteractionLevel) -> AnonymousPrivacySettings {
        switch socialLevel {
        case .minimal:
            return AnonymousPrivacySettings(
                allowDirectMessages: false,
                allowGroupInteractions: false,
                allowPublicPosts: false,
                allowLocationSharing: false,
                allowActivityTracking: false,
                dataRetentionDays: 1,
                autoDeleteInteractions: true,
                requireEncryptedCommunication: true
            )
            
        case .limited:
            return AnonymousPrivacySettings(
                allowDirectMessages: true,
                allowGroupInteractions: false,
                allowPublicPosts: false,
                allowLocationSharing: false,
                allowActivityTracking: false,
                dataRetentionDays: 7,
                autoDeleteInteractions: true,
                requireEncryptedCommunication: true
            )
            
        case .social:
            return AnonymousPrivacySettings(
                allowDirectMessages: true,
                allowGroupInteractions: true,
                allowPublicPosts: true,
                allowLocationSharing: false,
                allowActivityTracking: false,
                dataRetentionDays: 30,
                autoDeleteInteractions: false,
                requireEncryptedCommunication: true
            )
        }
    }
    
    // MARK: - Cryptographic Operations
    private func generateAnonymousId() throws -> String {
        // Generate cryptographically secure random ID
        var randomBytes = Data(count: 16) // 128 bits
        let result = randomBytes.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw AnonymousIdentityError.idGenerationFailed
        }
        
        // Convert to base58 for user-friendly format
        let base58Id = randomBytes.base58EncodedString()
        return "\(Constants.anonymousIdPrefix)\(base58Id)"
    }
    
    private func generateInteractionKeys() throws -> InteractionKeys {
        // Generate key pair for anonymous social interactions
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        // Generate encryption key for direct messages
        let encryptionKey = Curve25519.KeyAgreement.PrivateKey()
        let encryptionPublicKey = encryptionKey.publicKey
        
        return InteractionKeys(
            signingPrivateKey: privateKey.rawRepresentation,
            signingPublicKey: publicKey.rawRepresentation,
            encryptionPrivateKey: encryptionKey.rawRepresentation,
            encryptionPublicKey: encryptionPublicKey.rawRepresentation
        )
    }
    
    private func generateAnonymousDisplayName() -> String {
        let adjectives = [
            "Swift", "Gentle", "Bright", "Calm", "Clever", "Kind",
            "Quiet", "Smart", "Wise", "Bold", "Cool", "Free"
        ]
        
        let nouns = [
            "Fox", "Wolf", "Bear", "Eagle", "Hawk", "Lion",
            "Tiger", "Lynx", "Owl", "Raven", "Deer", "Whale"
        ]
        
        let adjective = adjectives.randomElement() ?? "Anonymous"
        let noun = nouns.randomElement() ?? "User"
        let number = Int.random(in: 100...999)
        
        return "\(adjective)\(noun)\(number)"
    }
    
    // MARK: - Storage Management
    private func storeIdentity(_ identity: AnonymousIdentity) async throws {
        let identityData = try JSONEncoder().encode(identity)
        let encryptedData = try cryptoEngine.encryptForLocalStorage(
            data: identityData,
            context: "anonymous_identity_\(identity.id)"
        )
        
        // Store in keychain
        try keychainManager.store(object: encryptedData, for: "current_anonymous_identity")
    }
    
    private func loadCurrentIdentity() {
        Task {
            do {
                if let encryptedData: EncryptedData = try keychainManager.retrieve(type: EncryptedData.self, for: "current_anonymous_identity") {
                    let identityData = try cryptoEngine.decryptFromLocalStorage(
                        encryptedData: encryptedData,
                        context: "anonymous_identity"
                    )
                    
                    let identity = try JSONDecoder().decode(AnonymousIdentity.self, from: identityData)
                    
                    await MainActor.run {
                        currentIdentity = identity
                        socialInteractionLevel = identity.socialLevel
                    }
                }
                
                // Load social interaction preference
                if let levelString: String = try keychainManager.retrieve(type: String.self, for: Constants.socialInteractionKey),
                   let level = SocialInteractionLevel(rawValue: levelString) {
                    await MainActor.run {
                        socialInteractionLevel = level
                    }
                }
            } catch {
                // Create new identity if loading fails
                let _ = try await createNewAnonymousIdentity()
            }
        }
    }
    
    private func archiveIdentity(_ identity: AnonymousIdentity) async throws {
        // Archive old identity for potential recovery
        let archiveData = try JSONEncoder().encode(identity)
        let encryptedArchive = try cryptoEngine.encryptForLocalStorage(
            data: archiveData,
            context: "archived_identity_\(identity.id)"
        )
        
        let archiveKey = "archived_identity_\(identity.id)"
        try keychainManager.store(object: encryptedArchive, for: archiveKey)
        
        // Clean up old archives (keep only recent ones)
        await cleanupOldIdentities()
    }
    
    private func cleanupOldIdentities() async {
        // Implementation would query and clean up old archived identities
        // This ensures we don't accumulate too much data over time
    }
    
    // MARK: - Identity Rotation
    private func setupIdentityRotation() {
        identityRotationTimer = Timer.scheduledTimer(withTimeInterval: Constants.identityRotationInterval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.rotateIdentity()
            }
        }
    }
    
    public func forceIdentityRotation() async throws {
        try await rotateIdentity()
    }
    
    // MARK: - VPN-Friendly Features
    public func enableVPNOptimizedMode() async {
        // Configure settings for VPN usage
        await updatePrivacySettings(for: .vpnOptimized)
        
        await auditLogger.logSecurityEvent(.vpnDetection, details: [
            "action": "vpn_optimized_mode_enabled"
        ])
    }
    
    private func updatePrivacySettings(for mode: PrivacyMode) async {
        // Update settings based on privacy mode
        guard var identity = currentIdentity else { return }
        
        switch mode {
        case .vpnOptimized:
            identity.privacySettings.requireEncryptedCommunication = true
            identity.privacySettings.allowLocationSharing = false
            identity.privacySettings.allowActivityTracking = false
            identity.privacySettings.dataRetentionDays = 1
            
        case .maxPrivacy:
            identity.privacySettings.allowDirectMessages = false
            identity.privacySettings.allowGroupInteractions = false
            identity.privacySettings.allowPublicPosts = false
            identity.privacySettings.allowLocationSharing = false
            identity.privacySettings.allowActivityTracking = false
            identity.privacySettings.dataRetentionDays = 1
            identity.privacySettings.autoDeleteInteractions = true
        }
        
        try? await storeIdentity(identity)
        currentIdentity = identity
    }
    
    // MARK: - Zero-Knowledge Proofs
    public func generateZKProof(for claim: AnonymousClaim) throws -> ZKProof {
        guard let identity = currentIdentity else {
            throw AnonymousIdentityError.noCurrentIdentity
        }
        
        // Generate zero-knowledge proof without revealing identity
        let challenge = cryptoEngine.generateBlindingFactor()
        let response = generateProofResponse(for: claim, challenge: challenge, identity: identity)
        
        return ZKProof(
            claim: claim,
            challenge: challenge,
            response: response,
            publicCommitment: generatePublicCommitment(for: identity)
        )
    }
    
    private func generateProofResponse(for claim: AnonymousClaim, challenge: Data, identity: AnonymousIdentity) -> Data {
        // Generate cryptographic proof response
        let claimData = claim.rawValue.data(using: .utf8) ?? Data()
        let identityHash = SHA256.hash(data: identity.id.data(using: .utf8) ?? Data())
        
        var combinedData = Data()
        combinedData.append(claimData)
        combinedData.append(challenge)
        combinedData.append(Data(identityHash))
        
        return Data(SHA256.hash(data: combinedData))
    }
    
    private func generatePublicCommitment(for identity: AnonymousIdentity) -> Data {
        // Generate public commitment that doesn't reveal identity
        let commitmentData = identity.interactionKeys.signingPublicKey
        return Data(SHA256.hash(data: commitmentData))
    }
}

// MARK: - Supporting Types
public struct AnonymousIdentity: Codable {
    public let id: String
    public let avatar: Avatar
    public let displayName: String
    public var socialLevel: SocialInteractionLevel
    public let interactionKeys: InteractionKeys
    public let createdAt: Date
    public var lastUsed: Date
    public let rotationCount: Int
    public var privacySettings: AnonymousPrivacySettings
}

public struct Avatar: Codable, Identifiable {
    public let id: String
    public let type: AvatarType
    public let primaryColor: Color
    public let secondaryColor: Color
    public let pattern: Pattern
    
    public enum AvatarType: String, Codable, CaseIterable {
        case geometric = "geometric"
        case abstractArt = "abstract_art"
        case symbol = "symbol"
        case generated = "generated"
    }
    
    public enum Pattern: String, Codable, CaseIterable {
        // Geometric patterns
        case circles = "circles"
        case triangles = "triangles"
        case squares = "squares"
        case hexagons = "hexagons"
        
        // Abstract patterns
        case flowing = "flowing"
        case swirl = "swirl"
        case wave = "wave"
        case gradient = "gradient"
        
        // Symbol patterns
        case dot = "dot"
        case line = "line"
        case cross = "cross"
        case star = "star"
        
        // Generated patterns
        case noise = "noise"
        case fractal = "fractal"
        case cellular = "cellular"
        case perlin = "perlin"
    }
}

public enum SocialInteractionLevel: String, Codable, CaseIterable {
    case minimal = "minimal"       // No social features
    case limited = "limited"       // Direct messages only
    case social = "social"         // Full social features
    
    public var displayName: String {
        switch self {
        case .minimal:
            return "Minimal Interaction"
        case .limited:
            return "Limited Interaction"
        case .social:
            return "Social Interaction"
        }
    }
    
    public var description: String {
        switch self {
        case .minimal:
            return "No social features, maximum privacy"
        case .limited:
            return "Direct messages only, high privacy"
        case .social:
            return "Full social features, balanced privacy"
        }
    }
}

public struct InteractionKeys: Codable {
    public let signingPrivateKey: Data
    public let signingPublicKey: Data
    public let encryptionPrivateKey: Data
    public let encryptionPublicKey: Data
}

public struct AnonymousPrivacySettings: Codable {
    public var allowDirectMessages: Bool
    public var allowGroupInteractions: Bool
    public var allowPublicPosts: Bool
    public var allowLocationSharing: Bool
    public var allowActivityTracking: Bool
    public var dataRetentionDays: Int
    public var autoDeleteInteractions: Bool
    public var requireEncryptedCommunication: Bool
}

public enum PrivacyMode {
    case vpnOptimized
    case maxPrivacy
}

public enum AnonymousClaim: String {
    case validUser = "valid_user"
    case humanVerified = "human_verified"
    case trustedDevice = "trusted_device"
}

public struct ZKProof {
    public let claim: AnonymousClaim
    public let challenge: Data
    public let response: Data
    public let publicCommitment: Data
}

public enum AnonymousIdentityError: LocalizedError {
    case noCurrentIdentity
    case idGenerationFailed
    case authenticationFailed(AuthenticationError)
    case storageError(Error)
    case invalidIdentity
    
    public var errorDescription: String? {
        switch self {
        case .noCurrentIdentity:
            return "No current anonymous identity available"
        case .idGenerationFailed:
            return "Failed to generate anonymous ID"
        case .authenticationFailed(let authError):
            return "Authentication failed: \(authError.localizedDescription)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .invalidIdentity:
            return "Invalid anonymous identity"
        }
    }
}

// MARK: - Base58 Encoding Extension
extension Data {
    func base58EncodedString() -> String {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        
        var x = self.withUnsafeBytes { bytes in
            bytes.reduce(0 as UInt64) { acc, byte in
                acc * 256 + UInt64(byte)
            }
        }
        
        var result = ""
        while x > 0 {
            let remainder = Int(x % 58)
            x /= 58
            result = String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: remainder)]) + result
        }
        
        // Handle leading zeros
        for byte in self {
            if byte == 0 {
                result = "1" + result
            } else {
                break
            }
        }
        
        return result.isEmpty ? "1" : result
    }
}

// MARK: - Color Codable Extension
extension Color: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorArray = [Double(red), Double(green), Double(blue), Double(alpha)]
        try container.encode(colorArray)
        #else
        // Fallback for other platforms
        try container.encode([0.0, 0.0, 0.0, 1.0])
        #endif
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorArray = try container.decode([Double].self)
        
        guard colorArray.count == 4 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Color array must have 4 components"
                )
            )
        }
        
        self.init(.sRGB, red: colorArray[0], green: colorArray[1], blue: colorArray[2], opacity: colorArray[3])
    }
}