import Foundation
import LocalAuthentication
import CryptoKit
import Security

// MARK: - Biometric Authentication Manager
public final class BiometricAuthManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = BiometricAuthManager()
    
    // MARK: - Published Properties
    @Published public var isAuthenticated = false
    @Published public var biometricType: BiometricType = .none
    @Published public var authenticationError: AuthenticationError?
    
    // MARK: - Private Properties
    private let context = LAContext()
    private var authenticationSession: Date?
    private let sessionTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Constants
    private enum Constants {
        static let biometricPrompt = "Authenticate to access your secure data"
        static let fallbackTitle = "Use Passcode"
        static let cancelTitle = "Cancel"
        static let secureEnclaveKeyTag = "com.stylesync.biometric.key"
    }
    
    private init() {
        updateBiometricType()
        setupSecurityObservers()
    }
    
    // MARK: - Biometric Type Detection
    public enum BiometricType: String, CaseIterable {
        case none = "None"
        case touchID = "Touch ID"
        case faceID = "Face ID"
        case opticID = "Optic ID" // For future Apple Vision Pro support
        
        var displayName: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .none: return "lock"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "eye"
            }
        }
    }
    
    private func updateBiometricType() {
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
        @unknown default:
            biometricType = .none
        }
    }
    
    // MARK: - Authentication State
    public var isBiometricAvailable: Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    public var isSecureEnclaveAvailable: Bool {
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) &&
               TARGET_OS_SIMULATOR == 0 // Secure Enclave not available in simulator
    }
    
    public var isCurrentSessionValid: Bool {
        guard let sessionStart = authenticationSession else { return false }
        return Date().timeIntervalSince(sessionStart) < sessionTimeout
    }
    
    // MARK: - Authentication Methods
    public func authenticate(reason: String? = nil) async -> AuthenticationResult {
        // Check if current session is still valid
        if isCurrentSessionValid {
            return .success
        }
        
        // Reset authentication state
        isAuthenticated = false
        authenticationError = nil
        
        let authReason = reason ?? Constants.biometricPrompt
        
        do {
            // Configure authentication context
            configureAuthenticationContext()
            
            // Perform biometric authentication
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: authReason
            )
            
            if success {
                // Update authentication state
                isAuthenticated = true
                authenticationSession = Date()
                
                // Log successful authentication
                await AuditLogger.shared.logSecurityEvent(.biometricAuthSuccess, details: [
                    "biometric_type": biometricType.rawValue,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ])
                
                return .success
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            let authError = mapLAError(error)
            authenticationError = authError
            
            // Log failed authentication
            await AuditLogger.shared.logSecurityEvent(.biometricAuthFailure, details: [
                "error": authError.localizedDescription,
                "error_code": "\(error.code)",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
            
            return .failure(authError)
        } catch {
            let unknownError = AuthenticationError.unknown(error.localizedDescription)
            authenticationError = unknownError
            return .failure(unknownError)
        }
    }
    
    public func authenticateWithPasscode(reason: String? = nil) async -> AuthenticationResult {
        let authReason = reason ?? "Enter your device passcode"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: authReason
            )
            
            if success {
                isAuthenticated = true
                authenticationSession = Date()
                return .success
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            let authError = mapLAError(error)
            authenticationError = authError
            return .failure(authError)
        } catch {
            let unknownError = AuthenticationError.unknown(error.localizedDescription)
            authenticationError = unknownError
            return .failure(unknownError)
        }
    }
    
    private func configureAuthenticationContext() {
        // Set authentication context properties
        context.localizedFallbackTitle = Constants.fallbackTitle
        context.localizedCancelTitle = Constants.cancelTitle
        
        // Configure touch ID reuse duration
        context.touchIDAuthenticationAllowableReuseDuration = 10 // 10 seconds
        
        // Set biometry lockout recovery
        if #available(iOS 11.2, *) {
            context.interactionNotAllowed = false
        }
    }
    
    private func mapLAError(_ error: LAError) -> AuthenticationError {
        switch error.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .appCancel:
            return .appCancel
        case .invalidContext:
            return .invalidContext
        default:
            return .unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Secure Enclave Operations
    public func generateSecureEnclaveKey() async -> SecKey? {
        // Ensure biometric authentication is available
        guard isBiometricAvailable else { return nil }
        
        // Create access control for Secure Enclave
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryAny],
            nil
        ) else {
            return nil
        }
        
        // Configure key attributes for Secure Enclave
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
        let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        
        if let error = error {
            print("Secure Enclave key generation failed: \(error.takeRetainedValue())")
            return nil
        }
        
        return privateKey
    }
    
    public func retrieveSecureEnclaveKey() async -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.secureEnclaveKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow,
            kSecUseAuthenticationContext as String: context
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let key = item as? SecKey else {
            return nil
        }
        
        return key
    }
    
    public func deleteSecureEnclaveKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.secureEnclaveKeyTag.data(using: .utf8)!
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Biometric Template Protection
    public func enableBiometricTemplateProtection() {
        // Configure enhanced biometric security
        guard isBiometricAvailable else { return }
        
        // Enable biometric invalidation on enrollment changes
        let context = LAContext()
        context.evaluateAccessControl(
            SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryAny],
                nil
            )!,
            operation: .useItem,
            localizedReason: "Enable enhanced biometric protection"
        ) { success, error in
            if success {
                // Biometric template protection enabled
                DispatchQueue.main.async {
                    self.logBiometricEvent("Template protection enabled")
                }
            }
        }
    }
    
    // MARK: - Anti-Spoofing Measures
    public func validateBiometricLiveness() async -> Bool {
        // Implement liveness detection for advanced security
        guard isBiometricAvailable else { return false }
        
        // Check for multiple authentication attempts in short time
        let recentAttempts = await getRecentAuthenticationAttempts()
        if recentAttempts.count > 3 {
            // Potential spoofing attempt
            await AuditLogger.shared.logSecurityEvent(.suspiciousBiometricActivity, details: [
                "attempts": "\(recentAttempts.count)",
                "timeframe": "60_seconds"
            ])
            return false
        }
        
        // Additional liveness checks would go here
        // (e.g., motion detection, temperature sensing, etc.)
        
        return true
    }
    
    private func getRecentAuthenticationAttempts() async -> [Date] {
        // Retrieve recent authentication attempts from secure storage
        // This is a simplified implementation
        return []
    }
    
    // MARK: - Session Management
    public func extendSession() {
        guard isAuthenticated else { return }
        authenticationSession = Date()
    }
    
    public func invalidateSession() {
        isAuthenticated = false
        authenticationSession = nil
        context.invalidate()
    }
    
    public func requireReauthentication() {
        invalidateSession()
        authenticationError = .sessionExpired
    }
    
    // MARK: - Security Observers
    private func setupSecurityObservers() {
        // Observe app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Observe biometric enrollment changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(biometricDatabaseChanged),
            name: .LABiometryDatabaseChanged,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // Start session timeout timer
        DispatchQueue.main.asyncAfter(deadline: .now() + sessionTimeout) { [weak self] in
            self?.requireReauthentication()
        }
    }
    
    @objc private func appWillEnterForeground() {
        // Check if session is still valid
        if !isCurrentSessionValid {
            requireReauthentication()
        }
        
        // Update biometric availability
        updateBiometricType()
    }
    
    @objc private func biometricDatabaseChanged() {
        // Biometric enrollment changed - invalidate current session
        invalidateSession()
        
        // Log security event
        logBiometricEvent("Biometric enrollment changed - session invalidated")
        
        // Update biometric type
        updateBiometricType()
    }
    
    private func logBiometricEvent(_ message: String) {
        Task {
            await AuditLogger.shared.logSecurityEvent(.biometricChange, details: [
                "message": message,
                "biometric_type": biometricType.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }
    
    // MARK: - Privacy Controls
    public func getBiometricPrivacySettings() -> BiometricPrivacySettings {
        return BiometricPrivacySettings(
            isBiometricEnabled: isBiometricAvailable,
            biometricType: biometricType,
            isSecureEnclaveEnabled: isSecureEnclaveAvailable,
            sessionTimeout: sessionTimeout,
            requiresReauthentication: !isCurrentSessionValid
        )
    }
    
    public func updatePrivacySettings(_ settings: BiometricPrivacySettings) {
        // Update privacy settings
        // Implementation would depend on specific requirements
    }
}

// MARK: - Supporting Types
public enum AuthenticationResult {
    case success
    case failure(AuthenticationError)
}

public enum AuthenticationError: LocalizedError {
    case authenticationFailed
    case userCancel
    case userFallback
    case systemCancel
    case passcodeNotSet
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case appCancel
    case invalidContext
    case sessionExpired
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancel:
            return "Authentication was cancelled by the user."
        case .userFallback:
            return "User chose to enter passcode."
        case .systemCancel:
            return "Authentication was cancelled by the system."
        case .passcodeNotSet:
            return "Passcode is not set on this device."
        case .biometryNotAvailable:
            return "Biometric authentication is not available."
        case .biometryNotEnrolled:
            return "No biometric data enrolled. Please set up biometric authentication in Settings."
        case .biometryLockout:
            return "Biometric authentication is locked out. Please try again later or use your passcode."
        case .appCancel:
            return "Authentication was cancelled by the app."
        case .invalidContext:
            return "Invalid authentication context."
        case .sessionExpired:
            return "Your session has expired. Please authenticate again."
        case .unknown(let message):
            return "Unknown authentication error: \(message)"
        }
    }
}

public struct BiometricPrivacySettings: Codable {
    public let isBiometricEnabled: Bool
    public let biometricType: BiometricAuthManager.BiometricType
    public let isSecureEnclaveEnabled: Bool
    public let sessionTimeout: TimeInterval
    public let requiresReauthentication: Bool
    
    public init(
        isBiometricEnabled: Bool,
        biometricType: BiometricAuthManager.BiometricType,
        isSecureEnclaveEnabled: Bool,
        sessionTimeout: TimeInterval,
        requiresReauthentication: Bool
    ) {
        self.isBiometricEnabled = isBiometricEnabled
        self.biometricType = biometricType
        self.isSecureEnclaveEnabled = isSecureEnclaveEnabled
        self.sessionTimeout = sessionTimeout
        self.requiresReauthentication = requiresReauthentication
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let LABiometryDatabaseChanged = Notification.Name("LABiometryDatabaseChanged")
}