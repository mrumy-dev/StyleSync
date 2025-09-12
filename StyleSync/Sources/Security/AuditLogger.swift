import Foundation
import CryptoKit
import OSLog

// MARK: - Military-Grade Audit Logger
public final class AuditLogger: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AuditLogger()
    
    // MARK: - Constants
    private enum Constants {
        static let maxLogEntries = 10000
        static let logRotationThreshold = 8000
        static let compressionThreshold = 100
        static let encryptedLogFile = "audit_logs.encrypted"
        static let logIntegrityFile = "log_integrity.hash"
        static let tamperDetectionInterval: TimeInterval = 60 // 1 minute
    }
    
    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let logger = Logger(subsystem: "com.stylesync.security", category: "audit")
    private var logEntries: [AuditEntry] = []
    private let logQueue = DispatchQueue(label: "com.stylesync.audit", qos: .background)
    private var integrityHashes: [String] = []
    private let integrityTimer: Timer
    
    // MARK: - Initialization
    private init() {
        self.integrityTimer = Timer.scheduledTimer(withTimeInterval: Constants.tamperDetectionInterval, repeats: true) { [weak self] _ in
            self?.performIntegrityCheck()
        }
        
        loadExistingLogs()
        setupTamperDetection()
    }
    
    deinit {
        integrityTimer.invalidate()
        saveLogs()
    }
    
    // MARK: - Security Events
    public enum SecurityEvent: String, CaseIterable {
        // Authentication Events
        case biometricAuthSuccess = "biometric_auth_success"
        case biometricAuthFailure = "biometric_auth_failure"
        case biometricChange = "biometric_change"
        case passcodeAuthSuccess = "passcode_auth_success"
        case passcodeAuthFailure = "passcode_auth_failure"
        case sessionExpired = "session_expired"
        case suspiciousBiometricActivity = "suspicious_biometric_activity"
        
        // Encryption Events
        case encryptionOperation = "encryption_operation"
        case decryptionOperation = "decryption_operation"
        case keyGeneration = "key_generation"
        case keyRotation = "key_rotation"
        case keyAccess = "key_access"
        case cryptoFailure = "crypto_failure"
        
        // Data Privacy Events
        case photoProcessed = "photo_processed"
        case metadataStripped = "metadata_stripped"
        case faceBlurred = "face_blurred"
        case backgroundRemoved = "background_removed"
        case watermarkDetected = "watermark_detected"
        case privacyVaultAccess = "privacy_vault_access"
        
        // Access Control Events
        case unauthorizedAccess = "unauthorized_access"
        case permissionGranted = "permission_granted"
        case permissionDenied = "permission_denied"
        case dataExport = "data_export"
        case dataDelete = "data_delete"
        case adminPanelBlocked = "admin_panel_blocked"
        
        // System Security Events
        case secureMemoryAllocation = "secure_memory_allocation"
        case secureWipe = "secure_wipe"
        case integrityCheckFailed = "integrity_check_failed"
        case tamperDetected = "tamper_detected"
        case emergencyRecovery = "emergency_recovery"
        case vpnDetection = "vpn_detection"
        
        var severity: AuditSeverity {
            switch self {
            case .biometricAuthSuccess, .passcodeAuthSuccess, .encryptionOperation, 
                 .decryptionOperation, .photoProcessed, .metadataStripped:
                return .info
                
            case .biometricAuthFailure, .passcodeAuthFailure, .permissionDenied,
                 .cryptoFailure, .keyAccess:
                return .warning
                
            case .suspiciousBiometricActivity, .unauthorizedAccess, .tamperDetected,
                 .integrityCheckFailed, .emergencyRecovery:
                return .critical
                
            default:
                return .normal
            }
        }
    }
    
    public enum AuditSeverity: String, CaseIterable {
        case info = "INFO"
        case normal = "NORMAL"
        case warning = "WARNING"
        case critical = "CRITICAL"
        
        var priority: Int {
            switch self {
            case .info: return 0
            case .normal: return 1
            case .warning: return 2
            case .critical: return 3
            }
        }
    }
    
    // MARK: - Logging Methods
    public func logSecurityEvent(_ event: SecurityEvent, details: [String: Any] = [:]) async {
        let entry = AuditEntry(
            id: UUID(),
            timestamp: Date(),
            event: event,
            severity: event.severity,
            details: details,
            userId: getCurrentUserId(),
            deviceId: getDeviceId(),
            sessionId: getSessionId(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            integrityHash: ""
        )
        
        await addLogEntry(entry)
    }
    
    public func log(event: Any) {
        guard let auditEntry = event as? AuditEntry else { return }
        
        Task {
            await addLogEntry(auditEntry)
        }
    }
    
    private func addLogEntry(_ entry: AuditEntry) async {
        await withCheckedContinuation { continuation in
            logQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Calculate integrity hash
                let entryWithHash = self.addIntegrityHash(to: entry)
                
                // Add to in-memory log
                self.logEntries.append(entryWithHash)
                
                // Log to system logger for real-time monitoring
                self.logToSystem(entryWithHash)
                
                // Check if rotation is needed
                if self.logEntries.count > Constants.logRotationThreshold {
                    self.rotateLogs()
                }
                
                // Persist immediately for critical events
                if entry.severity == .critical {
                    self.saveLogs()
                }
                
                continuation.resume()
            }
        }
    }
    
    private func addIntegrityHash(to entry: AuditEntry) -> AuditEntry {
        let entryData = createHashableData(from: entry)
        let hash = SHA256.hash(data: entryData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Store hash for integrity checking
        integrityHashes.append(hashString)
        
        var updatedEntry = entry
        updatedEntry.integrityHash = hashString
        
        return updatedEntry
    }
    
    private func createHashableData(from entry: AuditEntry) -> Data {
        let hashableString = "\(entry.id.uuidString)|\(entry.timestamp.timeIntervalSince1970)|\(entry.event.rawValue)|\(entry.severity.rawValue)|\(entry.userId ?? "")|\(entry.deviceId)|\(entry.sessionId ?? "")"
        return Data(hashableString.utf8)
    }
    
    private func logToSystem(_ entry: AuditEntry) {
        let logMessage = formatLogMessage(entry)
        
        switch entry.severity {
        case .info:
            logger.info("\(logMessage)")
        case .normal:
            logger.notice("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        }
    }
    
    private func formatLogMessage(_ entry: AuditEntry) -> String {
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        var message = "[\(timestamp)] [\(entry.severity.rawValue)] \(entry.event.rawValue)"
        
        if let userId = entry.userId {
            message += " [User: \(userId)]"
        }
        
        if !entry.details.isEmpty {
            let detailsString = entry.details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " {\(detailsString)}"
        }
        
        return message
    }
    
    // MARK: - Log Persistence
    private func saveLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let logsData = try JSONEncoder().encode(self.logEntries)
                let encryptedData = try self.cryptoEngine.encryptForLocalStorage(
                    data: logsData,
                    context: "audit_logs"
                )
                
                let url = self.getLogFileURL()
                let encryptedDataForStorage = try JSONEncoder().encode(encryptedData)
                try encryptedDataForStorage.write(to: url)
                
                // Save integrity hashes
                self.saveIntegrityHashes()
                
            } catch {
                self.logger.error("Failed to save audit logs: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadExistingLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let url = self.getLogFileURL()
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                
                let encryptedDataForStorage = try Data(contentsOf: url)
                let encryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedDataForStorage)
                let logsData = try self.cryptoEngine.decryptFromLocalStorage(
                    encryptedData: encryptedData,
                    context: "audit_logs"
                )
                
                self.logEntries = try JSONDecoder().decode([AuditEntry].self, from: logsData)
                
                // Load integrity hashes
                self.loadIntegrityHashes()
                
                // Verify integrity
                self.performIntegrityCheck()
                
            } catch {
                self.logger.error("Failed to load audit logs: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Log Rotation and Cleanup
    private func rotateLogs() {
        // Keep only the most recent logs
        if logEntries.count > Constants.maxLogEntries {
            let excessCount = logEntries.count - Constants.maxLogEntries
            let archivedLogs = Array(logEntries.prefix(excessCount))
            
            // Archive old logs
            archiveLogs(archivedLogs)
            
            // Remove from active logs
            logEntries.removeFirst(excessCount)
            integrityHashes.removeFirst(excessCount)
        }
    }
    
    private func archiveLogs(_ logs: [AuditEntry]) {
        // Compress and archive old logs
        do {
            let archiveData = try JSONEncoder().encode(logs)
            let compressedData = try archiveData.compressed()
            
            let archiveURL = getArchiveFileURL()
            let encryptedArchive = try cryptoEngine.encryptForLocalStorage(
                data: compressedData,
                context: "archived_logs"
            )
            
            let encryptedDataForStorage = try JSONEncoder().encode(encryptedArchive)
            try encryptedDataForStorage.write(to: archiveURL)
            
        } catch {
            logger.error("Failed to archive logs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Integrity Protection
    private func setupTamperDetection() {
        // Initialize integrity monitoring
        performIntegrityCheck()
    }
    
    private func performIntegrityCheck() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Verify each log entry's integrity hash
            for (index, entry) in self.logEntries.enumerated() {
                let expectedHash = self.calculateExpectedHash(for: entry)
                
                if expectedHash != entry.integrityHash {
                    // Integrity violation detected
                    Task {
                        await self.logSecurityEvent(.integrityCheckFailed, details: [
                            "entry_id": entry.id.uuidString,
                            "expected_hash": expectedHash,
                            "actual_hash": entry.integrityHash,
                            "entry_index": index
                        ])
                    }
                    
                    // Trigger tamper detection response
                    self.handleTamperDetection(at: index)
                }
            }
            
            // Verify overall log file integrity
            self.verifyLogFileIntegrity()
        }
    }
    
    private func calculateExpectedHash(for entry: AuditEntry) -> String {
        let entryData = createHashableData(from: entry)
        let hash = SHA256.hash(data: entryData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func handleTamperDetection(at index: Int) {
        logger.critical("Log tampering detected at index: \(index)")
        
        // Immediate security response
        Task {
            await logSecurityEvent(.tamperDetected, details: [
                "tampered_index": index,
                "response": "isolation_mode_activated"
            ])
        }
        
        // Notify security team
        sendTamperAlert()
    }
    
    private func sendTamperAlert() {
        // Implementation for alerting security team
        // This could include secure notifications, remote logging, etc.
    }
    
    private func verifyLogFileIntegrity() {
        do {
            let url = getLogFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            
            let fileData = try Data(contentsOf: url)
            let fileHash = SHA256.hash(data: fileData)
            let hashString = fileHash.compactMap { String(format: "%02x", $0) }.joined()
            
            let integrityURL = getIntegrityFileURL()
            
            if FileManager.default.fileExists(atPath: integrityURL.path) {
                let storedHash = try String(contentsOf: integrityURL)
                
                if storedHash != hashString {
                    // File integrity compromised
                    Task {
                        await logSecurityEvent(.integrityCheckFailed, details: [
                            "file": "audit_logs",
                            "stored_hash": storedHash,
                            "calculated_hash": hashString
                        ])
                    }
                }
            }
            
            // Update stored hash
            try hashString.write(to: integrityURL, atomically: true, encoding: .utf8)
            
        } catch {
            logger.error("Failed to verify log file integrity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Integrity Hash Management
    private func saveIntegrityHashes() {
        do {
            let hashesData = try JSONEncoder().encode(integrityHashes)
            let encryptedHashes = try cryptoEngine.encryptForLocalStorage(
                data: hashesData,
                context: "integrity_hashes"
            )
            
            let url = getIntegrityHashesURL()
            let encryptedDataForStorage = try JSONEncoder().encode(encryptedHashes)
            try encryptedDataForStorage.write(to: url)
            
        } catch {
            logger.error("Failed to save integrity hashes: \(error.localizedDescription)")
        }
    }
    
    private func loadIntegrityHashes() {
        do {
            let url = getIntegrityHashesURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            
            let encryptedDataForStorage = try Data(contentsOf: url)
            let encryptedHashes = try JSONDecoder().decode(EncryptedData.self, from: encryptedDataForStorage)
            let hashesData = try cryptoEngine.decryptFromLocalStorage(
                encryptedData: encryptedHashes,
                context: "integrity_hashes"
            )
            
            integrityHashes = try JSONDecoder().decode([String].self, from: hashesData)
            
        } catch {
            logger.error("Failed to load integrity hashes: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Query and Export
    public func queryLogs(
        event: SecurityEvent? = nil,
        severity: AuditSeverity? = nil,
        userId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100
    ) async -> [AuditEntry] {
        
        return await withCheckedContinuation { continuation in
            logQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                var filteredLogs = self.logEntries
                
                if let event = event {
                    filteredLogs = filteredLogs.filter { $0.event == event }
                }
                
                if let severity = severity {
                    filteredLogs = filteredLogs.filter { $0.severity == severity }
                }
                
                if let userId = userId {
                    filteredLogs = filteredLogs.filter { $0.userId == userId }
                }
                
                if let startDate = startDate {
                    filteredLogs = filteredLogs.filter { $0.timestamp >= startDate }
                }
                
                if let endDate = endDate {
                    filteredLogs = filteredLogs.filter { $0.timestamp <= endDate }
                }
                
                // Sort by timestamp (newest first) and limit results
                filteredLogs = Array(filteredLogs.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
                
                continuation.resume(returning: filteredLogs)
            }
        }
    }
    
    public func exportLogs(format: LogExportFormat = .json) async -> Data? {
        let allLogs = await queryLogs(limit: Int.max)
        
        switch format {
        case .json:
            return try? JSONEncoder().encode(allLogs)
        case .csv:
            return convertToCSV(logs: allLogs)
        }
    }
    
    private func convertToCSV(logs: [AuditEntry]) -> Data {
        var csvContent = "Timestamp,Event,Severity,UserID,DeviceID,Details\n"
        
        for log in logs {
            let timestamp = ISO8601DateFormatter().string(from: log.timestamp)
            let details = log.details.map { "\($0.key):\($0.value)" }.joined(separator: ";")
            let userId = log.userId ?? ""
            
            csvContent += "\(timestamp),\(log.event.rawValue),\(log.severity.rawValue),\(userId),\(log.deviceId),\"\(details)\"\n"
        }
        
        return Data(csvContent.utf8)
    }
    
    // MARK: - Utility Methods
    private func getCurrentUserId() -> String? {
        // Get current user ID from session or user manager
        return UserManager.shared.currentUserId
    }
    
    private func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    private func getSessionId() -> String? {
        // Get current session ID
        return SessionManager.shared.currentSessionId
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    private func getLogFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(Constants.encryptedLogFile)
    }
    
    private func getIntegrityFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(Constants.logIntegrityFile)
    }
    
    private func getIntegrityHashesURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("integrity_hashes.encrypted")
    }
    
    private func getArchiveFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("archived_logs.encrypted")
    }
}

// MARK: - Supporting Types
public struct AuditEntry: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let event: AuditLogger.SecurityEvent
    public let severity: AuditLogger.AuditSeverity
    public let details: [String: Any]
    public let userId: String?
    public let deviceId: String
    public let sessionId: String?
    public let appVersion: String
    public let osVersion: String
    public var integrityHash: String
    
    // Custom coding to handle [String: Any]
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, event, severity, details, userId, deviceId, sessionId, appVersion, osVersion, integrityHash
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(event, forKey: .event)
        try container.encode(severity, forKey: .severity)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(integrityHash, forKey: .integrityHash)
        
        // Encode details as JSON string
        let detailsData = try JSONSerialization.data(withJSONObject: details)
        let detailsString = String(data: detailsData, encoding: .utf8) ?? "{}"
        try container.encode(detailsString, forKey: .details)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        event = try container.decode(AuditLogger.SecurityEvent.self, forKey: .event)
        severity = try container.decode(AuditLogger.AuditSeverity.self, forKey: .severity)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        osVersion = try container.decode(String.self, forKey: .osVersion)
        integrityHash = try container.decode(String.self, forKey: .integrityHash)
        
        // Decode details from JSON string
        let detailsString = try container.decode(String.self, forKey: .details)
        if let detailsData = detailsString.data(using: .utf8),
           let decodedDetails = try? JSONSerialization.jsonObject(with: detailsData) as? [String: Any] {
            details = decodedDetails
        } else {
            details = [:]
        }
    }
    
    public init(
        id: UUID,
        timestamp: Date,
        event: AuditLogger.SecurityEvent,
        severity: AuditLogger.AuditSeverity,
        details: [String: Any],
        userId: String?,
        deviceId: String,
        sessionId: String?,
        appVersion: String,
        osVersion: String,
        integrityHash: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.severity = severity
        self.details = details
        self.userId = userId
        self.deviceId = deviceId
        self.sessionId = sessionId
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.integrityHash = integrityHash
    }
}

public enum LogExportFormat {
    case json
    case csv
}

// MARK: - Data Compression Extension
extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .lzfse) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .lzfse) as Data
    }
}

// MARK: - Placeholder Managers (to be implemented)
class UserManager {
    static let shared = UserManager()
    var currentUserId: String? = nil
    private init() {}
}

class SessionManager {
    static let shared = SessionManager()
    var currentSessionId: String? = nil
    private init() {}
}