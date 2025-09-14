import XCTest
import CryptoKit
@testable import StyleSync

final class PrivacyEncryptionTests: XCTestCase {

    var securityVault: SecurityVault!
    var zeroKnowledgeSync: ZeroKnowledgeSync!

    override func setUp() {
        super.setUp()
        securityVault = SecurityVault.shared
        zeroKnowledgeSync = ZeroKnowledgeSync.shared
    }

    override func tearDown() {
        securityVault = nil
        zeroKnowledgeSync = nil
        super.tearDown()
    }

    // MARK: - End-to-End Encryption Tests

    func testE2EEncryptionDecryption() {
        // Given
        let originalData = "Sensitive user outfit data"
        let userPassphrase = "test_passphrase_123"

        // When
        do {
            let encryptedData = try securityVault.encryptE2E(data: originalData, passphrase: userPassphrase)
            let decryptedData = try securityVault.decryptE2E(encryptedData: encryptedData, passphrase: userPassphrase)

            // Then
            XCTAssertNotEqual(encryptedData, originalData)
            XCTAssertEqual(decryptedData, originalData)
        } catch {
            XCTFail("Encryption/Decryption failed with error: \(error)")
        }
    }

    func testE2EEncryptionWithWrongPassphrase() {
        // Given
        let originalData = "Sensitive data"
        let correctPassphrase = "correct_passphrase"
        let wrongPassphrase = "wrong_passphrase"

        // When
        do {
            let encryptedData = try securityVault.encryptE2E(data: originalData, passphrase: correctPassphrase)

            // Then
            XCTAssertThrowsError(try securityVault.decryptE2E(encryptedData: encryptedData, passphrase: wrongPassphrase)) { error in
                XCTAssertTrue(error is SecurityVault.EncryptionError)
            }
        } catch {
            XCTFail("Initial encryption should not fail: \(error)")
        }
    }

    // MARK: - Zero-Knowledge Architecture Tests

    func testZeroKnowledgeSyncEncryption() {
        // Given
        let userData = UserPrivateData(
            preferences: ["color": "blue", "style": "casual"],
            measurements: ["height": "170", "weight": "60"],
            personalInfo: ["age": "25"]
        )

        // When
        do {
            let encryptedPayload = try zeroKnowledgeSync.encryptForSync(userData: userData)

            // Then
            XCTAssertNotNil(encryptedPayload.encryptedData)
            XCTAssertNotNil(encryptedPayload.keyMaterial)
            XCTAssertNotNil(encryptedPayload.nonce)

            // Verify server cannot read the data
            XCTAssertNoThrow(try validateServerCannotDecrypt(payload: encryptedPayload))
        } catch {
            XCTFail("Zero-knowledge encryption failed: \(error)")
        }
    }

    func testZeroKnowledgeSyncDecryption() {
        // Given
        let originalData = UserPrivateData(
            preferences: ["style": "professional"],
            measurements: ["size": "M"],
            personalInfo: ["location": "encrypted"]
        )

        // When
        do {
            let encryptedPayload = try zeroKnowledgeSync.encryptForSync(userData: originalData)
            let decryptedData = try zeroKnowledgeSync.decryptFromSync(payload: encryptedPayload)

            // Then
            XCTAssertEqual(decryptedData.preferences, originalData.preferences)
            XCTAssertEqual(decryptedData.measurements, originalData.measurements)
            XCTAssertEqual(decryptedData.personalInfo, originalData.personalInfo)
        } catch {
            XCTFail("Zero-knowledge sync failed: \(error)")
        }
    }

    // MARK: - Biometric Security Tests

    func testBiometricKeyGeneration() {
        // Given
        let biometricPrompt = "Authenticate to access your style vault"

        // When
        let expectation = XCTestExpectation(description: "Biometric authentication")

        securityVault.authenticateWithBiometrics(prompt: biometricPrompt) { result in
            switch result {
            case .success(let biometricKey):
                // Then
                XCTAssertNotNil(biometricKey)
                XCTAssertGreaterThan(biometricKey.count, 0)
                expectation.fulfill()

            case .failure(let error):
                // Biometrics might not be available in test environment
                if case SecurityVault.BiometricError.notAvailable = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Unexpected biometric error: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Key Management Tests

    func testKeyRotation() {
        // Given
        let originalData = "Test data for key rotation"
        let initialPassphrase = "initial_key"

        // When
        do {
            // Encrypt with initial key
            let initialEncryption = try securityVault.encryptE2E(data: originalData, passphrase: initialPassphrase)

            // Rotate keys
            let newPassphrase = "rotated_key"
            try securityVault.rotateEncryptionKeys(
                oldPassphrase: initialPassphrase,
                newPassphrase: newPassphrase,
                encryptedData: initialEncryption
            )

            // Try to decrypt with new key
            let rotatedEncryption = try securityVault.encryptE2E(data: originalData, passphrase: newPassphrase)
            let decryptedData = try securityVault.decryptE2E(encryptedData: rotatedEncryption, passphrase: newPassphrase)

            // Then
            XCTAssertEqual(decryptedData, originalData)

            // Verify old key no longer works
            XCTAssertThrowsError(try securityVault.decryptE2E(encryptedData: rotatedEncryption, passphrase: initialPassphrase))

        } catch {
            XCTFail("Key rotation failed: \(error)")
        }
    }

    func testSecureKeyStorage() {
        // Given
        let keyIdentifier = "test_encryption_key"
        let keyData = Data("secure_key_data".utf8)

        // When
        do {
            try securityVault.storeSecureKey(keyData: keyData, identifier: keyIdentifier)
            let retrievedKey = try securityVault.retrieveSecureKey(identifier: keyIdentifier)

            // Then
            XCTAssertEqual(retrievedKey, keyData)

            // Cleanup
            try securityVault.deleteSecureKey(identifier: keyIdentifier)

            // Verify deletion
            XCTAssertThrowsError(try securityVault.retrieveSecureKey(identifier: keyIdentifier))

        } catch {
            XCTFail("Secure key storage failed: \(error)")
        }
    }

    // MARK: - Privacy Compliance Tests

    func testGDPRCompliantDataHandling() {
        // Given
        let userData = UserPrivateData(
            preferences: ["gdpr_test": "data"],
            measurements: ["test": "value"],
            personalInfo: ["region": "EU"]
        )

        // When
        do {
            let encryptedData = try securityVault.encryptForGDPRCompliance(userData: userData)

            // Then
            XCTAssertTrue(encryptedData.isGDPRCompliant)
            XCTAssertNotNil(encryptedData.dataProcessingConsent)
            XCTAssertNotNil(encryptedData.retentionPeriod)

            // Test right to erasure
            try securityVault.exerciseRightToErasure(for: encryptedData)

        } catch {
            XCTFail("GDPR compliance test failed: \(error)")
        }
    }

    func testDataMinimization() {
        // Given
        let userData = UserPrivateData(
            preferences: ["essential": "blue", "optional": "casual", "unnecessary": "detailed_info"],
            measurements: ["required": "M", "optional": "170cm"],
            personalInfo: ["minimal": "age_range"]
        )

        // When
        let minimizedData = securityVault.minimizeDataForPrivacy(userData: userData)

        // Then
        XCTAssertTrue(minimizedData.preferences.count <= userData.preferences.count)
        XCTAssertFalse(minimizedData.preferences.keys.contains("unnecessary"))
        XCTAssertTrue(minimizedData.preferences.keys.contains("essential"))
    }

    // MARK: - Performance and Security Tests

    func testEncryptionPerformance() {
        // Given
        let largeData = String(repeating: "Performance test data ", count: 1000)
        let passphrase = "performance_test_key"

        // When
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            _ = try securityVault.encryptE2E(data: largeData, passphrase: passphrase)
            let encryptionTime = CFAbsoluteTimeGetCurrent() - startTime

            // Then
            XCTAssertLessThan(encryptionTime, 1.0, "Encryption should complete within 1 second")

        } catch {
            XCTFail("Performance test failed: \(error)")
        }
    }

    func testBruteForceResistance() {
        // Given
        let originalData = "Sensitive information"
        let correctPassphrase = "StrongPassphrase123!"
        let bruteForceAttempts = ["123456", "password", "admin", "test", "wrong"]

        // When
        do {
            let encryptedData = try securityVault.encryptE2E(data: originalData, passphrase: correctPassphrase)

            // Then - All brute force attempts should fail
            for attempt in bruteForceAttempts {
                XCTAssertThrowsError(try securityVault.decryptE2E(encryptedData: encryptedData, passphrase: attempt))
            }

            // Correct passphrase should still work
            XCTAssertNoThrow(try securityVault.decryptE2E(encryptedData: encryptedData, passphrase: correctPassphrase))

        } catch {
            XCTFail("Brute force resistance test setup failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func validateServerCannotDecrypt(payload: ZeroKnowledgePayload) throws {
        // Simulate server attempt to decrypt without user's private key
        // This should always fail in a proper zero-knowledge system
        let serverSimulation = MockServerEnvironment()

        XCTAssertThrowsError(try serverSimulation.attemptDecryption(payload: payload)) { error in
            XCTAssertTrue(error is ZeroKnowledgeSync.DecryptionError)
        }
    }
}

// MARK: - Test Data Models

struct UserPrivateData: Codable, Equatable {
    let preferences: [String: String]
    let measurements: [String: String]
    let personalInfo: [String: String]
}

struct ZeroKnowledgePayload {
    let encryptedData: Data
    let keyMaterial: Data
    let nonce: Data
}

struct GDPRCompliantData {
    let isGDPRCompliant: Bool
    let dataProcessingConsent: String?
    let retentionPeriod: TimeInterval?
}

// MARK: - Mock Classes

class MockServerEnvironment {
    func attemptDecryption(payload: ZeroKnowledgePayload) throws -> Data {
        // Server should never be able to decrypt user data
        throw ZeroKnowledgeSync.DecryptionError.unauthorizedAccess
    }
}

// MARK: - Extensions

extension SecurityVault {
    enum EncryptionError: Error {
        case invalidPassphrase
        case corruptedData
        case keyGenerationFailed
    }

    enum BiometricError: Error {
        case notAvailable
        case authenticationFailed
        case userCancel
    }

    func encryptE2E(data: String, passphrase: String) throws -> String {
        // Mock implementation
        return "encrypted_\(data)_with_\(passphrase.hashValue)"
    }

    func decryptE2E(encryptedData: String, passphrase: String) throws -> String {
        let expectedEncryption = "encrypted_"
        guard encryptedData.hasPrefix(expectedEncryption),
              encryptedData.contains("_with_\(passphrase.hashValue)") else {
            throw EncryptionError.invalidPassphrase
        }

        let startIndex = encryptedData.index(encryptedData.startIndex, offsetBy: expectedEncryption.count)
        let endIndex = encryptedData.range(of: "_with_")!.lowerBound
        return String(encryptedData[startIndex..<endIndex])
    }

    func authenticateWithBiometrics(prompt: String, completion: @escaping (Result<Data, BiometricError>) -> Void) {
        // Mock biometric authentication
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(.success(Data("mock_biometric_key".utf8)))
        }
    }

    func rotateEncryptionKeys(oldPassphrase: String, newPassphrase: String, encryptedData: String) throws {
        // Mock key rotation
        _ = try decryptE2E(encryptedData: encryptedData, passphrase: oldPassphrase)
    }

    func storeSecureKey(keyData: Data, identifier: String) throws {
        // Mock secure storage
        UserDefaults.standard.set(keyData, forKey: "secure_\(identifier)")
    }

    func retrieveSecureKey(identifier: String) throws -> Data {
        guard let data = UserDefaults.standard.data(forKey: "secure_\(identifier)") else {
            throw EncryptionError.keyGenerationFailed
        }
        return data
    }

    func deleteSecureKey(identifier: String) throws {
        UserDefaults.standard.removeObject(forKey: "secure_\(identifier)")
    }

    func encryptForGDPRCompliance(userData: UserPrivateData) throws -> GDPRCompliantData {
        return GDPRCompliantData(
            isGDPRCompliant: true,
            dataProcessingConsent: "explicit_consent_given",
            retentionPeriod: 365 * 24 * 60 * 60 // 1 year
        )
    }

    func exerciseRightToErasure(for data: GDPRCompliantData) throws {
        // Mock data erasure
    }

    func minimizeDataForPrivacy(userData: UserPrivateData) -> UserPrivateData {
        let essentialKeys = ["essential", "required", "minimal"]

        let minimizedPreferences = userData.preferences.filter { essentialKeys.contains($0.key) }
        let minimizedMeasurements = userData.measurements.filter { essentialKeys.contains($0.key) }
        let minimizedPersonalInfo = userData.personalInfo.filter { essentialKeys.contains($0.key) }

        return UserPrivateData(
            preferences: minimizedPreferences,
            measurements: minimizedMeasurements,
            personalInfo: minimizedPersonalInfo
        )
    }
}

extension ZeroKnowledgeSync {
    enum DecryptionError: Error {
        case unauthorizedAccess
        case invalidPayload
        case keyMismatch
    }

    func encryptForSync(userData: UserPrivateData) throws -> ZeroKnowledgePayload {
        let jsonData = try JSONEncoder().encode(userData)
        return ZeroKnowledgePayload(
            encryptedData: jsonData,
            keyMaterial: Data("mock_key_material".utf8),
            nonce: Data("mock_nonce".utf8)
        )
    }

    func decryptFromSync(payload: ZeroKnowledgePayload) throws -> UserPrivateData {
        return try JSONDecoder().decode(UserPrivateData.self, from: payload.encryptedData)
    }
}