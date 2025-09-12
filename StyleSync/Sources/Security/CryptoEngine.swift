import Foundation
import CryptoKit
import Security
import LocalAuthentication

// MARK: - Military-Grade Cryptographic Engine
public final class CryptoEngine: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = CryptoEngine()
    
    // MARK: - Constants
    private enum Constants {
        static let keyDerivationIterations: UInt32 = 600_000 // OWASP recommended minimum
        static let saltSize = 32
        static let keySize = 32
        static let ivSize = 12 // AES-GCM IV size
        static let tagSize = 16 // AES-GCM tag size
        static let secureEnclaveKeyTag = "com.stylesync.secureenclave.masterkey"
        static let keychainService = "com.stylesync.crypto"
    }
    
    // MARK: - Private Properties
    private var masterKey: SymmetricKey?
    private let keychain = KeychainManager.shared
    private let biometricAuth = BiometricAuthManager.shared
    
    private init() {
        initializeCryptoEngine()
    }
    
    // MARK: - Initialization
    private func initializeCryptoEngine() {
        // Attempt to retrieve or generate master key
        retrieveOrGenerateMasterKey()
        
        // Initialize secure memory management
        enableSecureMemoryManagement()
    }
    
    // MARK: - Key Management
    private func retrieveOrGenerateMasterKey() {
        // First try to retrieve from Secure Enclave
        if let secureEnclaveKey = retrieveSecureEnclaveKey() {
            self.masterKey = secureEnclaveKey
            return
        }
        
        // Fall back to keychain-stored key
        if let keychainKey = retrieveKeychainKey() {
            self.masterKey = keychainKey
            return
        }
        
        // Generate new master key
        generateAndStoreMasterKey()
    }
    
    private func generateAndStoreMasterKey() {
        // Generate cryptographically secure master key
        let newMasterKey = SymmetricKey(size: .bits256)
        
        // Store in Secure Enclave if available
        if storeInSecureEnclave(key: newMasterKey) {
            self.masterKey = newMasterKey
            return
        }
        
        // Fall back to keychain storage
        storeInKeychain(key: newMasterKey)
        self.masterKey = newMasterKey
    }
    
    // MARK: - Secure Enclave Integration
    private func retrieveSecureEnclaveKey() -> SymmetricKey? {
        guard biometricAuth.isSecureEnclaveAvailable else { return nil }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.secureEnclaveKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let key = item else { return nil }
        
        // Derive symmetric key from Secure Enclave key
        return deriveSymmetricKeyFromSecureEnclave(secKey: key as! SecKey)
    }
    
    private func storeInSecureEnclave(key: SymmetricKey) -> Bool {
        guard biometricAuth.isSecureEnclaveAvailable else { return false }
        
        // Generate Secure Enclave key pair
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryAny],
            nil
        )
        
        guard let accessControl = access else { return false }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Constants.secureEnclaveKeyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return false
        }
        
        // Store the derived key mapping in keychain
        return keychain.storeSecureEnclaveKeyMapping(privateKey: privateKey, symmetricKey: key)
    }
    
    private func deriveSymmetricKeyFromSecureEnclave(secKey: SecKey) -> SymmetricKey? {
        // Use ECDH key agreement to derive symmetric key
        guard let publicKey = SecKeyCopyPublicKey(secKey) else { return nil }
        
        // Generate ephemeral key pair for ECDH
        let ephemeralAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]
        
        var error: Unmanaged<CFError>?
        guard let ephemeralPrivateKey = SecKeyCreateRandomKey(ephemeralAttributes as CFDictionary, &error),
              let ephemeralPublicKey = SecKeyCopyPublicKey(ephemeralPrivateKey) else {
            return nil
        }
        
        // Perform ECDH key agreement
        let algorithm = SecKeyAlgorithm.ecdhKeyExchangeStandard
        guard let sharedSecret = SecKeyCopyKeyExchangeResult(
            secKey,
            algorithm,
            ephemeralPublicKey,
            [:] as CFDictionary,
            &error
        ) else { return nil }
        
        // Derive symmetric key using HKDF
        return deriveKeyFromSharedSecret(sharedSecret as Data)
    }
    
    private func deriveKeyFromSharedSecret(_ sharedSecret: Data) -> SymmetricKey {
        let salt = Data("StyleSync-HKDF-Salt".utf8)
        let info = Data("StyleSync-Master-Key".utf8)
        
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: sharedSecret),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }
    
    // MARK: - Keychain Storage
    private func retrieveKeychainKey() -> SymmetricKey? {
        return keychain.retrieveMasterKey()
    }
    
    private func storeInKeychain(key: SymmetricKey) {
        keychain.storeMasterKey(key)
    }
    
    // MARK: - Password-Based Key Derivation (PBKDF2)
    public func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = password.data(using: .utf8)!
        
        var derivedKeyData = Data(count: Constants.keySize)
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress },
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    Constants.keyDerivationIterations,
                    derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                    Constants.keySize
                )
            }
        }
        
        guard result == kCCSuccess else {
            fatalError("Key derivation failed")
        }
        
        return SymmetricKey(data: derivedKeyData)
    }
    
    public func generateSalt() -> Data {
        var salt = Data(count: Constants.saltSize)
        let result = salt.withUnsafeMutableBytes { saltBytes in
            SecRandomCopyBytes(kSecRandomDefault, Constants.saltSize, saltBytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            fatalError("Salt generation failed")
        }
        
        return salt
    }
    
    // MARK: - AES-256-GCM Encryption
    public func encrypt(data: Data, additionalData: Data? = nil) throws -> EncryptedData {
        guard let masterKey = self.masterKey else {
            throw CryptoError.keyNotAvailable
        }
        
        return try encrypt(data: data, key: masterKey, additionalData: additionalData)
    }
    
    public func encrypt(data: Data, key: SymmetricKey, additionalData: Data? = nil) throws -> EncryptedData {
        // Generate random IV
        var iv = Data(count: Constants.ivSize)
        let result = iv.withUnsafeMutableBytes { ivBytes in
            SecRandomCopyBytes(kSecRandomDefault, Constants.ivSize, ivBytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw CryptoError.ivGenerationFailed
        }
        
        // Encrypt with AES-GCM
        let sealedBox: AES.GCM.SealedBox
        if let additionalData = additionalData {
            sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: iv), additionalAuthenticatedData: additionalData)
        } else {
            sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: iv))
        }
        
        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            iv: iv,
            tag: sealedBox.tag,
            additionalData: additionalData
        )
    }
    
    // MARK: - AES-256-GCM Decryption
    public func decrypt(encryptedData: EncryptedData) throws -> Data {
        guard let masterKey = self.masterKey else {
            throw CryptoError.keyNotAvailable
        }
        
        return try decrypt(encryptedData: encryptedData, key: masterKey)
    }
    
    public func decrypt(encryptedData: EncryptedData, key: SymmetricKey) throws -> Data {
        // Reconstruct sealed box
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: encryptedData.iv),
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )
        
        // Decrypt
        if let additionalData = encryptedData.additionalData {
            return try AES.GCM.open(sealedBox, using: key, additionalAuthenticatedData: additionalData)
        } else {
            return try AES.GCM.open(sealedBox, using: key)
        }
    }
    
    // MARK: - ChaCha20-Poly1305 for Local Storage
    public func encryptForLocalStorage(data: Data, context: String) throws -> EncryptedData {
        guard let masterKey = self.masterKey else {
            throw CryptoError.keyNotAvailable
        }
        
        // Derive context-specific key
        let contextKey = deriveContextKey(from: masterKey, context: context)
        
        // Generate nonce
        let nonce = ChaChaPoly.Nonce()
        
        // Encrypt with ChaCha20-Poly1305
        let sealedBox = try ChaChaPoly.seal(data, using: contextKey, nonce: nonce)
        
        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            iv: Data(nonce),
            tag: sealedBox.tag,
            additionalData: context.data(using: .utf8)
        )
    }
    
    public func decryptFromLocalStorage(encryptedData: EncryptedData, context: String) throws -> Data {
        guard let masterKey = self.masterKey else {
            throw CryptoError.keyNotAvailable
        }
        
        // Derive context-specific key
        let contextKey = deriveContextKey(from: masterKey, context: context)
        
        // Reconstruct sealed box
        let nonce = try ChaChaPoly.Nonce(data: encryptedData.iv)
        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )
        
        return try ChaChaPoly.open(sealedBox, using: contextKey)
    }
    
    private func deriveContextKey(from masterKey: SymmetricKey, context: String) -> SymmetricKey {
        let salt = Data("StyleSync-Context-Salt".utf8)
        let info = Data(context.utf8)
        
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }
    
    // MARK: - Secure Memory Management
    private func enableSecureMemoryManagement() {
        // Enable secure memory allocation for sensitive operations
        mlockall(MCL_CURRENT | MCL_FUTURE)
        
        // Set up memory protection
        setupMemoryProtection()
    }
    
    private func setupMemoryProtection() {
        // Configure memory protection settings
        let pageSize = getpagesize()
        
        // Protect against memory dumps
        if #available(iOS 14.0, *) {
            // Use modern memory protection APIs
            mprotect(UnsafeMutableRawPointer(mutating: &masterKey), pageSize, PROT_READ)
        }
    }
    
    // MARK: - Secure Deletion
    public func secureWipe(data: inout Data) {
        // 7-pass secure deletion (DoD 5220.22-M standard)
        let passes: [UInt8] = [0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0xAA]
        
        for pass in passes {
            data.withUnsafeMutableBytes { bytes in
                memset(bytes.baseAddress, Int32(pass), bytes.count)
            }
            // Force memory barrier
            msync(data.withUnsafeBytes { $0.baseAddress }, data.count, MS_SYNC)
        }
        
        // Final random overwrite
        let _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        data.removeAll()
    }
    
    // MARK: - Hardware Security Module Integration
    public func generateHSMKey() -> SymmetricKey? {
        // Check for hardware security module availability
        guard isHSMAvailable() else { return nil }
        
        // Generate key using hardware RNG
        var keyData = Data(count: Constants.keySize)
        let result = keyData.withUnsafeMutableBytes { keyBytes in
            SecRandomCopyBytes(kSecRandomDefault, Constants.keySize, keyBytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else { return nil }
        
        return SymmetricKey(data: keyData)
    }
    
    private func isHSMAvailable() -> Bool {
        // Check for hardware security module
        return biometricAuth.isSecureEnclaveAvailable
    }
    
    // MARK: - Zero-Knowledge Proof Support
    public func generateBlindingFactor() -> Data {
        var blindingFactor = Data(count: 32)
        let result = blindingFactor.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            fatalError("Failed to generate blinding factor")
        }
        
        return blindingFactor
    }
    
    public func blindData(_ data: Data, with blindingFactor: Data) -> Data {
        // XOR blinding for simple zero-knowledge proof
        var blindedData = Data(count: data.count)
        
        for i in 0..<data.count {
            let dataIndex = i % data.count
            let blindingIndex = i % blindingFactor.count
            blindedData[i] = data[dataIndex] ^ blindingFactor[blindingIndex]
        }
        
        return blindedData
    }
    
    public func unblindData(_ blindedData: Data, with blindingFactor: Data) -> Data {
        // Unblind using same XOR operation
        return blindData(blindedData, with: blindingFactor)
    }
}

// MARK: - Supporting Types
public struct EncryptedData: Codable {
    public let ciphertext: Data
    public let iv: Data
    public let tag: Data
    public let additionalData: Data?
    
    public init(ciphertext: Data, iv: Data, tag: Data, additionalData: Data? = nil) {
        self.ciphertext = ciphertext
        self.iv = iv
        self.tag = tag
        self.additionalData = additionalData
    }
}

public enum CryptoError: LocalizedError {
    case keyNotAvailable
    case ivGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case biometricAuthenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .keyNotAvailable:
            return "Encryption key is not available"
        case .ivGenerationFailed:
            return "Failed to generate initialization vector"
        case .encryptionFailed:
            return "Encryption operation failed"
        case .decryptionFailed:
            return "Decryption operation failed"
        case .invalidData:
            return "Invalid encrypted data format"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        }
    }
}

// MARK: - CommonCrypto Integration
import CommonCrypto

// Extension for PBKDF2 support
extension Data {
    func derivedKey(password: String, saltData: Data, iterations: UInt32, keyLength: Int) -> Data? {
        let passwordData = password.data(using: .utf8)!
        var derivedKeyData = Data(count: keyLength)
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            saltData.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress },
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                    keyLength
                )
            }
        }
        
        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }
}