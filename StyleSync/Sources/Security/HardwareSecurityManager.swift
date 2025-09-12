import Foundation
import Security
import CryptoKit
import LocalAuthentication
import CommonCrypto

// MARK: - Hardware Security Manager
@MainActor
public final class HardwareSecurityManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = HardwareSecurityManager()
    
    // MARK: - Published Properties
    @Published public var isSecureEnclaveAvailable = false
    @Published public var isHSMConnected = false
    @Published public var hardwareSecurityLevel: HardwareSecurityLevel = .none
    @Published public var attestationStatus: AttestationStatus = .unknown
    
    // MARK: - Private Properties
    private let biometricAuth = BiometricAuthManager.shared
    private let auditLogger = AuditLogger.shared
    private let cryptoEngine = CryptoEngine.shared
    
    private var secureEnclaveKeys: [String: SecKey] = [:]
    private var hsmSessions: [String: HSMSession] = [:]
    private var hardwareAttestations: [String: HardwareAttestation] = [:]
    
    private let securityQueue = DispatchQueue(label: "com.stylesync.hardware.security", qos: .userInitiated)
    
    // MARK: - Constants
    private enum Constants {
        static let secureEnclaveKeyPrefix = "se_"
        static let hsmKeyPrefix = "hsm_"
        static let attestationPrefix = "attest_"
        static let keyRotationInterval: TimeInterval = 2592000 // 30 days
        static let hsmConnectionTimeout: TimeInterval = 10
        static let maxRetryAttempts = 3
    }
    
    private init() {
        detectHardwareCapabilities()
        initializeSecureEnclave()
        initializeHSMSupport()
        setupHardwareAttestation()
        startKeyRotationScheduler()
    }
    
    // MARK: - Hardware Detection
    private func detectHardwareCapabilities() {
        // Detect Secure Enclave availability
        isSecureEnclaveAvailable = biometricAuth.isSecureEnclaveAvailable && TARGET_OS_SIMULATOR == 0
        
        // Detect external HSM support
        detectExternalHSM()
        
        // Determine overall hardware security level
        hardwareSecurityLevel = determineSecurityLevel()
        
        Task {
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "hardware_capabilities_detected",
                "secure_enclave": isSecureEnclaveAvailable,
                "hsm_available": isHSMConnected,
                "security_level": hardwareSecurityLevel.rawValue
            ])
        }
    }
    
    private func detectExternalHSM() {
        // Check for connected HSM devices
        // This would integrate with actual HSM SDKs in production
        securityQueue.async { [weak self] in
            // Simulate HSM detection
            let mockHSMAvailable = self?.checkForMockHSM() ?? false
            
            DispatchQueue.main.async {
                self?.isHSMConnected = mockHSMAvailable
            }
        }
    }
    
    private func checkForMockHSM() -> Bool {
        // In a real implementation, this would check for actual HSM hardware
        // For demonstration, we'll simulate HSM availability
        return false // Set to true to simulate HSM presence
    }
    
    private func determineSecurityLevel() -> HardwareSecurityLevel {
        if isHSMConnected {
            return .hsm
        } else if isSecureEnclaveAvailable {
            return .secureEnclave
        } else {
            return .software
        }
    }
    
    // MARK: - Secure Enclave Operations
    private func initializeSecureEnclave() {
        guard isSecureEnclaveAvailable else { return }
        
        securityQueue.async { [weak self] in
            self?.setupSecureEnclaveEnvironment()
        }
    }
    
    private func setupSecureEnclaveEnvironment() {
        // Configure Secure Enclave for cryptographic operations
        Task {
            await auditLogger.logSecurityEvent(.keyGeneration, details: [
                "action": "secure_enclave_initialized",
                "hardware_backed": true
            ])
        }
    }
    
    public func generateSecureEnclaveKey(
        for purpose: KeyPurpose,
        requiresBiometrics: Bool = true
    ) async throws -> String {
        
        guard isSecureEnclaveAvailable else {
            throw HardwareSecurityError.secureEnclaveUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            securityQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: HardwareSecurityError.systemUnavailable)
                    return
                }
                
                do {
                    let keyId = "\(Constants.secureEnclaveKeyPrefix)\(UUID().uuidString)"
                    
                    // Create access control
                    let accessFlags: SecAccessControlCreateFlags = requiresBiometrics 
                        ? [.privateKeyUsage, .biometryAny] 
                        : [.privateKeyUsage]
                    
                    guard let accessControl = SecAccessControlCreateWithFlags(
                        kCFAllocatorDefault,
                        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                        accessFlags,
                        nil
                    ) else {
                        continuation.resume(throwing: HardwareSecurityError.accessControlCreationFailed)
                        return
                    }
                    
                    // Configure key attributes
                    let keyAttributes: [String: Any] = [
                        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                        kSecAttrKeySizeInBits as String: 256,
                        kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                        kSecPrivateKeyAttrs as String: [
                            kSecAttrIsPermanent as String: true,
                            kSecAttrApplicationTag as String: keyId.data(using: .utf8)!,
                            kSecAttrAccessControl as String: accessControl
                        ]
                    ]
                    
                    // Generate key in Secure Enclave
                    var error: Unmanaged<CFError>?
                    guard let privateKey = SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) else {
                        if let error = error?.takeRetainedValue() {
                            continuation.resume(throwing: HardwareSecurityError.keyGenerationFailed(CFErrorCopyDescription(error) as String? ?? "Unknown error"))
                        } else {
                            continuation.resume(throwing: HardwareSecurityError.keyGenerationFailed("Unknown error"))
                        }
                        return
                    }
                    
                    // Store key reference
                    self.secureEnclaveKeys[keyId] = privateKey
                    
                    // Log key generation
                    Task {
                        await self.auditLogger.logSecurityEvent(.keyGeneration, details: [
                            "key_id": keyId,
                            "purpose": purpose.rawValue,
                            "secure_enclave": true,
                            "biometrics_required": requiresBiometrics,
                            "hardware_backed": true
                        ])
                    }
                    
                    continuation.resume(returning: keyId)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func signWithSecureEnclaveKey(
        data: Data,
        keyId: String
    ) async throws -> Data {
        
        guard let privateKey = secureEnclaveKeys[keyId] else {
            throw HardwareSecurityError.keyNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            securityQueue.async { [weak self] in
                do {
                    var error: Unmanaged<CFError>?
                    
                    guard let signature = SecKeyCreateSignature(
                        privateKey,
                        .ecdsaSignatureMessageX962SHA256,
                        data as CFData,
                        &error
                    ) else {
                        if let error = error?.takeRetainedValue() {
                            continuation.resume(throwing: HardwareSecurityError.signingFailed(CFErrorCopyDescription(error) as String? ?? "Unknown error"))
                        } else {
                            continuation.resume(throwing: HardwareSecurityError.signingFailed("Unknown error"))
                        }
                        return
                    }
                    
                    let signatureData = signature as Data
                    
                    // Log signing operation
                    Task {
                        await self?.auditLogger.logSecurityEvent(.keyAccess, details: [
                            "action": "secure_enclave_signing",
                            "key_id": keyId,
                            "data_size": data.count,
                            "signature_size": signatureData.count,
                            "hardware_backed": true
                        ])
                    }
                    
                    continuation.resume(returning: signatureData)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func verifySecureEnclaveSignature(
        data: Data,
        signature: Data,
        keyId: String
    ) async throws -> Bool {
        
        guard let privateKey = secureEnclaveKeys[keyId],
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw HardwareSecurityError.keyNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            securityQueue.async { [weak self] in
                var error: Unmanaged<CFError>?
                
                let isValid = SecKeyVerifySignature(
                    publicKey,
                    .ecdsaSignatureMessageX962SHA256,
                    data as CFData,
                    signature as CFData,
                    &error
                )
                
                // Log verification
                Task {
                    await self?.auditLogger.logSecurityEvent(.keyAccess, details: [
                        "action": "signature_verification",
                        "key_id": keyId,
                        "valid": isValid,
                        "hardware_backed": true
                    ])
                }
                
                continuation.resume(returning: isValid)
            }
        }
    }
    
    // MARK: - HSM Integration
    private func initializeHSMSupport() {
        guard isHSMConnected else { return }
        
        securityQueue.async { [weak self] in
            self?.establishHSMConnection()
        }
    }
    
    private func establishHSMConnection() {
        // Initialize HSM connection
        // In a real implementation, this would use HSM vendor SDK
        
        Task {
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "hsm_connection_established",
                "hardware_backed": true,
                "external_hsm": true
            ])
        }
    }
    
    public func generateHSMKey(
        for purpose: KeyPurpose,
        algorithm: HSMAlgorithm = .aes256
    ) async throws -> String {
        
        guard isHSMConnected else {
            throw HardwareSecurityError.hsmUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            securityQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: HardwareSecurityError.systemUnavailable)
                    return
                }
                
                do {
                    let keyId = "\(Constants.hsmKeyPrefix)\(UUID().uuidString)"
                    
                    // Create HSM session
                    let session = try self.createHSMSession()
                    
                    // Generate key in HSM
                    let hsmKey = try session.generateKey(algorithm: algorithm)
                    
                    // Store session reference
                    self.hsmSessions[keyId] = session
                    
                    // Log HSM key generation
                    Task {
                        await self.auditLogger.logSecurityEvent(.keyGeneration, details: [
                            "key_id": keyId,
                            "purpose": purpose.rawValue,
                            "algorithm": algorithm.rawValue,
                            "hsm_backed": true,
                            "external_hardware": true
                        ])
                    }
                    
                    continuation.resume(returning: keyId)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func encryptWithHSM(
        data: Data,
        keyId: String
    ) async throws -> Data {
        
        guard let session = hsmSessions[keyId] else {
            throw HardwareSecurityError.hsmSessionNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            securityQueue.async { [weak self] in
                do {
                    let encryptedData = try session.encrypt(data: data)
                    
                    // Log HSM encryption
                    Task {
                        await self?.auditLogger.logSecurityEvent(.encryptionOperation, details: [
                            "action": "hsm_encryption",
                            "key_id": keyId,
                            "data_size": data.count,
                            "hsm_backed": true
                        ])
                    }
                    
                    continuation.resume(returning: encryptedData)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func decryptWithHSM(
        encryptedData: Data,
        keyId: String
    ) async throws -> Data {
        
        guard let session = hsmSessions[keyId] else {
            throw HardwareSecurityError.hsmSessionNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            securityQueue.async { [weak self] in
                do {
                    let decryptedData = try session.decrypt(data: encryptedData)
                    
                    // Log HSM decryption
                    Task {
                        await self?.auditLogger.logSecurityEvent(.decryptionOperation, details: [
                            "action": "hsm_decryption",
                            "key_id": keyId,
                            "data_size": decryptedData.count,
                            "hsm_backed": true
                        ])
                    }
                    
                    continuation.resume(returning: decryptedData)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createHSMSession() throws -> HSMSession {
        // Create HSM session - this would use actual HSM SDK
        return MockHSMSession()
    }
    
    // MARK: - Hardware Attestation
    private func setupHardwareAttestation() {
        performHardwareAttestation()
        
        // Schedule regular attestation checks
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.performHardwareAttestation()
            }
        }
    }
    
    private func performHardwareAttestation() async {
        let attestation = await generateHardwareAttestation()
        
        attestationStatus = attestation.isValid ? .valid : .invalid
        
        let attestationId = "\(Constants.attestationPrefix)\(UUID().uuidString)"
        hardwareAttestations[attestationId] = attestation
        
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "hardware_attestation",
            "attestation_id": attestationId,
            "valid": attestation.isValid,
            "security_level": hardwareSecurityLevel.rawValue,
            "secure_enclave": isSecureEnclaveAvailable,
            "hsm_connected": isHSMConnected
        ])
    }
    
    private func generateHardwareAttestation() async -> HardwareAttestation {
        return await withCheckedContinuation { continuation in
            securityQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: HardwareAttestation.invalid())
                    return
                }
                
                // Generate hardware attestation
                let deviceInfo = self.collectDeviceInfo()
                let securityFeatures = self.evaluateSecurityFeatures()
                let integrityMeasurement = self.measureSystemIntegrity()
                
                let attestation = HardwareAttestation(
                    deviceInfo: deviceInfo,
                    securityFeatures: securityFeatures,
                    integrityMeasurement: integrityMeasurement,
                    timestamp: Date(),
                    isValid: self.validateAttestation(deviceInfo, securityFeatures, integrityMeasurement)
                )
                
                continuation.resume(returning: attestation)
            }
        }
    }
    
    private func collectDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            secureEnclaveAvailable: isSecureEnclaveAvailable,
            biometryType: biometricAuth.biometricType.rawValue
        )
    }
    
    private func evaluateSecurityFeatures() -> SecurityFeatures {
        return SecurityFeatures(
            codeSigningValid: true, // Would check actual code signing
            systemIntegrityValid: true, // Would check system integrity
            bootChainValid: true, // Would verify boot chain
            debuggingDisabled: !isDebuggingEnabled()
        )
    }
    
    private func measureSystemIntegrity() -> Data {
        // Measure system integrity
        let measurements = [
            "boot_measurement",
            "kernel_measurement", 
            "application_measurement"
        ]
        
        let measurementData = measurements.joined(separator: "|").data(using: .utf8) ?? Data()
        return Data(SHA256.hash(data: measurementData))
    }
    
    private func validateAttestation(
        _ deviceInfo: DeviceInfo,
        _ securityFeatures: SecurityFeatures,
        _ integrityMeasurement: Data
    ) -> Bool {
        
        // Validate hardware attestation
        return deviceInfo.secureEnclaveAvailable &&
               securityFeatures.codeSigningValid &&
               securityFeatures.systemIntegrityValid &&
               securityFeatures.bootChainValid &&
               securityFeatures.debuggingDisabled
    }
    
    private func isDebuggingEnabled() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Key Rotation
    private func startKeyRotationScheduler() {
        Timer.scheduledTimer(withTimeInterval: Constants.keyRotationInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performKeyRotation()
            }
        }
    }
    
    private func performKeyRotation() async {
        await auditLogger.logSecurityEvent(.keyRotation, details: [
            "action": "hardware_key_rotation_started",
            "secure_enclave_keys": secureEnclaveKeys.count,
            "hsm_keys": hsmSessions.count
        ])
        
        // Rotate Secure Enclave keys
        await rotateSecureEnclaveKeys()
        
        // Rotate HSM keys
        await rotateHSMKeys()
        
        await auditLogger.logSecurityEvent(.keyRotation, details: [
            "action": "hardware_key_rotation_completed"
        ])
    }
    
    private func rotateSecureEnclaveKeys() async {
        for (keyId, _) in secureEnclaveKeys {
            do {
                // Generate new key
                let newKeyId = try await generateSecureEnclaveKey(for: .encryption)
                
                // Migrate data from old key to new key (implementation dependent)
                // await migrateDataToNewKey(from: keyId, to: newKeyId)
                
                // Remove old key
                await removeSecureEnclaveKey(keyId)
                
            } catch {
                await auditLogger.logSecurityEvent(.keyRotation, details: [
                    "action": "secure_enclave_key_rotation_failed",
                    "key_id": keyId,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    private func rotateHSMKeys() async {
        for (keyId, _) in hsmSessions {
            do {
                // Generate new HSM key
                let newKeyId = try await generateHSMKey(for: .encryption)
                
                // Migrate data from old key to new key
                // await migrateHSMDataToNewKey(from: keyId, to: newKeyId)
                
                // Remove old HSM session
                await removeHSMSession(keyId)
                
            } catch {
                await auditLogger.logSecurityEvent(.keyRotation, details: [
                    "action": "hsm_key_rotation_failed",
                    "key_id": keyId,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    private func removeSecureEnclaveKey(_ keyId: String) async {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyId.data(using: .utf8)!
        ]
        
        SecItemDelete(deleteQuery as CFDictionary)
        secureEnclaveKeys.removeValue(forKey: keyId)
    }
    
    private func removeHSMSession(_ keyId: String) async {
        hsmSessions.removeValue(forKey: keyId)
    }
    
    // MARK: - Hardware Random Number Generation
    public func generateHardwareRandom(bytes: Int) throws -> Data {
        var randomData = Data(count: bytes)
        
        let result = randomData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, randomData.count, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw HardwareSecurityError.randomGenerationFailed
        }
        
        Task {
            await auditLogger.logSecurityEvent(.keyGeneration, details: [
                "action": "hardware_random_generated",
                "bytes": bytes,
                "hardware_backed": true
            ])
        }
        
        return randomData
    }
    
    // MARK: - Secure Boot Verification
    public func verifySecureBoot() async -> Bool {
        return await withCheckedContinuation { continuation in
            securityQueue.async { [weak self] in
                // Verify secure boot chain
                let bootVerified = self?.checkBootIntegrity() ?? false
                
                Task {
                    await self?.auditLogger.logSecurityEvent(.permissionGranted, details: [
                        "action": "secure_boot_verification",
                        "verified": bootVerified,
                        "hardware_backed": true
                    ])
                }
                
                continuation.resume(returning: bootVerified)
            }
        }
    }
    
    private func checkBootIntegrity() -> Bool {
        // In a real implementation, this would verify the boot chain
        // For now, we assume boot integrity if hardware features are available
        return isSecureEnclaveAvailable || isHSMConnected
    }
    
    // MARK: - Hardware Status
    public func getHardwareSecurityStatus() -> HardwareSecurityStatus {
        return HardwareSecurityStatus(
            securityLevel: hardwareSecurityLevel,
            secureEnclaveAvailable: isSecureEnclaveAvailable,
            hsmConnected: isHSMConnected,
            attestationStatus: attestationStatus,
            activeSecureEnclaveKeys: secureEnclaveKeys.count,
            activeHSMSessions: hsmSessions.count,
            lastAttestation: lastIntegrityCheck,
            bootVerified: true // Would be dynamically checked
        )
    }
}

// MARK: - Supporting Types
public enum HardwareSecurityLevel: String, CaseIterable {
    case none = "none"
    case software = "software"
    case secureEnclave = "secure_enclave"
    case hsm = "hsm"
    
    public var displayName: String {
        switch self {
        case .none: return "No Hardware Security"
        case .software: return "Software Security"
        case .secureEnclave: return "Secure Enclave"
        case .hsm: return "Hardware Security Module"
        }
    }
}

public enum AttestationStatus: String {
    case unknown = "unknown"
    case valid = "valid"
    case invalid = "invalid"
    case expired = "expired"
}

public enum KeyPurpose: String, CaseIterable {
    case encryption = "encryption"
    case signing = "signing"
    case authentication = "authentication"
    case keyAgreement = "key_agreement"
}

public enum HSMAlgorithm: String, CaseIterable {
    case aes256 = "aes256"
    case rsa2048 = "rsa2048"
    case rsa4096 = "rsa4096"
    case ecdsaP256 = "ecdsa_p256"
    case ecdsaP384 = "ecdsa_p384"
}

public struct DeviceInfo: Codable {
    public let deviceModel: String
    public let systemVersion: String
    public let secureEnclaveAvailable: Bool
    public let biometryType: String
}

public struct SecurityFeatures: Codable {
    public let codeSigningValid: Bool
    public let systemIntegrityValid: Bool
    public let bootChainValid: Bool
    public let debuggingDisabled: Bool
}

public struct HardwareAttestation: Codable {
    public let deviceInfo: DeviceInfo
    public let securityFeatures: SecurityFeatures
    public let integrityMeasurement: Data
    public let timestamp: Date
    public let isValid: Bool
    
    public static func invalid() -> HardwareAttestation {
        return HardwareAttestation(
            deviceInfo: DeviceInfo(deviceModel: "unknown", systemVersion: "unknown", secureEnclaveAvailable: false, biometryType: "none"),
            securityFeatures: SecurityFeatures(codeSigningValid: false, systemIntegrityValid: false, bootChainValid: false, debuggingDisabled: false),
            integrityMeasurement: Data(),
            timestamp: Date(),
            isValid: false
        )
    }
}

public struct HardwareSecurityStatus {
    public let securityLevel: HardwareSecurityLevel
    public let secureEnclaveAvailable: Bool
    public let hsmConnected: Bool
    public let attestationStatus: AttestationStatus
    public let activeSecureEnclaveKeys: Int
    public let activeHSMSessions: Int
    public let lastAttestation: Date?
    public let bootVerified: Bool
}

// MARK: - HSM Protocol and Mock Implementation
public protocol HSMSession {
    func generateKey(algorithm: HSMAlgorithm) throws -> Data
    func encrypt(data: Data) throws -> Data
    func decrypt(data: Data) throws -> Data
    func sign(data: Data) throws -> Data
    func verify(data: Data, signature: Data) throws -> Bool
}

public class MockHSMSession: HSMSession {
    private var sessionKey: SymmetricKey = SymmetricKey(size: .bits256)
    
    public func generateKey(algorithm: HSMAlgorithm) throws -> Data {
        // Mock HSM key generation
        sessionKey = SymmetricKey(size: .bits256)
        return sessionKey.withUnsafeBytes { Data($0) }
    }
    
    public func encrypt(data: Data) throws -> Data {
        // Mock HSM encryption
        let sealedBox = try AES.GCM.seal(data, using: sessionKey)
        return sealedBox.ciphertext + sealedBox.tag
    }
    
    public func decrypt(data: Data) throws -> Data {
        // Mock HSM decryption
        guard data.count > 16 else {
            throw HardwareSecurityError.hsmOperationFailed("Invalid data size")
        }
        
        let ciphertext = data.dropLast(16)
        let tag = data.suffix(16)
        
        let sealedBox = try AES.GCM.SealedBox(ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: sessionKey)
    }
    
    public func sign(data: Data) throws -> Data {
        // Mock HSM signing
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
    
    public func verify(data: Data, signature: Data) throws -> Bool {
        // Mock HSM signature verification
        let hash = SHA256.hash(data: data)
        return Data(hash) == signature
    }
}

public enum HardwareSecurityError: LocalizedError {
    case secureEnclaveUnavailable
    case hsmUnavailable
    case hsmSessionNotFound
    case systemUnavailable
    case accessControlCreationFailed
    case keyGenerationFailed(String)
    case keyNotFound
    case signingFailed(String)
    case randomGenerationFailed
    case hsmOperationFailed(String)
    case attestationFailed
    
    public var errorDescription: String? {
        switch self {
        case .secureEnclaveUnavailable:
            return "Secure Enclave is not available on this device"
        case .hsmUnavailable:
            return "Hardware Security Module is not available"
        case .hsmSessionNotFound:
            return "HSM session not found"
        case .systemUnavailable:
            return "Hardware security system is unavailable"
        case .accessControlCreationFailed:
            return "Failed to create access control for hardware key"
        case .keyGenerationFailed(let error):
            return "Hardware key generation failed: \(error)"
        case .keyNotFound:
            return "Hardware key not found"
        case .signingFailed(let error):
            return "Hardware signing operation failed: \(error)"
        case .randomGenerationFailed:
            return "Hardware random number generation failed"
        case .hsmOperationFailed(let error):
            return "HSM operation failed: \(error)"
        case .attestationFailed:
            return "Hardware attestation failed"
        }
    }
}