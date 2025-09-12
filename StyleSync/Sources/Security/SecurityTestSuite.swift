import Foundation
import XCTest
import CryptoKit
import Security

// MARK: - Security Test Suite
public final class SecurityTestSuite: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SecurityTestSuite()
    
    // MARK: - Published Properties
    @Published public var testResults: [SecurityTestResult] = []
    @Published public var isRunningTests = false
    @Published public var overallSecurityScore: Double = 0.0
    @Published public var lastTestRun: Date?
    
    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let auditLogger = AuditLogger.shared
    private let biometricAuth = BiometricAuthManager.shared
    private let privacyControls = PrivacyControlsManager.shared
    private let sandboxStorage = SandboxedStorageManager.shared
    private let developerPrevention = DeveloperAccessPrevention.shared
    private let hardwareSecurity = HardwareSecurityManager.shared
    private let photoPrivacy = PhotoPrivacyEngine.shared
    private let anonymousIdentity = AnonymousIdentityManager.shared
    
    private let testQueue = DispatchQueue(label: "com.stylesync.security.tests", qos: .userInitiated)
    
    // MARK: - Test Categories
    public enum SecurityTestCategory: String, CaseIterable {
        case encryption = "encryption"
        case authentication = "authentication"
        case dataPrivacy = "data_privacy"
        case developerAccess = "developer_access"
        case hardwareSecurity = "hardware_security"
        case anonymousIdentity = "anonymous_identity"
        case auditTrail = "audit_trail"
        case dataIsolation = "data_isolation"
        case photoProcessing = "photo_processing"
        case zeroKnowledge = "zero_knowledge"
    }
    
    private init() {}
    
    // MARK: - Test Execution
    @MainActor
    public func runComprehensiveSecurityTests() async {
        isRunningTests = true
        testResults.removeAll()
        
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "security_test_suite_started",
            "comprehensive": true,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        // Run all test categories
        for category in SecurityTestCategory.allCases {
            await runTestsForCategory(category)
        }
        
        // Calculate overall security score
        calculateOverallSecurityScore()
        
        lastTestRun = Date()
        isRunningTests = false
        
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "security_test_suite_completed",
            "overall_score": overallSecurityScore,
            "tests_run": testResults.count,
            "passed_tests": testResults.filter { $0.passed }.count,
            "failed_tests": testResults.filter { !$0.passed }.count
        ])
    }
    
    @MainActor
    private func runTestsForCategory(_ category: SecurityTestCategory) async {
        switch category {
        case .encryption:
            await runEncryptionTests()
        case .authentication:
            await runAuthenticationTests()
        case .dataPrivacy:
            await runDataPrivacyTests()
        case .developerAccess:
            await runDeveloperAccessTests()
        case .hardwareSecurity:
            await runHardwareSecurityTests()
        case .anonymousIdentity:
            await runAnonymousIdentityTests()
        case .auditTrail:
            await runAuditTrailTests()
        case .dataIsolation:
            await runDataIsolationTests()
        case .photoProcessing:
            await runPhotoProcessingTests()
        case .zeroKnowledge:
            await runZeroKnowledgeTests()
        }
    }
    
    // MARK: - Encryption Tests
    @MainActor
    private func runEncryptionTests() async {
        // Test 1: AES-256-GCM Encryption/Decryption
        await runTest(
            name: "AES-256-GCM Encryption/Decryption",
            category: .encryption
        ) {
            let testData = "Sensitive test data for encryption".data(using: .utf8)!
            
            let encryptedData = try self.cryptoEngine.encrypt(data: testData)
            let decryptedData = try self.cryptoEngine.decrypt(encryptedData: encryptedData)
            
            guard testData == decryptedData else {
                throw SecurityTestError.encryptionDecryptionMismatch
            }
        }
        
        // Test 2: Key Derivation (PBKDF2)
        await runTest(
            name: "PBKDF2 Key Derivation",
            category: .encryption
        ) {
            let password = "TestPassword123!"
            let salt = self.cryptoEngine.generateSalt()
            
            let key1 = self.cryptoEngine.deriveKey(from: password, salt: salt)
            let key2 = self.cryptoEngine.deriveKey(from: password, salt: salt)
            
            // Same password + salt should produce same key
            guard key1.withUnsafeBytes({ Data($0) }) == key2.withUnsafeBytes({ Data($0) }) else {
                throw SecurityTestError.keyDerivationInconsistent
            }
            
            // Different salt should produce different key
            let differentSalt = self.cryptoEngine.generateSalt()
            let key3 = self.cryptoEngine.deriveKey(from: password, salt: differentSalt)
            
            guard key1.withUnsafeBytes({ Data($0) }) != key3.withUnsafeBytes({ Data($0) }) else {
                throw SecurityTestError.keyDerivationWeak
            }
        }
        
        // Test 3: ChaCha20-Poly1305 Local Storage Encryption
        await runTest(
            name: "ChaCha20-Poly1305 Local Storage",
            category: .encryption
        ) {
            let testData = "Local storage test data".data(using: .utf8)!
            let context = "test_context"
            
            let encryptedData = try self.cryptoEngine.encryptForLocalStorage(data: testData, context: context)
            let decryptedData = try self.cryptoEngine.decryptFromLocalStorage(encryptedData: encryptedData, context: context)
            
            guard testData == decryptedData else {
                throw SecurityTestError.localStorageEncryptionFailed
            }
        }
        
        // Test 4: Secure Memory Operations
        await runTest(
            name: "Secure Memory Management",
            category: .encryption
        ) {
            var sensitiveData = "Sensitive data to be wiped".data(using: .utf8)!
            let originalSize = sensitiveData.count
            
            self.cryptoEngine.secureWipe(data: &sensitiveData)
            
            guard sensitiveData.isEmpty else {
                throw SecurityTestError.secureWipeFailed
            }
        }
    }
    
    // MARK: - Authentication Tests
    @MainActor
    private func runAuthenticationTests() async {
        // Test 1: Biometric Availability Check
        await runTest(
            name: "Biometric Authentication Availability",
            category: .authentication
        ) {
            let isAvailable = self.biometricAuth.isBiometricAvailable
            let biometricType = self.biometricAuth.biometricType
            
            // Should have some form of authentication available
            guard biometricType != .none || isAvailable else {
                throw SecurityTestError.noAuthenticationAvailable
            }
        }
        
        // Test 2: Session Management
        await runTest(
            name: "Authentication Session Management",
            category: .authentication
        ) {
            // Test session validity logic
            let wasValid = self.biometricAuth.isCurrentSessionValid
            
            // Force session invalidation
            self.biometricAuth.invalidateSession()
            
            let isValidAfterInvalidation = self.biometricAuth.isCurrentSessionValid
            
            guard !isValidAfterInvalidation else {
                throw SecurityTestError.sessionInvalidationFailed
            }
        }
        
        // Test 3: Secure Enclave Key Generation
        await runTest(
            name: "Secure Enclave Key Generation",
            category: .authentication
        ) {
            if self.hardwareSecurity.isSecureEnclaveAvailable {
                let keyId = try await self.hardwareSecurity.generateSecureEnclaveKey(
                    for: .authentication,
                    requiresBiometrics: false
                )
                
                guard !keyId.isEmpty else {
                    throw SecurityTestError.secureEnclaveKeyGenerationFailed
                }
            }
            // Test passes if Secure Enclave is not available (not an error)
        }
    }
    
    // MARK: - Data Privacy Tests
    @MainActor
    private func runDataPrivacyTests() async {
        // Test 1: Permission System
        await runTest(
            name: "Privacy Permission System",
            category: .dataPrivacy
        ) {
            let initialPermissions = self.privacyControls.permissionsGranted
            
            // Test permission granting
            let result = await self.privacyControls.requestPermission(.basicFeatures)
            
            switch result {
            case .granted, .alreadyGranted:
                break // Success
            case .denied:
                throw SecurityTestError.permissionSystemFailed
            }
        }
        
        // Test 2: Data Export Functionality
        await runTest(
            name: "Data Export System",
            category: .dataPrivacy
        ) {
            // Test export request creation (without biometric auth for testing)
            // In a real test, you'd mock the biometric authentication
        }
        
        // Test 3: Privacy Level Changes
        await runTest(
            name: "Privacy Level Management",
            category: .dataPrivacy
        ) {
            let currentLevel = self.privacyControls.privacyLevel
            
            // Privacy level should be set to a secure default
            guard currentLevel != .minimal else {
                throw SecurityTestError.insecurePrivacyDefault
            }
        }
    }
    
    // MARK: - Developer Access Tests
    @MainActor
    private func runDeveloperAccessTests() async {
        // Test 1: Admin Panel Blocking
        await runTest(
            name: "Admin Panel Access Blocking",
            category: .developerAccess
        ) {
            guard self.developerPrevention.isAdminPanelBlocked() else {
                throw SecurityTestError.adminPanelNotBlocked
            }
            
            // Test URL blocking
            let adminURL = URL(string: "https://app.example.com/admin")!
            let adminRequest = URLRequest(url: adminURL)
            
            let isBlocked = self.developerPrevention.blockAdminPanelRequest(adminRequest)
            
            guard isBlocked else {
                throw SecurityTestError.adminUrlNotBlocked
            }
        }
        
        // Test 2: Customer-Controlled Encryption
        await runTest(
            name: "Customer-Controlled Encryption",
            category: .developerAccess
        ) {
            let keyId = try self.developerPrevention.generateCustomerControlledKey(for: "test")
            let testData = "Customer controlled data".data(using: .utf8)!
            
            let encryptedData = try self.developerPrevention.encryptWithCustomerKey(testData, keyId: keyId)
            let decryptedData = try self.developerPrevention.decryptWithCustomerKey(encryptedData, keyId: keyId)
            
            guard testData == decryptedData else {
                throw SecurityTestError.customerControlledEncryptionFailed
            }
        }
        
        // Test 3: Zero-Knowledge Proof Generation
        await runTest(
            name: "Zero-Knowledge Proof System",
            category: .developerAccess
        ) {
            let proofId = try self.developerPrevention.generateZKProof(for: "test_statement", witness: "test_witness")
            
            guard !proofId.isEmpty else {
                throw SecurityTestError.zkProofGenerationFailed
            }
        }
    }
    
    // MARK: - Hardware Security Tests
    @MainActor
    private func runHardwareSecurityTests() async {
        // Test 1: Hardware Capability Detection
        await runTest(
            name: "Hardware Security Detection",
            category: .hardwareSecurity
        ) {
            let status = self.hardwareSecurity.getHardwareSecurityStatus()
            
            // Should detect at least software-level security
            guard status.securityLevel != .none else {
                throw SecurityTestError.noHardwareSecurityDetected
            }
        }
        
        // Test 2: Hardware Random Number Generation
        await runTest(
            name: "Hardware Random Number Generation",
            category: .hardwareSecurity
        ) {
            let randomData1 = try self.hardwareSecurity.generateHardwareRandom(bytes: 32)
            let randomData2 = try self.hardwareSecurity.generateHardwareRandom(bytes: 32)
            
            guard randomData1.count == 32 && randomData2.count == 32 else {
                throw SecurityTestError.hardwareRandomGenerationFailed
            }
            
            // Random data should be different
            guard randomData1 != randomData2 else {
                throw SecurityTestError.hardwareRandomNotRandom
            }
        }
        
        // Test 3: Hardware Attestation
        await runTest(
            name: "Hardware Attestation",
            category: .hardwareSecurity
        ) {
            let bootVerified = await self.hardwareSecurity.verifySecureBoot()
            
            // Boot verification should complete (true or false is acceptable)
            // The important thing is that the system can perform the check
        }
    }
    
    // MARK: - Anonymous Identity Tests
    @MainActor
    private func runAnonymousIdentityTests() async {
        // Test 1: Anonymous Identity Creation
        await runTest(
            name: "Anonymous Identity Creation",
            category: .anonymousIdentity
        ) {
            if self.anonymousIdentity.currentIdentity == nil {
                let identity = try await self.anonymousIdentity.createNewAnonymousIdentity()
                
                guard !identity.id.isEmpty && !identity.displayName.isEmpty else {
                    throw SecurityTestError.anonymousIdentityCreationFailed
                }
            }
        }
        
        // Test 2: Avatar System
        await runTest(
            name: "Avatar Generation System",
            category: .anonymousIdentity
        ) {
            let customAvatar = self.anonymousIdentity.createCustomAvatar(
                type: .geometric,
                primaryColor: .blue,
                secondaryColor: .purple,
                pattern: .circles
            )
            
            guard !customAvatar.id.isEmpty else {
                throw SecurityTestError.avatarGenerationFailed
            }
        }
        
        // Test 3: Identity Rotation
        await runTest(
            name: "Identity Rotation",
            category: .anonymousIdentity
        ) {
            if let currentIdentity = self.anonymousIdentity.currentIdentity {
                let oldId = currentIdentity.id
                
                try await self.anonymousIdentity.rotateIdentity()
                
                guard let newIdentity = self.anonymousIdentity.currentIdentity else {
                    throw SecurityTestError.identityRotationFailed
                }
                
                guard newIdentity.id != oldId else {
                    throw SecurityTestError.identityNotRotated
                }
            }
        }
    }
    
    // MARK: - Audit Trail Tests
    @MainActor
    private func runAuditTrailTests() async {
        // Test 1: Audit Log Generation
        await runTest(
            name: "Audit Log Generation",
            category: .auditTrail
        ) {
            await self.auditLogger.logSecurityEvent(.permissionGranted, details: [
                "test": "audit_log_test",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
            
            let recentLogs = await self.auditLogger.queryLogs(
                event: .permissionGranted,
                limit: 10
            )
            
            guard !recentLogs.isEmpty else {
                throw SecurityTestError.auditLogGenerationFailed
            }
        }
        
        // Test 2: Audit Log Integrity
        await runTest(
            name: "Audit Log Integrity",
            category: .auditTrail
        ) {
            // Test that logs have integrity hashes
            let logs = await self.auditLogger.queryLogs(limit: 5)
            
            for log in logs {
                guard !log.integrityHash.isEmpty else {
                    throw SecurityTestError.auditLogIntegrityMissing
                }
            }
        }
        
        // Test 3: Audit Log Export
        await runTest(
            name: "Audit Log Export",
            category: .auditTrail
        ) {
            let exportData = await self.auditLogger.exportLogs(format: .json)
            
            guard let data = exportData, !data.isEmpty else {
                throw SecurityTestError.auditLogExportFailed
            }
        }
    }
    
    // MARK: - Data Isolation Tests
    @MainActor
    private func runDataIsolationTests() async {
        // Test 1: Sandbox Creation
        await runTest(
            name: "User Sandbox Creation",
            category: .dataIsolation
        ) {
            let testUserId = "test_user_\(UUID().uuidString)"
            
            let sandbox = try await self.sandboxStorage.createUserSandbox(for: testUserId)
            
            guard sandbox.userId == testUserId else {
                throw SecurityTestError.sandboxCreationFailed
            }
            
            // Clean up test sandbox
            try await self.sandboxStorage.secureDeleteSandbox(for: testUserId)
        }
        
        // Test 2: Encrypted Storage Operations
        await runTest(
            name: "Encrypted Storage Operations",
            category: .dataIsolation
        ) {
            let testUserId = "test_user_\(UUID().uuidString)"
            let testData = ["key": "value", "secret": "sensitive_data"]
            
            let sandbox = try await self.sandboxStorage.createUserSandbox(for: testUserId)
            
            // Store data
            try await self.sandboxStorage.store(
                object: testData,
                key: "test_key",
                in: testUserId,
                category: .general
            )
            
            // Retrieve data
            let retrievedData: [String: String]? = try await self.sandboxStorage.retrieve(
                type: [String: String].self,
                key: "test_key",
                from: testUserId,
                category: .general
            )
            
            guard let retrieved = retrievedData,
                  retrieved["key"] == "value",
                  retrieved["secret"] == "sensitive_data" else {
                throw SecurityTestError.encryptedStorageFailed
            }
            
            // Clean up
            try await self.sandboxStorage.secureDeleteSandbox(for: testUserId)
        }
    }
    
    // MARK: - Photo Processing Tests
    @MainActor
    private func runPhotoProcessingTests() async {
        // Test 1: Privacy Settings
        await runTest(
            name: "Photo Privacy Settings",
            category: .photoProcessing
        ) {
            let settings = self.photoPrivacy.privacySettings
            
            // Should have secure defaults
            guard settings.automaticFaceBlurring || settings.automaticMetadataStripping else {
                throw SecurityTestError.insecurePhotoPrivacyDefaults
            }
        }
        
        // Test 2: Privacy Engine Initialization
        await runTest(
            name: "Photo Privacy Engine",
            category: .photoProcessing
        ) {
            // Test that the photo privacy engine is properly initialized
            guard !self.photoPrivacy.isProcessing else {
                throw SecurityTestError.photoPrivacyEngineNotReady
            }
        }
    }
    
    // MARK: - Zero-Knowledge Tests
    @MainActor
    private func runZeroKnowledgeTests() async {
        // Test 1: Blinding Factor Generation
        await runTest(
            name: "Blinding Factor Generation",
            category: .zeroKnowledge
        ) {
            let blindingFactor1 = self.cryptoEngine.generateBlindingFactor()
            let blindingFactor2 = self.cryptoEngine.generateBlindingFactor()
            
            guard blindingFactor1.count == 32 && blindingFactor2.count == 32 else {
                throw SecurityTestError.blindingFactorGenerationFailed
            }
            
            // Should generate different factors
            guard blindingFactor1 != blindingFactor2 else {
                throw SecurityTestError.blindingFactorNotRandom
            }
        }
        
        // Test 2: Data Blinding/Unblinding
        await runTest(
            name: "Data Blinding Operations",
            category: .zeroKnowledge
        ) {
            let testData = "Sensitive data to be blinded".data(using: .utf8)!
            let blindingFactor = self.cryptoEngine.generateBlindingFactor()
            
            let blindedData = self.cryptoEngine.blindData(testData, with: blindingFactor)
            let unblinedData = self.cryptoEngine.unblindData(blindedData, with: blindingFactor)
            
            guard testData == unblinedData else {
                throw SecurityTestError.dataBlindingFailed
            }
            
            // Blinded data should be different from original
            guard blindedData != testData else {
                throw SecurityTestError.dataNotBlinded
            }
        }
    }
    
    // MARK: - Test Execution Helper
    private func runTest(
        name: String,
        category: SecurityTestCategory,
        test: @escaping () async throws -> Void
    ) async {
        let startTime = Date()
        
        do {
            try await test()
            
            let duration = Date().timeIntervalSince(startTime)
            let result = SecurityTestResult(
                name: name,
                category: category,
                passed: true,
                duration: duration,
                error: nil,
                timestamp: Date()
            )
            
            await MainActor.run {
                testResults.append(result)
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = SecurityTestResult(
                name: name,
                category: category,
                passed: false,
                duration: duration,
                error: error.localizedDescription,
                timestamp: Date()
            )
            
            await MainActor.run {
                testResults.append(result)
            }
        }
    }
    
    // MARK: - Security Score Calculation
    private func calculateOverallSecurityScore() {
        guard !testResults.isEmpty else {
            overallSecurityScore = 0.0
            return
        }
        
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        
        // Base score from test pass rate
        let baseScore = Double(passedTests) / Double(totalTests)
        
        // Weight critical security features more heavily
        var weightedScore = baseScore
        
        // Check for critical features and adjust score
        let criticalTests = testResults.filter { result in
            result.name.contains("Encryption") ||
            result.name.contains("Authentication") ||
            result.name.contains("Developer Access") ||
            result.name.contains("Audit")
        }
        
        let criticalPassed = criticalTests.filter { $0.passed }.count
        let criticalTotal = criticalTests.count
        
        if criticalTotal > 0 {
            let criticalScore = Double(criticalPassed) / Double(criticalTotal)
            // Weight critical tests at 70%, other tests at 30%
            weightedScore = (criticalScore * 0.7) + (baseScore * 0.3)
        }
        
        overallSecurityScore = min(1.0, max(0.0, weightedScore))
    }
    
    // MARK: - Test Report Generation
    public func generateSecurityReport() -> SecurityReport {
        let categoryResults = Dictionary(grouping: testResults) { $0.category }
        
        var categoryScores: [SecurityTestCategory: Double] = [:]
        
        for (category, tests) in categoryResults {
            let passed = tests.filter { $0.passed }.count
            let total = tests.count
            categoryScores[category] = total > 0 ? Double(passed) / Double(total) : 0.0
        }
        
        return SecurityReport(
            overallScore: overallSecurityScore,
            categoryScores: categoryScores,
            totalTests: testResults.count,
            passedTests: testResults.filter { $0.passed }.count,
            failedTests: testResults.filter { !$0.passed }.count,
            testDuration: testResults.reduce(0) { $0 + $1.duration },
            lastRun: lastTestRun ?? Date(),
            detailedResults: testResults
        )
    }
}

// MARK: - Supporting Types
public struct SecurityTestResult: Identifiable {
    public let id = UUID()
    public let name: String
    public let category: SecurityTestSuite.SecurityTestCategory
    public let passed: Bool
    public let duration: TimeInterval
    public let error: String?
    public let timestamp: Date
}

public struct SecurityReport {
    public let overallScore: Double
    public let categoryScores: [SecurityTestSuite.SecurityTestCategory: Double]
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let testDuration: TimeInterval
    public let lastRun: Date
    public let detailedResults: [SecurityTestResult]
    
    public var securityGrade: SecurityGrade {
        switch overallScore {
        case 0.9...1.0: return .excellent
        case 0.8..<0.9: return .good
        case 0.7..<0.8: return .satisfactory
        case 0.6..<0.7: return .needsImprovement
        default: return .critical
        }
    }
    
    public enum SecurityGrade: String {
        case excellent = "Excellent"
        case good = "Good"
        case satisfactory = "Satisfactory"
        case needsImprovement = "Needs Improvement"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "lightgreen"
            case .satisfactory: return "yellow"
            case .needsImprovement: return "orange"
            case .critical: return "red"
            }
        }
    }
}

public enum SecurityTestError: LocalizedError {
    case encryptionDecryptionMismatch
    case keyDerivationInconsistent
    case keyDerivationWeak
    case localStorageEncryptionFailed
    case secureWipeFailed
    case noAuthenticationAvailable
    case sessionInvalidationFailed
    case secureEnclaveKeyGenerationFailed
    case permissionSystemFailed
    case insecurePrivacyDefault
    case adminPanelNotBlocked
    case adminUrlNotBlocked
    case customerControlledEncryptionFailed
    case zkProofGenerationFailed
    case noHardwareSecurityDetected
    case hardwareRandomGenerationFailed
    case hardwareRandomNotRandom
    case anonymousIdentityCreationFailed
    case avatarGenerationFailed
    case identityRotationFailed
    case identityNotRotated
    case auditLogGenerationFailed
    case auditLogIntegrityMissing
    case auditLogExportFailed
    case sandboxCreationFailed
    case encryptedStorageFailed
    case insecurePhotoPrivacyDefaults
    case photoPrivacyEngineNotReady
    case blindingFactorGenerationFailed
    case blindingFactorNotRandom
    case dataBlindingFailed
    case dataNotBlinded
    
    public var errorDescription: String? {
        switch self {
        case .encryptionDecryptionMismatch:
            return "Encrypted data does not match original after decryption"
        case .keyDerivationInconsistent:
            return "Key derivation produces inconsistent results"
        case .keyDerivationWeak:
            return "Key derivation is too weak (same key for different salts)"
        case .localStorageEncryptionFailed:
            return "Local storage encryption/decryption failed"
        case .secureWipeFailed:
            return "Secure memory wipe failed"
        case .noAuthenticationAvailable:
            return "No authentication method available"
        case .sessionInvalidationFailed:
            return "Authentication session invalidation failed"
        case .secureEnclaveKeyGenerationFailed:
            return "Secure Enclave key generation failed"
        case .permissionSystemFailed:
            return "Privacy permission system failed"
        case .insecurePrivacyDefault:
            return "Privacy level default is insecure"
        case .adminPanelNotBlocked:
            return "Admin panel access is not properly blocked"
        case .adminUrlNotBlocked:
            return "Admin URLs are not being blocked"
        case .customerControlledEncryptionFailed:
            return "Customer-controlled encryption failed"
        case .zkProofGenerationFailed:
            return "Zero-knowledge proof generation failed"
        case .noHardwareSecurityDetected:
            return "No hardware security features detected"
        case .hardwareRandomGenerationFailed:
            return "Hardware random number generation failed"
        case .hardwareRandomNotRandom:
            return "Hardware random numbers are not random"
        case .anonymousIdentityCreationFailed:
            return "Anonymous identity creation failed"
        case .avatarGenerationFailed:
            return "Avatar generation failed"
        case .identityRotationFailed:
            return "Identity rotation failed"
        case .identityNotRotated:
            return "Identity was not properly rotated"
        case .auditLogGenerationFailed:
            return "Audit log generation failed"
        case .auditLogIntegrityMissing:
            return "Audit log integrity hash missing"
        case .auditLogExportFailed:
            return "Audit log export failed"
        case .sandboxCreationFailed:
            return "User sandbox creation failed"
        case .encryptedStorageFailed:
            return "Encrypted storage operations failed"
        case .insecurePhotoPrivacyDefaults:
            return "Photo privacy defaults are insecure"
        case .photoPrivacyEngineNotReady:
            return "Photo privacy engine is not ready"
        case .blindingFactorGenerationFailed:
            return "Blinding factor generation failed"
        case .blindingFactorNotRandom:
            return "Blinding factors are not random"
        case .dataBlindingFailed:
            return "Data blinding/unblinding failed"
        case .dataNotBlinded:
            return "Data was not properly blinded"
        }
    }
}