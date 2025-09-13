import Foundation
import SwiftUI
import CryptoKit
import os.log

@MainActor
public final class ComprehensiveAuditSystem: ObservableObject {

    // MARK: - Singleton
    public static let shared = ComprehensiveAuditSystem()

    // MARK: - Published Properties
    @Published public var auditingEnabled = true
    @Published public var realTimeMonitoring = true
    @Published public var anomalyDetectionEnabled = true
    @Published public var complianceMode: ComplianceMode = .gdpr
    @Published public var auditLevel: AuditLevel = .standard
    @Published public var retentionPeriod: TimeInterval = 2_592_000 // 30 days
    @Published public var logIntegrityStatus: LogIntegrityStatus = .verified
    @Published public var activeAnomalies: [AnomalyAlert] = []
    @Published public var auditStatistics = AuditStatistics()
    @Published public var breachDetectionStatus: BreachDetectionStatus = .monitoring

    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let logger = Logger(subsystem: "com.stylesync.audit", category: "security")
    private let dataFlowTracker = DataFlowTracker()
    private let permissionTracker = PermissionTracker()
    private let accessLogger = AccessLogger()
    private let exportLogger = ExportLogger()
    private let breachDetector = BreachDetector()
    private let anomalyDetector = AnomalyDetector()
    private let integrityVerifier = LogIntegrityVerifier()
    private let complianceReporter = ComplianceReporter()
    private let alertManager = AlertManager()

    private var auditQueue = DispatchQueue(label: "com.stylesync.audit.queue", qos: .utility)
    private var realTimeMonitoringTimer: Timer?
    private var integrityVerificationTimer: Timer?
    private var auditCleanupTimer: Timer?
    private var anomalyCheckTimer: Timer?

    // MARK: - Storage
    private var auditLogs: [AuditLogEntry] = []
    private var dataFlowLogs: [DataFlowEntry] = []
    private var accessLogs: [AccessLogEntry] = []
    private var permissionLogs: [PermissionLogEntry] = []
    private var exportLogs: [ExportLogEntry] = []
    private var breachAlerts: [BreachAlert] = []
    private var complianceReports: [ComplianceReport] = []

    // MARK: - Constants
    private enum Constants {
        static let maxLogEntries = 100000
        static let realTimeMonitoringInterval: TimeInterval = 10 // 10 seconds
        static let integrityCheckInterval: TimeInterval = 3600 // 1 hour
        static let cleanupInterval: TimeInterval = 86400 // 24 hours
        static let anomalyCheckInterval: TimeInterval = 300 // 5 minutes
        static let maxAnomalies = 50
        static let maxBreachAlerts = 25
        static let logRotationSize = 10 * 1024 * 1024 // 10MB
    }

    private init() {
        Task {
            await initializeAuditSystem()
        }
    }

    // MARK: - Initialization
    private func initializeAuditSystem() async {
        await loadExistingLogs()
        await startMonitoring()
        await verifyLogIntegrity()

        await logAuditEvent(.systemInitialized, details: [
            "audit_level": auditLevel.rawValue,
            "compliance_mode": complianceMode.rawValue,
            "real_time_monitoring": realTimeMonitoring,
            "anomaly_detection": anomalyDetectionEnabled,
            "retention_period_days": retentionPeriod / 86400
        ])
    }

    // MARK: - Core Audit Logging
    public func logAuditEvent(
        _ type: AuditEventType,
        details: [String: Any],
        severity: AuditSeverity = .info,
        userId: String? = nil,
        sessionId: String? = nil
    ) async {
        guard auditingEnabled else { return }

        let entry = AuditLogEntry(
            id: UUID(),
            timestamp: Date(),
            eventType: type,
            severity: severity,
            userId: userId,
            sessionId: sessionId,
            details: details,
            deviceId: await getDeviceId(),
            ipAddress: await getCurrentIPAddress(),
            userAgent: await getUserAgent(),
            checksum: ""
        )

        // Calculate integrity checksum
        let checksumEntry = entry.withChecksum(calculateChecksum(for: entry))

        auditLogs.append(checksumEntry)
        await saveAuditLog(checksumEntry)

        // Update statistics
        await updateAuditStatistics(entry: checksumEntry)

        // Check for anomalies in real-time
        if anomalyDetectionEnabled && realTimeMonitoring {
            await checkForAnomalies(entry: checksumEntry)
        }

        // Trigger compliance checks if needed
        if complianceMode.requiresRealTimeReporting {
            await checkComplianceRequirements(entry: checksumEntry)
        }

        // System logging for debugging
        logger.log(level: severity.osLogLevel, "\(type.rawValue): \(details)")
    }

    // MARK: - Access Logging
    public func logDataAccess(
        resource: String,
        operation: DataOperation,
        userId: String?,
        result: AccessResult,
        dataSize: Int? = nil,
        dataTypes: [String] = []
    ) async {
        let accessEntry = AccessLogEntry(
            id: UUID(),
            timestamp: Date(),
            userId: userId,
            resource: resource,
            operation: operation,
            result: result,
            dataSize: dataSize,
            dataTypes: dataTypes,
            source: await getAccessSource(),
            duration: nil
        )

        accessLogs.append(accessEntry)
        await saveAccessLog(accessEntry)

        // Log as audit event
        await logAuditEvent(.dataAccessed, details: [
            "resource": resource,
            "operation": operation.rawValue,
            "result": result.rawValue,
            "data_size": dataSize ?? 0,
            "data_types": dataTypes
        ], severity: result == .denied ? .warning : .info, userId: userId)

        await accessLogger.track(accessEntry)
    }

    // MARK: - Data Flow Tracking
    public func trackDataFlow(
        from source: DataSource,
        to destination: DataDestination,
        dataType: String,
        dataSize: Int,
        purpose: String,
        userId: String?,
        encrypted: Bool = false,
        anonymized: Bool = false
    ) async {
        let flowEntry = DataFlowEntry(
            id: UUID(),
            timestamp: Date(),
            source: source,
            destination: destination,
            dataType: dataType,
            dataSize: dataSize,
            purpose: purpose,
            userId: userId,
            encrypted: encrypted,
            anonymized: anonymized,
            legalBasis: getLegalBasis(for: purpose),
            retentionPeriod: getRetentionPeriod(for: dataType)
        )

        dataFlowLogs.append(flowEntry)
        await saveDataFlowLog(flowEntry)

        await dataFlowTracker.track(flowEntry)

        await logAuditEvent(.dataTransferred, details: [
            "source": source.rawValue,
            "destination": destination.rawValue,
            "data_type": dataType,
            "data_size": dataSize,
            "purpose": purpose,
            "encrypted": encrypted,
            "anonymized": anonymized
        ], userId: userId)
    }

    // MARK: - Permission Tracking
    public func logPermissionChange(
        permission: String,
        granted: Bool,
        userId: String,
        requestedBy: String?,
        reason: String?
    ) async {
        let permissionEntry = PermissionLogEntry(
            id: UUID(),
            timestamp: Date(),
            userId: userId,
            permission: permission,
            granted: granted,
            requestedBy: requestedBy,
            reason: reason,
            automaticGrant: requestedBy == nil,
            expiresAt: getPermissionExpiry(permission: permission)
        )

        permissionLogs.append(permissionEntry)
        await savePermissionLog(permissionEntry)

        await permissionTracker.track(permissionEntry)

        await logAuditEvent(.permissionChanged, details: [
            "permission": permission,
            "granted": granted,
            "requested_by": requestedBy ?? "system",
            "reason": reason ?? "automatic",
            "expires_at": permissionEntry.expiresAt?.iso8601String ?? "never"
        ], severity: granted ? .info : .warning, userId: userId)
    }

    // MARK: - Export Logging
    public func logDataExport(
        userId: String,
        dataTypes: [String],
        format: ExportFormat,
        destination: ExportDestination,
        fileSize: Int,
        encryptionUsed: Bool
    ) async {
        let exportEntry = ExportLogEntry(
            id: UUID(),
            timestamp: Date(),
            userId: userId,
            dataTypes: dataTypes,
            format: format,
            destination: destination,
            fileSize: fileSize,
            encryptionUsed: encryptionUsed,
            downloadExpiry: Date().addingTimeInterval(604800), // 7 days
            downloaded: false,
            deletedAt: nil
        )

        exportLogs.append(exportEntry)
        await saveExportLog(exportEntry)

        await exportLogger.track(exportEntry)

        await logAuditEvent(.dataExported, details: [
            "data_types": dataTypes,
            "format": format.rawValue,
            "destination": destination.rawValue,
            "file_size": fileSize,
            "encryption_used": encryptionUsed
        ], userId: userId)
    }

    // MARK: - Breach Detection
    public func reportSecurityBreach(
        type: BreachType,
        severity: BreachSeverity,
        description: String,
        affectedData: [String],
        estimatedAffectedUsers: Int,
        discoveredBy: String
    ) async {
        breachDetectionStatus = .breachDetected

        let breachAlert = BreachAlert(
            id: UUID(),
            timestamp: Date(),
            type: type,
            severity: severity,
            description: description,
            affectedData: affectedData,
            estimatedAffectedUsers: estimatedAffectedUsers,
            discoveredBy: discoveredBy,
            status: .reported,
            containmentActions: [],
            notificationsSent: false,
            regulatoryReported: false
        )

        breachAlerts.append(breachAlert)
        await saveBreachAlert(breachAlert)

        await breachDetector.processBreach(breachAlert)

        await logAuditEvent(.securityBreach, details: [
            "breach_type": type.rawValue,
            "severity": severity.rawValue,
            "description": description,
            "affected_data_types": affectedData,
            "estimated_affected_users": estimatedAffectedUsers,
            "discovered_by": discoveredBy
        ], severity: .critical)

        // Trigger compliance notifications
        await handleBreachComplianceRequirements(breachAlert)
    }

    // MARK: - Anomaly Detection
    private func checkForAnomalies(entry: AuditLogEntry) async {
        let anomalies = await anomalyDetector.detectAnomalies(
            in: auditLogs.suffix(100),
            newEntry: entry
        )

        for anomaly in anomalies {
            await handleAnomaly(anomaly)
        }
    }

    private func handleAnomaly(_ anomaly: AnomalyAlert) async {
        activeAnomalies.append(anomaly)

        // Limit active anomalies
        if activeAnomalies.count > Constants.maxAnomalies {
            activeAnomalies.removeFirst(activeAnomalies.count - Constants.maxAnomalies)
        }

        await alertManager.sendAnomaly(anomaly)

        await logAuditEvent(.anomalyDetected, details: [
            "anomaly_type": anomaly.type.rawValue,
            "risk_level": anomaly.riskLevel.rawValue,
            "description": anomaly.description,
            "confidence": anomaly.confidence
        ], severity: anomaly.riskLevel == .high ? .warning : .info)
    }

    // MARK: - Compliance Reporting
    public func generateComplianceReport(
        type: ComplianceReportType,
        startDate: Date,
        endDate: Date
    ) async -> ComplianceReport {
        let report = await complianceReporter.generateReport(
            type: type,
            startDate: startDate,
            endDate: endDate,
            auditLogs: auditLogs,
            dataFlowLogs: dataFlowLogs,
            accessLogs: accessLogs,
            permissionLogs: permissionLogs,
            exportLogs: exportLogs,
            breachAlerts: breachAlerts
        )

        complianceReports.append(report)
        await saveComplianceReport(report)

        await logAuditEvent(.complianceReportGenerated, details: [
            "report_type": type.rawValue,
            "start_date": startDate.iso8601String,
            "end_date": endDate.iso8601String,
            "total_events": report.totalEvents,
            "compliance_score": report.complianceScore
        ])

        return report
    }

    // MARK: - Third-Party Audit Support
    public func prepareThirdPartyAudit(
        auditorId: String,
        scope: AuditScope,
        startDate: Date,
        endDate: Date
    ) async -> ThirdPartyAuditPackage {
        let package = ThirdPartyAuditPackage(
            id: UUID(),
            auditorId: auditorId,
            scope: scope,
            startDate: startDate,
            endDate: endDate,
            createdAt: Date(),
            auditLogs: filterLogsForThirdParty(startDate: startDate, endDate: endDate),
            systemConfiguration: await getSystemConfiguration(),
            complianceStatus: await getComplianceStatus(),
            integrityVerification: await verifyLogsIntegrity(startDate: startDate, endDate: endDate)
        )

        await logAuditEvent(.thirdPartyAuditPrepared, details: [
            "auditor_id": auditorId,
            "scope": scope.rawValue,
            "start_date": startDate.iso8601String,
            "end_date": endDate.iso8601String,
            "log_entries": package.auditLogs.count
        ])

        return package
    }

    // MARK: - Log Integrity and Security
    private func calculateChecksum(for entry: AuditLogEntry) -> String {
        let data = "\(entry.timestamp.iso8601String)\(entry.eventType.rawValue)\(entry.details)".data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func verifyLogIntegrity() async {
        logIntegrityStatus = .verifying

        let verificationResult = await integrityVerifier.verifyIntegrity(of: auditLogs)

        logIntegrityStatus = verificationResult.isValid ? .verified : .compromised

        if !verificationResult.isValid {
            await logAuditEvent(.logIntegrityFailure, details: [
                "failed_entries": verificationResult.failedEntries.count,
                "corruption_detected": verificationResult.corruptionDetected,
                "tampering_suspected": verificationResult.tamperingDetected
            ], severity: .critical)

            await handleIntegrityFailure(verificationResult)
        }
    }

    private func handleIntegrityFailure(_ result: IntegrityVerificationResult) async {
        // Log integrity failure
        await reportSecurityBreach(
            type: .dataIntegrityCompromise,
            severity: .high,
            description: "Audit log integrity verification failed",
            affectedData: ["audit_logs"],
            estimatedAffectedUsers: 0,
            discoveredBy: "automated_integrity_check"
        )

        // Trigger additional security measures
        await alertManager.sendCriticalAlert("Audit log integrity compromised")
    }

    // MARK: - Monitoring and Timers
    private func startMonitoring() async {
        if realTimeMonitoring {
            startRealTimeMonitoring()
        }

        startIntegrityVerificationTimer()
        startCleanupTimer()

        if anomalyDetectionEnabled {
            startAnomalyDetectionTimer()
        }
    }

    private func startRealTimeMonitoring() {
        realTimeMonitoringTimer = Timer.scheduledTimer(withTimeInterval: Constants.realTimeMonitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performRealTimeChecks()
            }
        }
    }

    private func startIntegrityVerificationTimer() {
        integrityVerificationTimer = Timer.scheduledTimer(withTimeInterval: Constants.integrityCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.verifyLogIntegrity()
            }
        }
    }

    private func startCleanupTimer() {
        auditCleanupTimer = Timer.scheduledTimer(withTimeInterval: Constants.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performLogCleanup()
            }
        }
    }

    private func startAnomalyDetectionTimer() {
        anomalyCheckTimer = Timer.scheduledTimer(withTimeInterval: Constants.anomalyCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAnomalyDetection()
            }
        }
    }

    private func performRealTimeChecks() async {
        await updateAuditStatistics()
        await checkStorageLimits()
        await monitorSystemHealth()
    }

    private func performAnomalyDetection() async {
        let recentLogs = auditLogs.suffix(100)
        let anomalies = await anomalyDetector.detectBatchAnomalies(Array(recentLogs))

        for anomaly in anomalies {
            await handleAnomaly(anomaly)
        }
    }

    private func performLogCleanup() async {
        let cutoffDate = Date().addingTimeInterval(-retentionPeriod)

        // Clean old logs
        auditLogs.removeAll { $0.timestamp < cutoffDate }
        accessLogs.removeAll { $0.timestamp < cutoffDate }
        dataFlowLogs.removeAll { $0.timestamp < cutoffDate }
        permissionLogs.removeAll { $0.timestamp < cutoffDate }

        // Archive old logs before deletion
        await archiveOldLogs(before: cutoffDate)

        await logAuditEvent(.logCleanupPerformed, details: [
            "cutoff_date": cutoffDate.iso8601String,
            "remaining_audit_logs": auditLogs.count,
            "remaining_access_logs": accessLogs.count
        ])
    }

    // MARK: - Statistics and Monitoring
    private func updateAuditStatistics(entry: AuditLogEntry? = nil) async {
        auditStatistics.totalEvents = auditLogs.count
        auditStatistics.totalAccessEvents = accessLogs.count
        auditStatistics.totalDataFlows = dataFlowLogs.count
        auditStatistics.totalPermissionChanges = permissionLogs.count
        auditStatistics.totalExports = exportLogs.count
        auditStatistics.activeAnomalies = activeAnomalies.count
        auditStatistics.activeBreach = breachAlerts.contains { $0.status == .investigating }

        // Calculate event rates
        let last24Hours = Date().addingTimeInterval(-86400)
        auditStatistics.eventsLast24Hours = auditLogs.filter { $0.timestamp > last24Hours }.count

        // Update severity distribution
        updateSeverityDistribution()

        // Update compliance metrics
        auditStatistics.complianceScore = await calculateComplianceScore()
    }

    private func updateSeverityDistribution() {
        let last24HourEvents = auditLogs.filter { $0.timestamp > Date().addingTimeInterval(-86400) }

        auditStatistics.severityDistribution = [
            .info: last24HourEvents.filter { $0.severity == .info }.count,
            .warning: last24HourEvents.filter { $0.severity == .warning }.count,
            .error: last24HourEvents.filter { $0.severity == .error }.count,
            .critical: last24HourEvents.filter { $0.severity == .critical }.count
        ]
    }

    private func calculateComplianceScore() async -> Double {
        return await complianceReporter.calculateComplianceScore(
            auditLogs: auditLogs,
            dataFlowLogs: dataFlowLogs,
            mode: complianceMode
        )
    }

    // MARK: - Helper Methods
    private func getDeviceId() async -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private func getCurrentIPAddress() async -> String? {
        // Implementation would get actual IP address
        return "127.0.0.1"
    }

    private func getUserAgent() async -> String {
        // Implementation would get actual user agent
        return "StyleSync/1.0"
    }

    private func getAccessSource() async -> AccessSource {
        return .application
    }

    private func getLegalBasis(for purpose: String) -> String {
        // Determine legal basis based on purpose
        switch purpose {
        case "user_consent": return "consent"
        case "contract_fulfillment": return "contract"
        case "legal_obligation": return "legal_obligation"
        case "legitimate_interest": return "legitimate_interest"
        default: return "consent"
        }
    }

    private func getRetentionPeriod(for dataType: String) -> TimeInterval {
        // Return appropriate retention period based on data type and compliance requirements
        return retentionPeriod
    }

    private func getPermissionExpiry(permission: String) -> Date? {
        // Return expiry date for temporary permissions
        return nil
    }

    private func checkComplianceRequirements(entry: AuditLogEntry) async {
        if complianceMode.requiresImmediateNotification(for: entry.eventType) {
            await complianceReporter.sendImmediateNotification(entry)
        }
    }

    private func handleBreachComplianceRequirements(_ breach: BreachAlert) async {
        await complianceReporter.handleBreachNotification(breach, mode: complianceMode)
    }

    // MARK: - Storage Operations (Mock)
    private func loadExistingLogs() async {
        // Implementation would load persisted logs
    }

    private func saveAuditLog(_ entry: AuditLogEntry) async {
        // Implementation would persist audit log
    }

    private func saveAccessLog(_ entry: AccessLogEntry) async {
        // Implementation would persist access log
    }

    private func saveDataFlowLog(_ entry: DataFlowEntry) async {
        // Implementation would persist data flow log
    }

    private func savePermissionLog(_ entry: PermissionLogEntry) async {
        // Implementation would persist permission log
    }

    private func saveExportLog(_ entry: ExportLogEntry) async {
        // Implementation would persist export log
    }

    private func saveBreachAlert(_ alert: BreachAlert) async {
        // Implementation would persist breach alert
    }

    private func saveComplianceReport(_ report: ComplianceReport) async {
        // Implementation would persist compliance report
    }

    private func archiveOldLogs(before date: Date) async {
        // Implementation would archive old logs to long-term storage
    }

    private func checkStorageLimits() async {
        if auditLogs.count > Constants.maxLogEntries {
            await performLogRotation()
        }
    }

    private func performLogRotation() async {
        let oldLogs = auditLogs.prefix(auditLogs.count - Constants.maxLogEntries/2)
        await archiveOldLogs(before: Date())
        auditLogs.removeFirst(oldLogs.count)
    }

    private func monitorSystemHealth() async {
        // Monitor system health metrics
    }

    private func filterLogsForThirdParty(startDate: Date, endDate: Date) -> [AuditLogEntry] {
        return auditLogs.filter { log in
            log.timestamp >= startDate && log.timestamp <= endDate
        }.map { log in
            // Sanitize logs for third party - remove sensitive details
            return log.sanitizedForThirdParty()
        }
    }

    private func getSystemConfiguration() async -> [String: Any] {
        return [
            "audit_level": auditLevel.rawValue,
            "compliance_mode": complianceMode.rawValue,
            "retention_period_days": retentionPeriod / 86400,
            "real_time_monitoring": realTimeMonitoring,
            "anomaly_detection": anomalyDetectionEnabled
        ]
    }

    private func getComplianceStatus() async -> [String: Any] {
        return [
            "compliance_score": auditStatistics.complianceScore,
            "last_report_date": complianceReports.last?.generatedAt.iso8601String ?? "never",
            "active_breaches": breachAlerts.filter { $0.status == .investigating }.count,
            "log_integrity": logIntegrityStatus.rawValue
        ]
    }

    private func verifyLogsIntegrity(startDate: Date, endDate: Date) async -> IntegrityVerificationResult {
        let logsToVerify = auditLogs.filter { log in
            log.timestamp >= startDate && log.timestamp <= endDate
        }

        return await integrityVerifier.verifyIntegrity(of: logsToVerify)
    }

    // MARK: - Public API
    public func getAuditStatistics() -> AuditStatistics {
        return auditStatistics
    }

    public func searchAuditLogs(
        criteria: AuditSearchCriteria
    ) async -> [AuditLogEntry] {
        return auditLogs.filter { log in
            criteria.matches(log)
        }
    }

    public func exportAuditLogs(
        format: ExportFormat,
        startDate: Date,
        endDate: Date
    ) async -> URL {
        // Implementation would export logs in specified format
        return URL(fileURLWithPath: "/tmp/audit_export.json")
    }

    // MARK: - Cleanup
    deinit {
        realTimeMonitoringTimer?.invalidate()
        integrityVerificationTimer?.invalidate()
        auditCleanupTimer?.invalidate()
        anomalyCheckTimer?.invalidate()
    }
}

// MARK: - Supporting Types and Extensions
extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

extension AuditLogEntry {
    func withChecksum(_ checksum: String) -> AuditLogEntry {
        return AuditLogEntry(
            id: self.id,
            timestamp: self.timestamp,
            eventType: self.eventType,
            severity: self.severity,
            userId: self.userId,
            sessionId: self.sessionId,
            details: self.details,
            deviceId: self.deviceId,
            ipAddress: self.ipAddress,
            userAgent: self.userAgent,
            checksum: checksum
        )
    }

    func sanitizedForThirdParty() -> AuditLogEntry {
        // Remove sensitive information for third-party audits
        var sanitizedDetails = self.details
        sanitizedDetails.removeValue(forKey: "user_id")
        sanitizedDetails.removeValue(forKey: "ip_address")
        sanitizedDetails.removeValue(forKey: "session_id")

        return AuditLogEntry(
            id: self.id,
            timestamp: self.timestamp,
            eventType: self.eventType,
            severity: self.severity,
            userId: nil,
            sessionId: nil,
            details: sanitizedDetails,
            deviceId: "redacted",
            ipAddress: nil,
            userAgent: nil,
            checksum: self.checksum
        )
    }
}

extension AuditSeverity {
    var osLogLevel: OSLogType {
        switch self {
        case .info: return .info
        case .warning: return .error
        case .error: return .error
        case .critical: return .fault
        }
    }
}

extension ComplianceMode {
    var requiresRealTimeReporting: Bool {
        switch self {
        case .gdpr, .ccpa, .hipaa:
            return true
        case .none:
            return false
        }
    }

    func requiresImmediateNotification(for eventType: AuditEventType) -> Bool {
        switch self {
        case .gdpr:
            return eventType == .securityBreach || eventType == .dataExported
        case .ccpa:
            return eventType == .dataExported
        case .hipaa:
            return eventType == .securityBreach || eventType == .dataAccessed
        case .none:
            return false
        }
    }
}