import Foundation
import SwiftUI
import CryptoKit
import LocalAuthentication
import Photos
import PhotosUI

@MainActor
public final class SecurePhotoVault: ObservableObject {

    // MARK: - Singleton
    public static let shared = SecurePhotoVault()

    // MARK: - Published Properties
    @Published public var isVaultLocked = true
    @Published public var vaultAccess: VaultAccess = .denied
    @Published public var encryptedPhotos: [SecurePhoto] = []
    @Published public var decoyPhotos: [SecurePhoto] = []
    @Published public var isDecoyMode = false
    @Published public var panicModeActive = false
    @Published public var intrusionAttempts: [IntrusionAttempt] = []
    @Published public var biometricLockEnabled = true
    @Published public var timeBasedLockEnabled = false
    @Published public var timeLockDuration: TimeInterval = 3600 // 1 hour
    @Published public var timeLockExpiry: Date?

    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let biometricAuth = BiometricAuthManager.shared
    private let auditLogger = AuditLogger.shared
    private let fileManager = FileManager.default
    private let vaultQueue = DispatchQueue(label: "com.stylesync.photo.vault", qos: .userInitiated)

    // MARK: - Constants
    private enum Constants {
        static let vaultDirectoryName = "SecurePhotoVault"
        static let decoyDirectoryName = "DecoyPhotoVault"
        static let metadataFileName = "vault_metadata.encrypted"
        static let intrusionLogFileName = "intrusion_log.encrypted"
        static let maxIntrusionAttempts = 5
        static let panicDeleteTimeLimit: TimeInterval = 10.0
        static let thumbnailSize = CGSize(width: 150, height: 150)
    }

    // MARK: - Initialization
    private init() {
        Task {
            await initializeVault()
        }
    }

    private func initializeVault() async {
        do {
            try await createVaultDirectories()
            await loadVaultMetadata()
            await checkTimeLockStatus()
            await loadEncryptedPhotos()

            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "photo_vault_initialized",
                "biometric_enabled": biometricLockEnabled,
                "time_lock_enabled": timeBasedLockEnabled
            ])
        } catch {
            await auditLogger.logSecurityEvent(.suspiciousBiometricActivity, details: [
                "action": "photo_vault_initialization_failed",
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Vault Setup and Management
    private func createVaultDirectories() async throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let vaultURL = documentsPath.appendingPathComponent(Constants.vaultDirectoryName)
        let decoyURL = documentsPath.appendingPathComponent(Constants.decoyDirectoryName)

        try fileManager.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: decoyURL, withIntermediateDirectories: true)

        // Set security attributes
        try await setSecurityAttributes(for: vaultURL)
        try await setSecurityAttributes(for: decoyURL)
    }

    private func setSecurityAttributes(for url: URL) async throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try url.setResourceValues(resourceValues)

        // Set file protection level to complete unless open
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUnlessOpen
        ]
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
    }

    // MARK: - Biometric Authentication
    public func authenticateWithBiometrics(reason: String = "Access secure photo vault") async -> Bool {
        guard biometricLockEnabled else { return true }

        let result = await biometricAuth.authenticateUser(reason: reason)

        switch result {
        case .success:
            vaultAccess = .granted
            isVaultLocked = false
            await resetIntrusionCounter()

            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "vault_biometric_auth_success",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])

            return true

        case .failure(let error):
            await handleAuthenticationFailure(error: error)
            return false
        }
    }

    private func handleAuthenticationFailure(error: BiometricAuthError) async {
        let attempt = IntrusionAttempt(
            timestamp: Date(),
            type: .biometricFailure,
            details: error.localizedDescription
        )

        intrusionAttempts.append(attempt)

        await auditLogger.logSecurityEvent(.suspiciousBiometricActivity, details: [
            "action": "vault_auth_failure",
            "error": error.localizedDescription,
            "attempt_count": intrusionAttempts.count
        ])

        if intrusionAttempts.count >= Constants.maxIntrusionAttempts {
            await triggerIntrusionResponse()
        }

        await saveIntrusionLog()
    }

    private func triggerIntrusionResponse() async {
        await auditLogger.logSecurityEvent(.emergencyRecovery, details: [
            "action": "intrusion_response_triggered",
            "attempt_count": intrusionAttempts.count
        ])

        // Optional: Hide real vault and show decoy
        isDecoyMode = true

        // Optional: Notify security contacts
        await notifySecurityContacts()

        // Lock vault for extended period
        await lockVaultExtended()
    }

    // MARK: - Time-Based Locks
    public func setTimeLock(duration: TimeInterval) async {
        timeBasedLockEnabled = true
        timeLockDuration = duration
        timeLockExpiry = Date().addingTimeInterval(duration)
        isVaultLocked = true
        vaultAccess = .timeLocked

        await saveVaultMetadata()

        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "time_lock_activated",
            "duration": duration,
            "expiry": ISO8601DateFormatter().string(from: timeLockExpiry!)
        ])
    }

    private func checkTimeLockStatus() async {
        guard let expiry = timeLockExpiry, timeBasedLockEnabled else { return }

        if Date() < expiry {
            isVaultLocked = true
            vaultAccess = .timeLocked
        } else {
            timeBasedLockEnabled = false
            timeLockExpiry = nil
            await saveVaultMetadata()
        }
    }

    // MARK: - Photo Management
    public func importPhoto(_ image: UIImage, metadata: PhotoMetadata? = nil) async throws -> SecurePhoto {
        guard vaultAccess == .granted else {
            throw VaultError.accessDenied
        }

        let photoId = UUID()
        let timestamp = Date()

        // Create encrypted photo data
        let photoData = image.jpegData(compressionQuality: 0.9) ?? Data()
        let encryptedData = try await cryptoEngine.encryptData(photoData)

        // Create encrypted thumbnail
        let thumbnail = await createThumbnail(from: image)
        let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) ?? Data()
        let encryptedThumbnail = try await cryptoEngine.encryptData(thumbnailData)

        // Create secure photo object
        let securePhoto = SecurePhoto(
            id: photoId,
            filename: "photo_\(photoId.uuidString).encrypted",
            originalSize: photoData.count,
            encryptedSize: encryptedData.count,
            thumbnailSize: thumbnailData.count,
            createdAt: timestamp,
            importedAt: timestamp,
            metadata: metadata,
            isDecoy: isDecoyMode
        )

        // Save encrypted photo to disk
        try await saveEncryptedPhoto(securePhoto, data: encryptedData, thumbnail: encryptedThumbnail)

        // Add to appropriate collection
        if isDecoyMode {
            decoyPhotos.append(securePhoto)
        } else {
            encryptedPhotos.append(securePhoto)
        }

        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "photo_imported",
            "photo_id": photoId.uuidString,
            "is_decoy": isDecoyMode,
            "size": photoData.count
        ])

        return securePhoto
    }

    public func importFromPhotoLibrary(assets: [PHAsset]) async throws -> [SecurePhoto] {
        guard vaultAccess == .granted else {
            throw VaultError.accessDenied
        }

        var importedPhotos: [SecurePhoto] = []
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat

        for asset in assets {
            await withCheckedContinuation { continuation in
                imageManager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    if let image = image {
                        Task {
                            do {
                                let metadata = PhotoMetadata.from(asset: asset)
                                let securePhoto = try await self.importPhoto(image, metadata: metadata)
                                importedPhotos.append(securePhoto)
                            } catch {
                                await self.auditLogger.logSecurityEvent(.permissionDenied, details: [
                                    "action": "photo_import_failed",
                                    "error": error.localizedDescription
                                ])
                            }
                        }
                    }
                    continuation.resume()
                }
            }
        }

        return importedPhotos
    }

    public func retrievePhoto(_ securePhoto: SecurePhoto) async throws -> UIImage {
        guard vaultAccess == .granted else {
            throw VaultError.accessDenied
        }

        let photoURL = getPhotoURL(for: securePhoto)
        let encryptedData = try Data(contentsOf: photoURL)
        let decryptedData = try await cryptoEngine.decryptData(encryptedData)

        guard let image = UIImage(data: decryptedData) else {
            throw VaultError.corruptedData
        }

        await auditLogger.logSecurityEvent(.dataAccessed, details: [
            "action": "photo_retrieved",
            "photo_id": securePhoto.id.uuidString
        ])

        return image
    }

    public func retrieveThumbnail(_ securePhoto: SecurePhoto) async throws -> UIImage {
        let thumbnailURL = getThumbnailURL(for: securePhoto)
        let encryptedData = try Data(contentsOf: thumbnailURL)
        let decryptedData = try await cryptoEngine.decryptData(encryptedData)

        guard let image = UIImage(data: decryptedData) else {
            throw VaultError.corruptedData
        }

        return image
    }

    public func deletePhoto(_ securePhoto: SecurePhoto) async throws {
        guard vaultAccess == .granted else {
            throw VaultError.accessDenied
        }

        // Remove from memory
        encryptedPhotos.removeAll { $0.id == securePhoto.id }
        decoyPhotos.removeAll { $0.id == securePhoto.id }

        // Secure deletion from disk
        try await secureDeletePhoto(securePhoto)

        await auditLogger.logSecurityEvent(.dataDeleted, details: [
            "action": "photo_deleted",
            "photo_id": securePhoto.id.uuidString
        ])
    }

    // MARK: - Panic Mode
    public func activatePanicMode() async {
        panicModeActive = true

        await auditLogger.logSecurityEvent(.emergencyRecovery, details: [
            "action": "panic_mode_activated",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Start panic deletion timer
        Task {
            try await Task.sleep(nanoseconds: UInt64(Constants.panicDeleteTimeLimit * 1_000_000_000))
            if panicModeActive {
                await executePanicDeletion()
            }
        }
    }

    public func cancelPanicMode() async -> Bool {
        guard panicModeActive else { return false }

        // Require biometric authentication to cancel
        let authenticated = await authenticateWithBiometrics(reason: "Cancel panic deletion")

        if authenticated {
            panicModeActive = false
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "panic_mode_cancelled"
            ])
            return true
        }

        return false
    }

    private func executePanicDeletion() async {
        await auditLogger.logSecurityEvent(.dataDeleted, details: [
            "action": "panic_deletion_executed",
            "photo_count": encryptedPhotos.count
        ])

        // Secure delete all photos
        for photo in encryptedPhotos {
            try? await secureDeletePhoto(photo)
        }

        // Clear collections
        encryptedPhotos.removeAll()

        // Clear metadata
        await clearVaultMetadata()

        panicModeActive = false
    }

    // MARK: - Secure Sharing
    public func createSecureShareLink(_ securePhoto: SecurePhoto, expiresIn: TimeInterval) async throws -> SecureShareLink {
        guard vaultAccess == .granted else {
            throw VaultError.accessDenied
        }

        let shareId = UUID()
        let shareKey = SymmetricKey(size: .bits256)
        let expiryDate = Date().addingTimeInterval(expiresIn)

        // Encrypt photo with temporary key
        let image = try await retrievePhoto(securePhoto)
        let imageData = image.jpegData(compressionQuality: 0.9) ?? Data()
        let encryptedShare = try AES.GCM.seal(imageData, using: shareKey)

        let shareLink = SecureShareLink(
            id: shareId,
            photoId: securePhoto.id,
            shareKey: shareKey,
            encryptedData: encryptedShare,
            expiresAt: expiryDate,
            createdAt: Date()
        )

        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "secure_share_created",
            "photo_id": securePhoto.id.uuidString,
            "share_id": shareId.uuidString,
            "expires_at": ISO8601DateFormatter().string(from: expiryDate)
        ])

        return shareLink
    }

    // MARK: - Helper Methods
    private func createThumbnail(from image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnailImage = image.preparingThumbnail(of: Constants.thumbnailSize) ?? image
                continuation.resume(returning: thumbnailImage)
            }
        }
    }

    private func saveEncryptedPhoto(
        _ securePhoto: SecurePhoto,
        data: Data,
        thumbnail: Data
    ) async throws {
        let vaultDirectory = getVaultDirectory(isDecoy: securePhoto.isDecoy)
        let photoURL = vaultDirectory.appendingPathComponent(securePhoto.filename)
        let thumbnailURL = vaultDirectory.appendingPathComponent("thumb_\(securePhoto.filename)")

        try data.write(to: photoURL)
        try thumbnail.write(to: thumbnailURL)

        // Set security attributes
        try await setSecurityAttributes(for: photoURL)
        try await setSecurityAttributes(for: thumbnailURL)
    }

    private func secureDeletePhoto(_ securePhoto: SecurePhoto) async throws {
        let photoURL = getPhotoURL(for: securePhoto)
        let thumbnailURL = getThumbnailURL(for: securePhoto)

        // Overwrite file with random data before deletion
        try await secureDeleteFile(at: photoURL)
        try await secureDeleteFile(at: thumbnailURL)
    }

    private func secureDeleteFile(at url: URL) async throws {
        let fileSize = try fileManager.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0

        // Overwrite with random data multiple times
        for _ in 0..<3 {
            let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
            try randomData.write(to: url)
        }

        // Finally delete the file
        try fileManager.removeItem(at: url)
    }

    private func getVaultDirectory(isDecoy: Bool) -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directoryName = isDecoy ? Constants.decoyDirectoryName : Constants.vaultDirectoryName
        return documentsPath.appendingPathComponent(directoryName)
    }

    private func getPhotoURL(for securePhoto: SecurePhoto) -> URL {
        let vaultDirectory = getVaultDirectory(isDecoy: securePhoto.isDecoy)
        return vaultDirectory.appendingPathComponent(securePhoto.filename)
    }

    private func getThumbnailURL(for securePhoto: SecurePhoto) -> URL {
        let vaultDirectory = getVaultDirectory(isDecoy: securePhoto.isDecoy)
        return vaultDirectory.appendingPathComponent("thumb_\(securePhoto.filename)")
    }

    // MARK: - Metadata Management
    private func loadVaultMetadata() async {
        // Implementation for loading encrypted vault metadata
    }

    private func saveVaultMetadata() async {
        // Implementation for saving encrypted vault metadata
    }

    private func clearVaultMetadata() async {
        // Implementation for clearing vault metadata
    }

    private func loadEncryptedPhotos() async {
        // Implementation for loading photo metadata from encrypted storage
    }

    private func saveIntrusionLog() async {
        // Implementation for saving intrusion attempts log
    }

    private func resetIntrusionCounter() async {
        intrusionAttempts.removeAll()
        await saveIntrusionLog()
    }

    private func notifySecurityContacts() async {
        // Implementation for notifying security contacts
    }

    private func lockVaultExtended() async {
        await setTimeLock(duration: 24 * 3600) // Lock for 24 hours
    }

    // MARK: - Public Utility Methods
    public func lockVault() async {
        isVaultLocked = true
        vaultAccess = .denied

        await auditLogger.logSecurityEvent(.permissionDenied, details: [
            "action": "vault_locked_manually"
        ])
    }

    public func getVaultStatistics() -> VaultStatistics {
        return VaultStatistics(
            totalPhotos: encryptedPhotos.count,
            decoyPhotos: decoyPhotos.count,
            totalSize: encryptedPhotos.reduce(0) { $0 + $1.originalSize },
            lastAccessed: Date(), // Would track actual last access
            intrusionAttempts: intrusionAttempts.count,
            isTimeLocked: timeBasedLockEnabled
        )
    }
}

// MARK: - Supporting Types

public struct SecurePhoto: Identifiable, Codable {
    public let id: UUID
    public let filename: String
    public let originalSize: Int
    public let encryptedSize: Int
    public let thumbnailSize: Int
    public let createdAt: Date
    public let importedAt: Date
    public let metadata: PhotoMetadata?
    public let isDecoy: Bool
}

public struct PhotoMetadata: Codable {
    public let location: CLLocation?
    public let cameraMake: String?
    public let cameraModel: String?
    public let lensModel: String?
    public let focalLength: Double?
    public let aperture: Double?
    public let shutterSpeed: Double?
    public let iso: Int?
    public let timestamp: Date?

    public static func from(asset: PHAsset) -> PhotoMetadata {
        return PhotoMetadata(
            location: asset.location,
            cameraMake: nil,
            cameraModel: nil,
            lensModel: nil,
            focalLength: nil,
            aperture: nil,
            shutterSpeed: nil,
            iso: nil,
            timestamp: asset.creationDate
        )
    }
}

public struct IntrusionAttempt: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let type: AttemptType
    public let details: String

    public enum AttemptType: String, CaseIterable {
        case biometricFailure = "biometric_failure"
        case incorrectPassword = "incorrect_password"
        case bruteForce = "brute_force"
        case unauthorizedAccess = "unauthorized_access"
    }
}

public struct SecureShareLink: Identifiable {
    public let id: UUID
    public let photoId: UUID
    public let shareKey: SymmetricKey
    public let encryptedData: AES.GCM.SealedBox
    public let expiresAt: Date
    public let createdAt: Date

    public var isExpired: Bool {
        Date() > expiresAt
    }
}

public struct VaultStatistics {
    public let totalPhotos: Int
    public let decoyPhotos: Int
    public let totalSize: Int
    public let lastAccessed: Date
    public let intrusionAttempts: Int
    public let isTimeLocked: Bool
}

public enum VaultAccess: String, CaseIterable {
    case denied = "denied"
    case granted = "granted"
    case timeLocked = "time_locked"
    case emergencyLocked = "emergency_locked"
}

public enum VaultError: Error, LocalizedError {
    case accessDenied
    case biometricUnavailable
    case encryptionFailed
    case decryptionFailed
    case corruptedData
    case fileNotFound
    case insufficientStorage

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to vault denied"
        case .biometricUnavailable:
            return "Biometric authentication unavailable"
        case .encryptionFailed:
            return "Failed to encrypt photo"
        case .decryptionFailed:
            return "Failed to decrypt photo"
        case .corruptedData:
            return "Photo data is corrupted"
        case .fileNotFound:
            return "Photo file not found"
        case .insufficientStorage:
            return "Insufficient storage space"
        }
    }
}