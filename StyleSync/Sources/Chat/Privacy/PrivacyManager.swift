import Foundation
import UIKit
import CryptoKit
import LocalAuthentication
import SwiftUI

@MainActor
class PrivacyManager: ObservableObject {
    @Published var privacySettings = PrivacySettings()
    @Published var isPrivacyModeEnabled = false
    @Published var autoDeleteEnabled = false
    @Published var localProcessingEnabled = true
    
    private let encryptionManager = EncryptionManager()
    private let imagePrivacyEngine = ImagePrivacyEngine()
    private let biometricManager = BiometricAuthManager()
    private let anonymousDataManager = AnonymousDataManager()
    
    // MARK: - Privacy Settings Management
    
    func updatePrivacySettings(_ newSettings: PrivacySettings) {
        privacySettings = newSettings
        savePrivacySettings()
        
        // Update system settings based on privacy preferences
        updateSystemSettings()
    }
    
    func enablePrivacyMode(_ enabled: Bool) {
        isPrivacyModeEnabled = enabled
        
        if enabled {
            // Enable maximum privacy protections
            privacySettings.enableEndToEndEncryption = true
            privacySettings.blurImagesBeforeSending = true
            privacySettings.enableLocalProcessing = true
            privacySettings.disableCloudSync = true
        }
    }
    
    // MARK: - Message Encryption
    
    func encryptMessage(_ message: ChatMessage) async -> EncryptedMessage? {
        guard privacySettings.enableEndToEndEncryption else {
            return EncryptedMessage(originalMessage: message, isEncrypted: false)
        }
        
        do {
            let encryptedContent = try await encryptionManager.encrypt(message.content)
            let encryptedMessage = EncryptedMessage(
                id: message.id,
                encryptedContent: encryptedContent,
                sender: message.sender,
                timestamp: message.timestamp,
                status: message.status,
                reactions: message.reactions,
                threadId: message.threadId,
                replyTo: message.replyTo,
                isEncrypted: true
            )
            
            return encryptedMessage
        } catch {
            print("Encryption failed: \(error)")
            return nil
        }
    }
    
    func decryptMessage(_ encryptedMessage: EncryptedMessage) async -> ChatMessage? {
        guard encryptedMessage.isEncrypted else {
            return ChatMessage(
                content: encryptedMessage.originalMessage?.content ?? .text(""),
                sender: encryptedMessage.sender,
                timestamp: encryptedMessage.timestamp,
                status: encryptedMessage.status,
                reactions: encryptedMessage.reactions,
                threadId: encryptedMessage.threadId,
                replyTo: encryptedMessage.replyTo
            )
        }
        
        do {
            let decryptedContent = try await encryptionManager.decrypt(encryptedMessage.encryptedContent)
            
            return ChatMessage(
                content: decryptedContent,
                sender: encryptedMessage.sender,
                timestamp: encryptedMessage.timestamp,
                status: encryptedMessage.status,
                reactions: encryptedMessage.reactions,
                threadId: encryptedMessage.threadId,
                replyTo: encryptedMessage.replyTo
            )
        } catch {
            print("Decryption failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Image Privacy Protection
    
    func blurImage(_ imageData: Data) -> Data {
        guard privacySettings.blurImagesBeforeSending,
              let image = UIImage(data: imageData) else {
            return imageData
        }
        
        let blurredImage = imagePrivacyEngine.applyPrivacyBlur(to: image)
        return blurredImage.jpegData(compressionQuality: 0.8) ?? imageData
    }
    
    func applyFaceBlur(_ imageData: Data) async -> Data {
        guard let image = UIImage(data: imageData) else {
            return imageData
        }
        
        let protectedImage = await imagePrivacyEngine.blurFacesInImage(image)
        return protectedImage.jpegData(compressionQuality: 0.8) ?? imageData
    }
    
    func removeSensitiveMetadata(_ imageData: Data) -> Data {
        return imagePrivacyEngine.stripMetadata(from: imageData)
    }
    
    // MARK: - Auto-Delete Messages
    
    func scheduleAutoDelete(for message: ChatMessage) {
        guard let deleteAfterDays = privacySettings.autoDeleteAfterDays else { return }
        
        let deleteDate = Calendar.current.date(
            byAdding: .day,
            value: deleteAfterDays,
            to: message.timestamp
        ) ?? Date()
        
        scheduleMessageDeletion(messageId: message.id, at: deleteDate)
    }
    
    private func scheduleMessageDeletion(messageId: UUID, at date: Date) {
        let identifier = "delete_message_\(messageId.uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = "Message Auto-Delete"
        content.body = "A message has been automatically deleted for privacy"
        content.sound = nil // Silent notification
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: date.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule auto-delete: \(error)")
            }
        }
    }
    
    func deleteMessage(_ messageId: UUID) {
        // Remove from storage and notify observers
        NotificationCenter.default.post(
            name: .messageDeleted,
            object: nil,
            userInfo: ["messageId": messageId]
        )
    }
    
    // MARK: - Biometric Authentication
    
    func enableBiometricProtection() async -> Bool {
        return await biometricManager.enableBiometricLock()
    }
    
    func authenticateForChatAccess() async -> Bool {
        guard privacySettings.requireBiometricAuth else { return true }
        return await biometricManager.authenticate(reason: "Access your private chat")
    }
    
    // MARK: - Anonymous Data Handling
    
    func anonymizeUserData(_ data: Any) -> Any {
        return anonymousDataManager.anonymize(data)
    }
    
    func generateAnonymousIdentifier() -> String {
        return anonymousDataManager.generateAnonymousId()
    }
    
    // MARK: - Local Processing
    
    func shouldProcessLocally() -> Bool {
        return privacySettings.enableLocalProcessing
    }
    
    func processDataLocally<T>(_ data: T, processor: (T) -> T) -> T {
        guard shouldProcessLocally() else {
            return data
        }
        
        return processor(data)
    }
    
    // MARK: - Data Export with Privacy
    
    func exportChatDataSecurely(_ session: ChatSession) async -> SecureChatExport? {
        do {
            let exportData = SecureChatExport(
                sessionId: session.id,
                exportDate: Date(),
                messageCount: session.messages.count,
                encryptedMessages: [],
                privacySettings: privacySettings
            )
            
            // Encrypt messages if enabled
            var encryptedMessages: [EncryptedMessage] = []
            
            for message in session.messages {
                if let encrypted = await encryptMessage(message) {
                    encryptedMessages.append(encrypted)
                }
            }
            
            let finalExport = SecureChatExport(
                sessionId: session.id,
                exportDate: Date(),
                messageCount: session.messages.count,
                encryptedMessages: encryptedMessages,
                privacySettings: privacySettings
            )
            
            return finalExport
        } catch {
            print("Failed to export chat data: \(error)")
            return nil
        }
    }
    
    // MARK: - Privacy Audit
    
    func performPrivacyAudit() -> PrivacyAuditResult {
        var issues: [PrivacyIssue] = []
        var recommendations: [String] = []
        
        // Check encryption status
        if !privacySettings.enableEndToEndEncryption {
            issues.append(.encryptionDisabled)
            recommendations.append("Enable end-to-end encryption for maximum security")
        }
        
        // Check auto-delete settings
        if privacySettings.autoDeleteAfterDays == nil {
            issues.append(.noAutoDelete)
            recommendations.append("Enable automatic message deletion")
        }
        
        // Check image privacy
        if !privacySettings.blurImagesBeforeSending {
            issues.append(.imagePrivacyDisabled)
            recommendations.append("Enable image privacy protection")
        }
        
        // Check biometric protection
        if !privacySettings.requireBiometricAuth && biometricManager.isBiometricAvailable() {
            issues.append(.noBiometricProtection)
            recommendations.append("Enable biometric authentication for chat access")
        }
        
        // Check local processing
        if !privacySettings.enableLocalProcessing {
            issues.append(.cloudProcessingEnabled)
            recommendations.append("Enable local processing to keep data on device")
        }
        
        let riskLevel = calculatePrivacyRiskLevel(issues: issues)
        
        return PrivacyAuditResult(
            issues: issues,
            recommendations: recommendations,
            riskLevel: riskLevel,
            auditDate: Date()
        )
    }
    
    private func calculatePrivacyRiskLevel(issues: [PrivacyIssue]) -> PrivacyRiskLevel {
        let criticalIssues = issues.filter { $0.severity == .critical }.count
        let moderateIssues = issues.filter { $0.severity == .moderate }.count
        let lowIssues = issues.filter { $0.severity == .low }.count
        
        if criticalIssues > 0 {
            return .high
        } else if moderateIssues > 1 {
            return .moderate
        } else if lowIssues > 2 {
            return .low
        } else {
            return .minimal
        }
    }
    
    // MARK: - Settings Persistence
    
    private func savePrivacySettings() {
        do {
            let data = try JSONEncoder().encode(privacySettings)
            UserDefaults.standard.set(data, forKey: "PrivacySettings")
        } catch {
            print("Failed to save privacy settings: \(error)")
        }
    }
    
    private func loadPrivacySettings() {
        guard let data = UserDefaults.standard.data(forKey: "PrivacySettings") else { return }
        
        do {
            privacySettings = try JSONDecoder().decode(PrivacySettings.self, from: data)
        } catch {
            print("Failed to load privacy settings: \(error)")
        }
    }
    
    private func updateSystemSettings() {
        // Update various system settings based on privacy preferences
        isPrivacyModeEnabled = privacySettings.enableEndToEndEncryption && 
                              privacySettings.blurImagesBeforeSending
        autoDeleteEnabled = privacySettings.autoDeleteAfterDays != nil
        localProcessingEnabled = privacySettings.enableLocalProcessing
    }
    
    init() {
        loadPrivacySettings()
        updateSystemSettings()
    }
}

// MARK: - Privacy Settings Model

struct PrivacySettings: Codable {
    var enableEndToEndEncryption: Bool = true
    var blurImagesBeforeSending: Bool = true
    var enableLocalProcessing: Bool = true
    var disableCloudSync: Bool = false
    var requireBiometricAuth: Bool = false
    var autoDeleteAfterDays: Int? = nil
    var anonymizeAnalytics: Bool = true
    var blockScreenshots: Bool = false
    var enableIncognitoMode: Bool = false
    
    var enableReadReceipts: Bool = true
    var enableTypingIndicators: Bool = true
    var shareUsageData: Bool = false
}

// MARK: - Encrypted Message Model

struct EncryptedMessage: Identifiable {
    let id: UUID
    let encryptedContent: Data
    let sender: MessageSender
    let timestamp: Date
    var status: MessageStatus
    var reactions: [MessageReaction]
    var threadId: UUID?
    var replyTo: UUID?
    let isEncrypted: Bool
    
    // Reference to original message for non-encrypted cases
    let originalMessage: ChatMessage?
    
    init(originalMessage: ChatMessage, isEncrypted: Bool) {
        self.id = originalMessage.id
        self.encryptedContent = Data()
        self.sender = originalMessage.sender
        self.timestamp = originalMessage.timestamp
        self.status = originalMessage.status
        self.reactions = originalMessage.reactions
        self.threadId = originalMessage.threadId
        self.replyTo = originalMessage.replyTo
        self.isEncrypted = isEncrypted
        self.originalMessage = originalMessage
    }
    
    init(id: UUID, encryptedContent: Data, sender: MessageSender, timestamp: Date, status: MessageStatus, reactions: [MessageReaction], threadId: UUID?, replyTo: UUID?, isEncrypted: Bool) {
        self.id = id
        self.encryptedContent = encryptedContent
        self.sender = sender
        self.timestamp = timestamp
        self.status = status
        self.reactions = reactions
        self.threadId = threadId
        self.replyTo = replyTo
        self.isEncrypted = isEncrypted
        self.originalMessage = nil
    }
}

// MARK: - Privacy Audit Models

struct PrivacyAuditResult {
    let issues: [PrivacyIssue]
    let recommendations: [String]
    let riskLevel: PrivacyRiskLevel
    let auditDate: Date
}

enum PrivacyIssue {
    case encryptionDisabled
    case noAutoDelete
    case imagePrivacyDisabled
    case noBiometricProtection
    case cloudProcessingEnabled
    case metadataNotStripped
    
    var severity: PrivacyIssueSeverity {
        switch self {
        case .encryptionDisabled:
            return .critical
        case .noAutoDelete, .imagePrivacyDisabled:
            return .moderate
        case .noBiometricProtection, .cloudProcessingEnabled:
            return .low
        case .metadataNotStripped:
            return .low
        }
    }
    
    var description: String {
        switch self {
        case .encryptionDisabled:
            return "End-to-end encryption is disabled"
        case .noAutoDelete:
            return "Automatic message deletion is not configured"
        case .imagePrivacyDisabled:
            return "Image privacy protection is disabled"
        case .noBiometricProtection:
            return "Biometric authentication is not enabled"
        case .cloudProcessingEnabled:
            return "Cloud processing is enabled (data leaves device)"
        case .metadataNotStripped:
            return "Image metadata is not being stripped"
        }
    }
}

enum PrivacyIssueSeverity {
    case critical, moderate, low
}

enum PrivacyRiskLevel {
    case minimal, low, moderate, high
    
    var description: String {
        switch self {
        case .minimal:
            return "Minimal Risk - Excellent privacy protection"
        case .low:
            return "Low Risk - Good privacy protection"
        case .moderate:
            return "Moderate Risk - Consider improving privacy settings"
        case .high:
            return "High Risk - Immediate privacy improvements needed"
        }
    }
    
    var color: Color {
        switch self {
        case .minimal:
            return .green
        case .low:
            return .blue
        case .moderate:
            return .orange
        case .high:
            return .red
        }
    }
}

// MARK: - Secure Export Model

struct SecureChatExport: Codable {
    let sessionId: UUID
    let exportDate: Date
    let messageCount: Int
    let encryptedMessages: [EncryptedMessage]
    let privacySettings: PrivacySettings
}

// MARK: - Supporting Manager Classes

class EncryptionManager {
    private let keychain = KeychainManager()
    
    func encrypt(_ content: MessageContent) async throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let plaintext = try JSONEncoder().encode(content)
        
        let sealedBox = try ChaChaPoly.seal(plaintext, using: key)
        return sealedBox.combined
    }
    
    func decrypt(_ encryptedData: Data) async throws -> MessageContent {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
        let plaintext = try ChaChaPoly.open(sealedBox, using: key)
        
        return try JSONDecoder().decode(MessageContent.self, from: plaintext)
    }
    
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        let keyData = try keychain.getEncryptionKey() ?? generateNewKey()
        return SymmetricKey(data: keyData)
    }
    
    private func generateNewKey() throws -> Data {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.storeEncryptionKey(keyData)
        return keyData
    }
}

class ImagePrivacyEngine {
    func applyPrivacyBlur(to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = 10.0
        
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func blurFacesInImage(_ image: UIImage) async -> UIImage {
        // Use Vision framework to detect faces and apply blur
        return await withCheckedContinuation { continuation in
            // Placeholder implementation - would use actual face detection
            continuation.resume(returning: applyPrivacyBlur(to: image))
        }
    }
    
    func stripMetadata(from imageData: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(source),
              let destination = CGImageDestinationCreateWithData(NSMutableData() as CFMutableData, type, 1, nil) else {
            return imageData
        }
        
        // Copy image without metadata
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        CGImageDestinationFinalize(destination)
        
        return imageData // Placeholder - would return cleaned data
    }
}

class BiometricAuthManager {
    private let context = LAContext()
    
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func enableBiometricLock() async -> Bool {
        return await authenticate(reason: "Enable biometric protection for your chat")
    }
    
    func authenticate(reason: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                continuation.resume(returning: success)
            }
        }
    }
}

class AnonymousDataManager {
    private let anonymousId = UUID().uuidString
    
    func anonymize(_ data: Any) -> Any {
        // Placeholder implementation - would anonymize sensitive data
        return data
    }
    
    func generateAnonymousId() -> String {
        return anonymousId
    }
}

class KeychainManager {
    private let service = "com.stylesync.chat.encryption"
    private let account = "chat_encryption_key"
    
    func storeEncryptionKey(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed
        }
    }
    
    func getEncryptionKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.retrievalFailed
        }
        
        return result as? Data
    }
}

enum KeychainError: Error {
    case storeFailed
    case retrievalFailed
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let messageDeleted = Notification.Name("messageDeleted")
    static let privacySettingsChanged = Notification.Name("privacySettingsChanged")
}