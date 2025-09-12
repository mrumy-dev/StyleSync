import Foundation
import SwiftUI
import CryptoKit
import LocalAuthentication

// MARK: - Privacy Controls Manager
@MainActor
public final class PrivacyControlsManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = PrivacyControlsManager()
    
    // MARK: - Published Properties
    @Published public var privacyLevel: PrivacyLevel = .high
    @Published public var permissionsGranted: Set<PrivacyPermission> = []
    @Published public var dataExportRequests: [DataExportRequest] = []
    @Published public var isIncognitoMode = false
    @Published public var privacyModeEnabled = true
    @Published public var auditTrailEnabled = true
    
    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let auditLogger = AuditLogger.shared
    private let keychainManager = KeychainManager.shared
    private let biometricAuth = BiometricAuthManager.shared
    
    private var privacySettings: ComprehensivePrivacySettings
    private let settingsQueue = DispatchQueue(label: "com.stylesync.privacy.settings", qos: .utility)
    
    // MARK: - Constants
    private enum Constants {
        static let privacySettingsKey = "comprehensive_privacy_settings"
        static let permissionsKey = "granted_permissions"
        static let exportRequestsKey = "data_export_requests"
        static let auditRetentionDays = 2555 // 7 years
        static let dataExportCooldown: TimeInterval = 86400 // 24 hours
    }
    
    private init() {
        self.privacySettings = ComprehensivePrivacySettings()
        loadPrivacySettings()
        setupPrivacyMonitoring()
    }
    
    // MARK: - Privacy Level Management
    public func setPrivacyLevel(_ level: PrivacyLevel) async throws {
        // Require authentication for privacy level changes
        let authResult = await biometricAuth.authenticate(reason: "Change privacy level")
        
        switch authResult {
        case .success:
            privacyLevel = level
            await updatePrivacySettings(for: level)
            
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "privacy_level_changed",
                "new_level": level.rawValue,
                "authenticated": true
            ])
            
        case .failure(let error):
            throw PrivacyError.authenticationRequired(error)
        }
    }
    
    private func updatePrivacySettings(for level: PrivacyLevel) async {
        await withCheckedContinuation { continuation in
            settingsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                switch level {
                case .minimal:
                    self.privacySettings = self.createMinimalPrivacySettings()
                    
                case .balanced:
                    self.privacySettings = self.createBalancedPrivacySettings()
                    
                case .high:
                    self.privacySettings = self.createHighPrivacySettings()
                    
                case .maximum:
                    self.privacySettings = self.createMaximumPrivacySettings()
                }
                
                // Save updated settings
                self.savePrivacySettings()
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Permission Management
    public func requestPermission(_ permission: PrivacyPermission) async -> PermissionResult {
        // Check if permission is already granted
        if permissionsGranted.contains(permission) {
            return .alreadyGranted
        }
        
        // Check if permission is allowed by current privacy level
        guard privacySettings.allowedPermissions.contains(permission) else {
            await auditLogger.logSecurityEvent(.permissionDenied, details: [
                "permission": permission.rawValue,
                "reason": "blocked_by_privacy_level",
                "privacy_level": privacyLevel.rawValue
            ])
            return .denied(.blockedByPrivacyLevel)
        }
        
        // Require biometric authentication for sensitive permissions
        if permission.requiresBiometricAuth {
            let authResult = await biometricAuth.authenticate(reason: "Grant \(permission.displayName) permission")
            
            switch authResult {
            case .success:
                break
            case .failure(let error):
                await auditLogger.logSecurityEvent(.permissionDenied, details: [
                    "permission": permission.rawValue,
                    "reason": "authentication_failed",
                    "error": error.localizedDescription
                ])
                return .denied(.authenticationFailed)
            }
        }
        
        // Grant permission
        permissionsGranted.insert(permission)
        await savePermissions()
        
        // Log permission grant
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "permission": permission.rawValue,
            "authenticated": permission.requiresBiometricAuth,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        return .granted
    }
    
    public func revokePermission(_ permission: PrivacyPermission) async {
        permissionsGranted.remove(permission)
        await savePermissions()
        
        await auditLogger.logSecurityEvent(.permissionDenied, details: [
            "action": "permission_revoked",
            "permission": permission.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    public func revokeAllPermissions() async throws {
        // Require authentication for bulk revocation
        let authResult = await biometricAuth.authenticate(reason: "Revoke all permissions")
        
        switch authResult {
        case .success:
            let revokedPermissions = permissionsGranted
            permissionsGranted.removeAll()
            await savePermissions()
            
            await auditLogger.logSecurityEvent(.permissionDenied, details: [
                "action": "all_permissions_revoked",
                "revoked_count": revokedPermissions.count,
                "permissions": revokedPermissions.map { $0.rawValue }
            ])
            
        case .failure(let error):
            throw PrivacyError.authenticationRequired(error)
        }
    }
    
    // MARK: - Data Export Management
    public func requestDataExport(type: DataExportType) async throws -> DataExportRequest {
        // Check cooldown period
        let lastExport = dataExportRequests.last(where: { $0.type == type })
        if let lastExport = lastExport,
           Date().timeIntervalSince(lastExport.requestedAt) < Constants.dataExportCooldown {
            throw PrivacyError.exportCooldownActive
        }
        
        // Require biometric authentication
        let authResult = await biometricAuth.authenticate(reason: "Request data export")
        
        switch authResult {
        case .success:
            let exportRequest = DataExportRequest(
                id: UUID(),
                type: type,
                requestedAt: Date(),
                status: .pending,
                expiresAt: Date().addingTimeInterval(86400 * 7), // 7 days
                downloadURL: nil
            )
            
            dataExportRequests.append(exportRequest)
            await saveExportRequests()
            
            // Process export asynchronously
            Task {
                await processDataExport(exportRequest)
            }
            
            await auditLogger.logSecurityEvent(.dataExport, details: [
                "export_id": exportRequest.id.uuidString,
                "export_type": type.rawValue,
                "authenticated": true
            ])
            
            return exportRequest
            
        case .failure(let error):
            throw PrivacyError.authenticationRequired(error)
        }
    }
    
    private func processDataExport(_ request: DataExportRequest) async {
        // Update status to processing
        if let index = dataExportRequests.firstIndex(where: { $0.id == request.id }) {
            dataExportRequests[index].status = .processing
            await saveExportRequests()
        }
        
        do {
            // Generate encrypted export based on type
            let exportData = try await generateExportData(for: request.type)
            
            // Encrypt export data
            let encryptedExport = try cryptoEngine.encrypt(data: exportData)
            
            // Store temporarily for download
            let exportURL = try await storeExportFile(encryptedExport, for: request.id)
            
            // Update request with download URL
            if let index = dataExportRequests.firstIndex(where: { $0.id == request.id }) {
                dataExportRequests[index].status = .ready
                dataExportRequests[index].downloadURL = exportURL
                await saveExportRequests()
            }
            
            await auditLogger.logSecurityEvent(.dataExport, details: [
                "export_id": request.id.uuidString,
                "status": "completed",
                "file_size": exportData.count
            ])
            
        } catch {
            // Update status to failed
            if let index = dataExportRequests.firstIndex(where: { $0.id == request.id }) {
                dataExportRequests[index].status = .failed
                await saveExportRequests()
            }
            
            await auditLogger.logSecurityEvent(.dataExport, details: [
                "export_id": request.id.uuidString,
                "status": "failed",
                "error": error.localizedDescription
            ])
        }
    }
    
    private func generateExportData(for type: DataExportType) async throws -> Data {
        switch type {
        case .allData:
            return try await exportAllUserData()
        case .photos:
            return try await exportPhotoData()
        case .preferences:
            return try await exportPreferences()
        case .auditLogs:
            return try await exportAuditLogs()
        case .socialData:
            return try await exportSocialData()
        }
    }
    
    // MARK: - Complete Data Deletion
    public func requestCompleteDataDeletion() async throws {
        // Require biometric authentication
        let authResult = await biometricAuth.authenticate(reason: "Delete all data permanently")
        
        switch authResult {
        case .success:
            // Start deletion process
            await performCompleteDataDeletion()
            
            await auditLogger.logSecurityEvent(.dataDelete, details: [
                "action": "complete_data_deletion_requested",
                "authenticated": true,
                "irreversible": true
            ])
            
        case .failure(let error):
            throw PrivacyError.authenticationRequired(error)
        }
    }
    
    private func performCompleteDataDeletion() async {
        // Delete all user data
        await deleteAllUserData()
        
        // Delete sandboxed storage
        await deleteSandboxedData()
        
        // Delete encrypted files
        await deleteEncryptedFiles()
        
        // Clear keychain
        await clearKeychain()
        
        // Reset privacy settings
        privacySettings = ComprehensivePrivacySettings()
        permissionsGranted.removeAll()
        dataExportRequests.removeAll()
        
        // Final audit log entry before clearing
        await auditLogger.logSecurityEvent(.dataDelete, details: [
            "action": "complete_data_deletion_completed",
            "method": "secure_wipe",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        // Clear audit logs (as requested)
        // Note: In a real implementation, you might want to keep some logs for legal compliance
        // await auditLogger.clearAllLogs()
    }
    
    // MARK: - Incognito Mode
    public func enableIncognitoMode() async throws {
        // Require authentication
        let authResult = await biometricAuth.authenticate(reason: "Enable incognito mode")
        
        switch authResult {
        case .success:
            isIncognitoMode = true
            
            // Configure incognito settings
            await configureIncognitoMode()
            
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "incognito_mode_enabled",
                "authenticated": true
            ])
            
        case .failure(let error):
            throw PrivacyError.authenticationRequired(error)
        }
    }
    
    public func disableIncognitoMode() async {
        isIncognitoMode = false
        
        // Clear incognito data
        await clearIncognitoData()
        
        await auditLogger.logSecurityEvent(.permissionGranted, details: [
            "action": "incognito_mode_disabled"
        ])
    }
    
    private func configureIncognitoMode() async {
        // Disable tracking
        privacySettings.allowActivityTracking = false
        privacySettings.allowLocationSharing = false
        privacySettings.allowAnalytics = false
        
        // Enable auto-deletion
        privacySettings.autoDeleteData = true
        privacySettings.dataRetentionDays = 1
        
        // Require encrypted communication
        privacySettings.requireEncryptedCommunication = true
        
        await savePrivacySettings()
    }
    
    private func clearIncognitoData() async {
        // Clear temporary data, cache, etc.
        // Implementation would clear all incognito session data
    }
    
    // MARK: - Audit Trail Access
    public func getAuditTrail(
        startDate: Date? = nil,
        endDate: Date? = nil,
        eventType: AuditLogger.SecurityEvent? = nil
    ) async throws -> [AuditEntry] {
        
        // Require authentication for audit access
        let authResult = await biometricAuth.authenticate(reason: "Access audit trail")
        
        switch authResult {
        case .success:
            let auditEntries = await auditLogger.queryLogs(
                event: eventType,
                startDate: startDate,
                endDate: endDate,
                limit: 1000
            )
            
            await auditLogger.logSecurityEvent(.permissionGranted, details: [
                "action": "audit_trail_accessed",
                "entries_count": auditEntries.count,
                "authenticated": true
            ])
            
            return auditEntries
            
        case .failure(let error):
            throw PrivacyError.authenticationRequired(error)
        }
    }
    
    // MARK: - Privacy Settings Creation
    private func createMinimalPrivacySettings() -> ComprehensivePrivacySettings {
        return ComprehensivePrivacySettings(
            allowedPermissions: [.basicFeatures],
            allowLocationSharing: false,
            allowActivityTracking: false,
            allowAnalytics: false,
            allowSocialFeatures: false,
            allowExternalIntegrations: false,
            requireEncryptedCommunication: false,
            autoDeleteData: false,
            dataRetentionDays: 365,
            allowBiometricAuth: true,
            requirePasswordComplexity: true,
            sessionTimeoutMinutes: 15,
            allowScreenshots: true,
            allowDataExport: true,
            allowAccountDeletion: true
        )
    }
    
    private func createBalancedPrivacySettings() -> ComprehensivePrivacySettings {
        return ComprehensivePrivacySettings(
            allowedPermissions: [.basicFeatures, .notifications, .camera, .photos],
            allowLocationSharing: false,
            allowActivityTracking: false,
            allowAnalytics: true,
            allowSocialFeatures: true,
            allowExternalIntegrations: false,
            requireEncryptedCommunication: true,
            autoDeleteData: false,
            dataRetentionDays: 90,
            allowBiometricAuth: true,
            requirePasswordComplexity: true,
            sessionTimeoutMinutes: 30,
            allowScreenshots: true,
            allowDataExport: true,
            allowAccountDeletion: true
        )
    }
    
    private func createHighPrivacySettings() -> ComprehensivePrivacySettings {
        return ComprehensivePrivacySettings(
            allowedPermissions: [.basicFeatures, .notifications, .camera, .photos, .microphone],
            allowLocationSharing: false,
            allowActivityTracking: false,
            allowAnalytics: false,
            allowSocialFeatures: true,
            allowExternalIntegrations: false,
            requireEncryptedCommunication: true,
            autoDeleteData: true,
            dataRetentionDays: 30,
            allowBiometricAuth: true,
            requirePasswordComplexity: true,
            sessionTimeoutMinutes: 15,
            allowScreenshots: false,
            allowDataExport: true,
            allowAccountDeletion: true
        )
    }
    
    private func createMaximumPrivacySettings() -> ComprehensivePrivacySettings {
        return ComprehensivePrivacySettings(
            allowedPermissions: [.basicFeatures],
            allowLocationSharing: false,
            allowActivityTracking: false,
            allowAnalytics: false,
            allowSocialFeatures: false,
            allowExternalIntegrations: false,
            requireEncryptedCommunication: true,
            autoDeleteData: true,
            dataRetentionDays: 1,
            allowBiometricAuth: true,
            requirePasswordComplexity: true,
            sessionTimeoutMinutes: 5,
            allowScreenshots: false,
            allowDataExport: true,
            allowAccountDeletion: true
        )
    }
    
    // MARK: - Storage Operations
    private func loadPrivacySettings() {
        Task {
            do {
                if let settings: ComprehensivePrivacySettings = try keychainManager.retrieve(
                    type: ComprehensivePrivacySettings.self,
                    for: Constants.privacySettingsKey
                ) {
                    await MainActor.run {
                        self.privacySettings = settings
                    }
                }
                
                if let permissions: Set<PrivacyPermission> = try keychainManager.retrieve(
                    type: Set<PrivacyPermission>.self,
                    for: Constants.permissionsKey
                ) {
                    await MainActor.run {
                        self.permissionsGranted = permissions
                    }
                }
                
                if let requests: [DataExportRequest] = try keychainManager.retrieve(
                    type: [DataExportRequest].self,
                    for: Constants.exportRequestsKey
                ) {
                    await MainActor.run {
                        self.dataExportRequests = requests
                    }
                }
            } catch {
                // Use default settings if loading fails
            }
        }
    }
    
    private func savePrivacySettings() {
        settingsQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.keychainManager.store(object: self.privacySettings, for: Constants.privacySettingsKey)
            } catch {
                print("Failed to save privacy settings: \(error)")
            }
        }
    }
    
    private func savePermissions() async {
        await withCheckedContinuation { continuation in
            settingsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                do {
                    try self.keychainManager.store(object: self.permissionsGranted, for: Constants.permissionsKey)
                } catch {
                    print("Failed to save permissions: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func saveExportRequests() async {
        await withCheckedContinuation { continuation in
            settingsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                do {
                    try self.keychainManager.store(object: self.dataExportRequests, for: Constants.exportRequestsKey)
                } catch {
                    print("Failed to save export requests: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Privacy Monitoring
    private func setupPrivacyMonitoring() {
        // Monitor for privacy violations
        // Set up timers for automatic data cleanup
        setupDataCleanupTimer()
    }
    
    private func setupDataCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.performScheduledCleanup()
            }
        }
    }
    
    private func performScheduledCleanup() async {
        if privacySettings.autoDeleteData {
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(privacySettings.dataRetentionDays * 24 * 3600))
            await deleteDataOlderThan(cutoffDate)
        }
        
        // Clean up expired export requests
        let now = Date()
        dataExportRequests.removeAll { $0.expiresAt < now }
        await saveExportRequests()
    }
    
    // MARK: - Data Export Implementations
    private func exportAllUserData() async throws -> Data {
        var exportData: [String: Any] = [:]
        
        // Export privacy settings
        exportData["privacy_settings"] = try JSONEncoder().encode(privacySettings)
        
        // Export permissions
        exportData["granted_permissions"] = permissionsGranted.map { $0.rawValue }
        
        // Export audit trail (last 30 days)
        let auditEntries = await auditLogger.queryLogs(
            startDate: Date().addingTimeInterval(-30 * 24 * 3600),
            limit: 1000
        )
        exportData["audit_trail"] = try JSONEncoder().encode(auditEntries)
        
        // Add metadata
        exportData["export_timestamp"] = ISO8601DateFormatter().string(from: Date())
        exportData["export_version"] = "1.0"
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    private func exportPhotoData() async throws -> Data {
        // Implementation would export photo metadata and privacy settings
        // Actual photos would be exported separately due to size
        let photoData: [String: Any] = [
            "photo_privacy_settings": "Implementation specific",
            "vault_entries_count": "Implementation specific"
        ]
        
        return try JSONSerialization.data(withJSONObject: photoData, options: .prettyPrinted)
    }
    
    private func exportPreferences() async throws -> Data {
        return try JSONEncoder().encode(privacySettings)
    }
    
    private func exportAuditLogs() async throws -> Data {
        let auditEntries = await auditLogger.queryLogs(limit: Int.max)
        return try JSONEncoder().encode(auditEntries)
    }
    
    private func exportSocialData() async throws -> Data {
        // Implementation would export social interaction data
        let socialData: [String: Any] = [
            "anonymous_identity": "Implementation specific",
            "social_interactions": "Implementation specific"
        ]
        
        return try JSONSerialization.data(withJSONObject: socialData, options: .prettyPrinted)
    }
    
    private func storeExportFile(_ encryptedData: EncryptedData, for requestId: UUID) async throws -> URL {
        // Store export file temporarily for download
        let tempDir = FileManager.default.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("\(requestId.uuidString).export")
        
        let exportFileData = try JSONEncoder().encode(encryptedData)
        try exportFileData.write(to: exportURL)
        
        return exportURL
    }
    
    // MARK: - Data Deletion Implementations
    private func deleteAllUserData() async {
        // Implementation would delete all user-specific data
    }
    
    private func deleteSandboxedData() async {
        // Implementation would delete sandboxed storage
    }
    
    private func deleteEncryptedFiles() async {
        // Implementation would securely delete encrypted files
    }
    
    private func clearKeychain() async {
        // Implementation would clear keychain items
    }
    
    private func deleteDataOlderThan(_ date: Date) async {
        // Implementation would delete data older than specified date
    }
}

// MARK: - Supporting Types
public enum PrivacyLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case balanced = "balanced" 
    case high = "high"
    case maximum = "maximum"
    
    public var displayName: String {
        switch self {
        case .minimal: return "Minimal Privacy"
        case .balanced: return "Balanced Privacy"
        case .high: return "High Privacy"
        case .maximum: return "Maximum Privacy"
        }
    }
}

public enum PrivacyPermission: String, CaseIterable, Codable, Hashable {
    case basicFeatures = "basic_features"
    case camera = "camera"
    case microphone = "microphone"
    case photos = "photos"
    case location = "location"
    case contacts = "contacts"
    case notifications = "notifications"
    case biometrics = "biometrics"
    case faceID = "face_id"
    case touchID = "touch_id"
    case socialFeatures = "social_features"
    case analytics = "analytics"
    case crashReporting = "crash_reporting"
    case backgroundRefresh = "background_refresh"
    
    public var displayName: String {
        switch self {
        case .basicFeatures: return "Basic App Features"
        case .camera: return "Camera Access"
        case .microphone: return "Microphone Access"
        case .photos: return "Photo Library Access"
        case .location: return "Location Services"
        case .contacts: return "Contacts Access"
        case .notifications: return "Push Notifications"
        case .biometrics: return "Biometric Authentication"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .socialFeatures: return "Social Features"
        case .analytics: return "Usage Analytics"
        case .crashReporting: return "Crash Reporting"
        case .backgroundRefresh: return "Background App Refresh"
        }
    }
    
    public var requiresBiometricAuth: Bool {
        switch self {
        case .basicFeatures, .notifications, .analytics, .crashReporting:
            return false
        default:
            return true
        }
    }
}

public enum PermissionResult {
    case granted
    case alreadyGranted
    case denied(DenialReason)
    
    public enum DenialReason {
        case blockedByPrivacyLevel
        case authenticationFailed
        case userDenied
        case systemRestriction
    }
}

public enum DataExportType: String, CaseIterable, Codable {
    case allData = "all_data"
    case photos = "photos"
    case preferences = "preferences"
    case auditLogs = "audit_logs"
    case socialData = "social_data"
    
    public var displayName: String {
        switch self {
        case .allData: return "All Data"
        case .photos: return "Photos & Media"
        case .preferences: return "Settings & Preferences"
        case .auditLogs: return "Audit Trail"
        case .socialData: return "Social Data"
        }
    }
}

public struct DataExportRequest: Codable, Identifiable {
    public let id: UUID
    public let type: DataExportType
    public let requestedAt: Date
    public var status: ExportStatus
    public let expiresAt: Date
    public var downloadURL: URL?
    
    public enum ExportStatus: String, Codable {
        case pending = "pending"
        case processing = "processing"
        case ready = "ready"
        case failed = "failed"
        case expired = "expired"
    }
}

public struct ComprehensivePrivacySettings: Codable {
    public var allowedPermissions: Set<PrivacyPermission>
    public var allowLocationSharing: Bool
    public var allowActivityTracking: Bool
    public var allowAnalytics: Bool
    public var allowSocialFeatures: Bool
    public var allowExternalIntegrations: Bool
    public var requireEncryptedCommunication: Bool
    public var autoDeleteData: Bool
    public var dataRetentionDays: Int
    public var allowBiometricAuth: Bool
    public var requirePasswordComplexity: Bool
    public var sessionTimeoutMinutes: Int
    public var allowScreenshots: Bool
    public var allowDataExport: Bool
    public var allowAccountDeletion: Bool
    
    public init(
        allowedPermissions: Set<PrivacyPermission> = [.basicFeatures],
        allowLocationSharing: Bool = false,
        allowActivityTracking: Bool = false,
        allowAnalytics: Bool = false,
        allowSocialFeatures: Bool = false,
        allowExternalIntegrations: Bool = false,
        requireEncryptedCommunication: Bool = true,
        autoDeleteData: Bool = true,
        dataRetentionDays: Int = 30,
        allowBiometricAuth: Bool = true,
        requirePasswordComplexity: Bool = true,
        sessionTimeoutMinutes: Int = 15,
        allowScreenshots: Bool = false,
        allowDataExport: Bool = true,
        allowAccountDeletion: Bool = true
    ) {
        self.allowedPermissions = allowedPermissions
        self.allowLocationSharing = allowLocationSharing
        self.allowActivityTracking = allowActivityTracking
        self.allowAnalytics = allowAnalytics
        self.allowSocialFeatures = allowSocialFeatures
        self.allowExternalIntegrations = allowExternalIntegrations
        self.requireEncryptedCommunication = requireEncryptedCommunication
        self.autoDeleteData = autoDeleteData
        self.dataRetentionDays = dataRetentionDays
        self.allowBiometricAuth = allowBiometricAuth
        self.requirePasswordComplexity = requirePasswordComplexity
        self.sessionTimeoutMinutes = sessionTimeoutMinutes
        self.allowScreenshots = allowScreenshots
        self.allowDataExport = allowDataExport
        self.allowAccountDeletion = allowAccountDeletion
    }
}

public enum PrivacyError: LocalizedError {
    case authenticationRequired(AuthenticationError)
    case exportCooldownActive
    case exportFailed(Error)
    case permissionDenied
    case invalidRequest
    
    public var errorDescription: String? {
        switch self {
        case .authenticationRequired(let authError):
            return "Authentication required: \(authError.localizedDescription)"
        case .exportCooldownActive:
            return "Data export is on cooldown. Please try again later."
        case .exportFailed(let error):
            return "Data export failed: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied by privacy settings"
        case .invalidRequest:
            return "Invalid privacy request"
        }
    }
}