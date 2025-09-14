import Foundation
import Security
import LocalAuthentication
import CryptoKit
import CommonCrypto
import CloudKit

// MARK: - Security Vault Manager

@MainActor
class SecurityVault: ObservableObject {
    static let shared = SecurityVault()

    @Published var isUnlocked = false
    @Published var authenticationState: AuthenticationState = .locked
    @Published var encryptionStatus: EncryptionStatus = .idle
    @Published var biometricType: BiometricType = .none

    private let keychain = KeychainManager()
    private let photoHasher = PhotoHasher()
    private let cloudKitVault = CloudKitVault()
    private let panicDetector = PanicGestureDetector()

    enum AuthenticationState {
        case locked
        case authenticating
        case unlocked
        case failed(Error)
        case panicMode
    }

    enum EncryptionStatus {
        case idle
        case encrypting
        case decrypting
        case syncing
        case error(String)
    }

    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID

        var displayName: String {
            switch self {
            case .none: return "Passcode"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }

        var icon: String {
            switch self {
            case .none: return "lock.fill"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }
    }

    private init() {
        setupSecurityVault()
        detectBiometricCapabilities()
        setupPanicGesture()
    }

    // MARK: - Setup

    private func setupSecurityVault() {
        // Initialize Secure Enclave keys if needed
        initializeSecureEnclaveKeys()

        // Setup panic gesture detection
        panicDetector.onPanicTriggered = { [weak self] in
            Task { @MainActor in
                self?.triggerPanicMode()
            }
        }
    }

    private func detectBiometricCapabilities() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }

        switch context.biometryType {
        case .none:
            biometricType = .none
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        case .opticID:
            if #available(iOS 17.0, *) {
                biometricType = .opticID
            } else {
                biometricType = .faceID
            }
        @unknown default:
            biometricType = .none
        }
    }

    private func setupPanicGesture() {
        panicDetector.startMonitoring()
    }

    // MARK: - Authentication

    func authenticateUser() async throws {
        authenticationState = .authenticating
        encryptionStatus = .idle

        do {
            let success = try await performBiometricAuthentication()
            if success {
                isUnlocked = true
                authenticationState = .unlocked
                HapticManager.HapticType.success.trigger()
                SoundManager.SoundType.success.play(volume: 0.6)
            } else {
                throw SecurityError.authenticationFailed
            }
        } catch {
            authenticationState = .failed(error)
            HapticManager.HapticType.error.trigger()
            SoundManager.SoundType.error.play(volume: 0.8)
            throw error
        }
    }

    private func performBiometricAuthentication() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        context.localizedFallbackTitle = "Enter Passcode"

        let reason = "Unlock StyleSync to access your private style collection"

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch LAError.userFallback, LAError.biometryNotAvailable {
            // Fall back to passcode
            return try await performPasscodeAuthentication()
        } catch {
            throw SecurityError.biometricAuthenticationFailed(error)
        }
    }

    private func performPasscodeAuthentication() async throws -> Bool {
        let context = LAContext()
        let reason = "Enter your device passcode to unlock StyleSync"

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return result
        } catch {
            throw SecurityError.passcodeAuthenticationFailed(error)
        }
    }

    func lockVault() {
        isUnlocked = false
        authenticationState = .locked
        encryptionStatus = .idle

        // Clear sensitive data from memory
        clearSensitiveMemory()

        HapticManager.HapticType.medium.trigger()
        SoundManager.SoundType.click.play(volume: 0.5)
    }

    private func triggerPanicMode() {
        isUnlocked = false
        authenticationState = .panicMode
        encryptionStatus = .idle

        // Enhanced security measures in panic mode
        clearSensitiveMemory()
        invalidateAllSessions()

        HapticManager.HapticType.error.trigger()
        SoundManager.SoundType.error.play(volume: 0.9)

        // Auto-exit panic mode after 30 seconds
        Task {
            try await Task.sleep(nanoseconds: 30_000_000_000)
            if authenticationState == .panicMode {
                authenticationState = .locked
            }
        }
    }

    // MARK: - Secure Enclave Integration

    private func initializeSecureEnclaveKeys() {
        guard SecureEnclave.isAvailable else {
            print("Secure Enclave not available on this device")
            return
        }

        do {
            try keychain.generateSecureEnclaveKey()
        } catch {
            print("Failed to initialize Secure Enclave keys: \(error)")
        }
    }

    func encryptData(_ data: Data) async throws -> EncryptedData {
        encryptionStatus = .encrypting

        do {
            let encryptedData = try await keychain.encryptWithSecureEnclave(data)
            encryptionStatus = .idle
            return encryptedData
        } catch {
            encryptionStatus = .error("Encryption failed: \(error.localizedDescription)")
            throw error
        }
    }

    func decryptData(_ encryptedData: EncryptedData) async throws -> Data {
        encryptionStatus = .decrypting

        do {
            let decryptedData = try await keychain.decryptWithSecureEnclave(encryptedData)
            encryptionStatus = .idle
            return decryptedData
        } catch {
            encryptionStatus = .error("Decryption failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Photo Hashing & Duplicate Detection

    func generatePhotoHash(_ image: UIImage) async -> String {
        return await photoHasher.generateDNAHash(image)
    }

    func findDuplicates(in images: [UIImage]) async -> [DuplicateGroup] {
        return await photoHasher.findDuplicates(images)
    }

    // MARK: - CloudKit Encryption

    func enableCloudKitSync() async throws {
        guard isUnlocked else { throw SecurityError.vaultLocked }

        encryptionStatus = .syncing

        do {
            try await cloudKitVault.enableEncryptedSync()
            encryptionStatus = .idle
        } catch {
            encryptionStatus = .error("CloudKit sync failed: \(error.localizedDescription)")
            throw error
        }
    }

    func syncToCloud<T: Codable>(_ data: T, recordType: String) async throws {
        guard isUnlocked else { throw SecurityError.vaultLocked }

        try await cloudKitVault.syncEncrypted(data, recordType: recordType)
    }

    // MARK: - Memory Management

    private func clearSensitiveMemory() {
        // Clear any cached encryption keys
        keychain.clearCache()

        // Force garbage collection
        autoreleasepool {
            // Clear any temporary data structures
        }
    }

    private func invalidateAllSessions() {
        // Invalidate any active sessions or tokens
        UserDefaults.standard.removeObject(forKey: "activeSessionToken")
    }
}

// MARK: - Keychain Manager

private class KeychainManager {
    private let service = "com.stylesync.vault"
    private let secureEnclaveKeyTag = "com.stylesync.vault.secureenclave"

    func generateSecureEnclaveKey() throws {
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: secureEnclaveKeyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    [.privateKeyUsage, .biometryAny],
                    nil
                )!
            ]
        ]

        var error: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) != nil else {
            throw SecurityError.keyGenerationFailed(error?.takeRetainedValue())
        }
    }

    func encryptWithSecureEnclave(_ data: Data) async throws -> EncryptedData {
        guard let privateKey = getSecureEnclaveKey() else {
            throw SecurityError.keyNotFound
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecurityError.publicKeyExtractionFailed
        }

        // Use AES-GCM for data encryption with RSA for key wrapping
        let symmetricKey = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)

        // Encrypt the symmetric key with the Secure Enclave key
        let keyData = symmetricKey.withUnsafeBytes { Data($0) }

        var error: Unmanaged<CFError>?
        guard let encryptedKey = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionStandardVariableIVX963SHA256AESGCM,
            keyData as CFData,
            &error
        ) else {
            throw SecurityError.encryptionFailed(error?.takeRetainedValue())
        }

        return EncryptedData(
            encryptedContent: sealedBox.combined!,
            encryptedKey: encryptedKey as Data,
            nonce: sealedBox.nonce
        )
    }

    func decryptWithSecureEnclave(_ encryptedData: EncryptedData) async throws -> Data {
        guard let privateKey = getSecureEnclaveKey() else {
            throw SecurityError.keyNotFound
        }

        // Decrypt the symmetric key
        var error: Unmanaged<CFError>?
        guard let symmetricKeyData = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionStandardVariableIVX963SHA256AESGCM,
            encryptedData.encryptedKey as CFData,
            &error
        ) else {
            throw SecurityError.decryptionFailed(error?.takeRetainedValue())
        }

        let symmetricKey = SymmetricKey(data: symmetricKeyData as Data)

        // Decrypt the content
        let sealedBox = try AES.GCM.SealedBox(
            nonce: encryptedData.nonce,
            ciphertext: encryptedData.encryptedContent.dropLast(16),
            tag: encryptedData.encryptedContent.suffix(16)
        )

        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    private func getSecureEnclaveKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: secureEnclaveKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else { return nil }
        return (item as! SecKey)
    }

    func clearCache() {
        // Clear any cached keys or sensitive data
    }
}

// MARK: - Photo Hasher (DNA-like hashing)

private class PhotoHasher {
    private let hashQueue = DispatchQueue(label: "com.stylesync.photohash", qos: .utility)

    func generateDNAHash(_ image: UIImage) async -> String {
        return await withCheckedContinuation { continuation in
            hashQueue.async {
                let hash = self.computePerceptualHash(image)
                continuation.resume(returning: hash)
            }
        }
    }

    func findDuplicates(_ images: [UIImage]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        var processed: Set<Int> = []

        for (index, image) in images.enumerated() {
            guard !processed.contains(index) else { continue }

            let hash = await generateDNAHash(image)
            var similarImages: [UIImage] = [image]
            processed.insert(index)

            // Find similar images
            for (otherIndex, otherImage) in images.enumerated() {
                guard !processed.contains(otherIndex) else { continue }

                let otherHash = await generateDNAHash(otherImage)
                let similarity = calculateHashSimilarity(hash, otherHash)

                if similarity > 0.85 { // 85% similarity threshold
                    similarImages.append(otherImage)
                    processed.insert(otherIndex)
                }
            }

            if similarImages.count > 1 {
                groups.append(DuplicateGroup(images: similarImages, similarity: 1.0))
            }
        }

        return groups
    }

    private func computePerceptualHash(_ image: UIImage) -> String {
        // Simplified perceptual hash - in production, use a proper pHash algorithm
        guard let cgImage = image.cgImage else { return "" }

        // Resize to 8x8 for simplicity
        let size = CGSize(width: 8, height: 8)
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let data = context.data else { return "" }
        let buffer = data.bindMemory(to: UInt8.self, capacity: 64)

        // Calculate average brightness
        var sum: Int = 0
        for i in 0..<64 {
            sum += Int(buffer[i])
        }
        let average = sum / 64

        // Generate hash based on whether each pixel is above/below average
        var hash = ""
        for i in 0..<64 {
            hash += buffer[i] > average ? "1" : "0"
        }

        return hash
    }

    private func calculateHashSimilarity(_ hash1: String, _ hash2: String) -> Double {
        guard hash1.count == hash2.count else { return 0.0 }

        let matches = zip(hash1, hash2).reduce(0) { $0 + ($1.0 == $1.1 ? 1 : 0) }
        return Double(matches) / Double(hash1.count)
    }
}

// MARK: - CloudKit Vault

private class CloudKitVault {
    private let container = CKContainer.default()
    private let database: CKDatabase

    init() {
        database = container.privateCloudDatabase
    }

    func enableEncryptedSync() async throws {
        // Setup encrypted record zone
        let zone = CKRecordZone(zoneName: "StyleSyncVault")
        try await database.save(zone)
    }

    func syncEncrypted<T: Codable>(_ data: T, recordType: String) async throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)

        // Encrypt data before storing
        let encryptedData = try await SecurityVault.shared.encryptData(jsonData)
        let encryptedDataEncoded = try JSONEncoder().encode(encryptedData)

        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["encryptedData"] = encryptedDataEncoded

        try await database.save(record)
    }
}

// MARK: - Panic Gesture Detector

private class PanicGestureDetector {
    var onPanicTriggered: (() -> Void)?
    private var shakeDetectionEnabled = false

    func startMonitoring() {
        shakeDetectionEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceShaken),
            name: UIDevice.deviceDidShakeNotification,
            object: nil
        )
    }

    @objc private func deviceShaken() {
        guard shakeDetectionEnabled else { return }
        onPanicTriggered?()
    }

    func stopMonitoring() {
        shakeDetectionEnabled = false
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Data Structures

struct EncryptedData: Codable {
    let encryptedContent: Data
    let encryptedKey: Data
    let nonce: AES.GCM.Nonce

    init(encryptedContent: Data, encryptedKey: Data, nonce: AES.GCM.Nonce) {
        self.encryptedContent = encryptedContent
        self.encryptedKey = encryptedKey
        self.nonce = nonce
    }
}

struct DuplicateGroup {
    let images: [UIImage]
    let similarity: Double
}

// MARK: - Security Errors

enum SecurityError: LocalizedError {
    case vaultLocked
    case authenticationFailed
    case biometricAuthenticationFailed(Error)
    case passcodeAuthenticationFailed(Error)
    case keyGenerationFailed(CFError?)
    case keyNotFound
    case publicKeyExtractionFailed
    case encryptionFailed(CFError?)
    case decryptionFailed(CFError?)

    var errorDescription: String? {
        switch self {
        case .vaultLocked:
            return "Security vault is locked"
        case .authenticationFailed:
            return "Authentication failed"
        case .biometricAuthenticationFailed(let error):
            return "Biometric authentication failed: \(error.localizedDescription)"
        case .passcodeAuthenticationFailed(let error):
            return "Passcode authentication failed: \(error.localizedDescription)"
        case .keyGenerationFailed(let error):
            return "Key generation failed: \(error?.localizedDescription ?? "Unknown error")"
        case .keyNotFound:
            return "Security key not found"
        case .publicKeyExtractionFailed:
            return "Failed to extract public key"
        case .encryptionFailed(let error):
            return "Encryption failed: \(error?.localizedDescription ?? "Unknown error")"
        case .decryptionFailed(let error):
            return "Decryption failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

// MARK: - Secure Enclave Helper

private class SecureEnclave {
    static var isAvailable: Bool {
        return TARGET_OS_SIMULATOR == 0 &&
               SecKeyCreateRandomKey([
                   kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                   kSecAttrKeySizeInBits: 256,
                   kSecAttrTokenID: kSecAttrTokenIDSecureEnclave
               ] as CFDictionary, nil) != nil
    }
}

// MARK: - Device Shake Extension

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

#Preview {
    VStack {
        Text("Security Vault Preview")
            .font(.title)
        Text("This preview shows the SecurityVault service structure")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}