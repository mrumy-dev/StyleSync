import Foundation
import CloudKit
import CryptoKit
import Network

// MARK: - Zero Knowledge Sync Manager

@MainActor
class ZeroKnowledgeSync: ObservableObject {
    static let shared = ZeroKnowledgeSync()

    @Published var syncStatus: SyncStatus = .idle
    @Published var encryptedRecordsCount: Int = 0
    @Published var lastSyncDate: Date?
    @Published var conflictResolutionNeeded: [SyncConflict] = []

    private let cloudContainer = CKContainer.default()
    private let privateDatabase: CKDatabase
    private let encryptionManager = ZKEncryptionManager()
    private let conflictResolver = ConflictResolver()
    private let networkMonitor = NWPathMonitor()

    enum SyncStatus {
        case idle
        case syncing
        case uploading(progress: Double)
        case downloading(progress: Double)
        case resolving
        case completed
        case error(String)
        case offline
    }

    private init() {
        privateDatabase = cloudContainer.privateCloudDatabase
        setupNetworkMonitoring()
        setupConflictResolution()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied {
                    if self?.syncStatus == .offline {
                        await self?.resumeSync()
                    }
                } else {
                    self?.syncStatus = .offline
                }
            }
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    private func setupConflictResolution() {
        conflictResolver.onConflictDetected = { [weak self] conflict in
            Task { @MainActor in
                self?.conflictResolutionNeeded.append(conflict)
            }
        }
    }

    // MARK: - Zero Knowledge Encryption

    func syncUserData<T: Codable & ZeroKnowledgeSyncable>(_ data: [T]) async throws {
        guard networkMonitor.currentPath.status == .satisfied else {
            syncStatus = .offline
            return
        }

        syncStatus = .syncing

        do {
            // Step 1: Generate client-side encryption keys
            let encryptionKeys = try await encryptionManager.generateSyncKeys()

            // Step 2: Encrypt data with zero-knowledge guarantees
            let encryptedRecords = try await encryptDataForSync(data, keys: encryptionKeys)

            // Step 3: Upload encrypted data to CloudKit
            syncStatus = .uploading(progress: 0.0)
            try await uploadEncryptedRecords(encryptedRecords)

            // Step 4: Update local sync state
            await updateSyncState()

            syncStatus = .completed
            lastSyncDate = Date()

            HapticManager.HapticType.success.trigger()
            SoundManager.SoundType.success.play(volume: 0.5)

        } catch {
            syncStatus = .error(error.localizedDescription)
            HapticManager.HapticType.error.trigger()
            throw error
        }
    }

    func downloadAndDecryptData<T: Codable & ZeroKnowledgeSyncable>(
        type: T.Type
    ) async throws -> [T] {
        guard networkMonitor.currentPath.status == .satisfied else {
            throw ZKSyncError.offline
        }

        syncStatus = .downloading(progress: 0.0)

        do {
            // Step 1: Download encrypted records from CloudKit
            let encryptedRecords = try await downloadEncryptedRecords(for: T.recordType)

            // Step 2: Decrypt with zero-knowledge keys
            let decryptedData = try await decryptRecordsFromSync(encryptedRecords, type: T.self)

            // Step 3: Resolve any conflicts
            let resolvedData = await resolveConflicts(decryptedData)

            syncStatus = .completed
            return resolvedData

        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Encryption Operations

    private func encryptDataForSync<T: Codable>(
        _ data: [T],
        keys: ZKEncryptionKeys
    ) async throws -> [EncryptedRecord] {
        return try await withThrowingTaskGroup(of: EncryptedRecord.self) { group in
            var encryptedRecords: [EncryptedRecord] = []

            for item in data {
                group.addTask {
                    return try await self.encryptionManager.encryptForZKSync(item, keys: keys)
                }
            }

            for try await record in group {
                encryptedRecords.append(record)
            }

            return encryptedRecords
        }
    }

    private func decryptRecordsFromSync<T: Codable>(
        _ records: [CKRecord],
        type: T.Type
    ) async throws -> [T] {
        return try await withThrowingTaskGroup(of: T?.self) { group in
            var decryptedItems: [T] = []

            for record in records {
                group.addTask {
                    return try await self.encryptionManager.decryptFromZKSync(record, type: T.self)
                }
            }

            for try await item in group {
                if let item = item {
                    decryptedItems.append(item)
                }
            }

            return decryptedItems
        }
    }

    // MARK: - CloudKit Operations

    private func uploadEncryptedRecords(_ records: [EncryptedRecord]) async throws {
        let ckRecords = records.map { createCKRecord(from: $0) }
        let operation = CKModifyRecordsOperation(recordsToSave: ckRecords)

        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        var uploadedCount = 0
        operation.perRecordProgressBlock = { _, progress in
            uploadedCount += 1
            let overallProgress = Double(uploadedCount) / Double(ckRecords.count)
            Task { @MainActor in
                self.syncStatus = .uploading(progress: overallProgress)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            privateDatabase.add(operation)
        }
    }

    private func downloadEncryptedRecords(for recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)

        operation.qualityOfService = .userInitiated

        var records: [CKRecord] = []
        var downloadedCount = 0

        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { recordID, result in
                downloadedCount += 1
                Task { @MainActor in
                    let progress = Double(downloadedCount) / 100.0 // Estimate
                    self.syncStatus = .downloading(progress: min(progress, 1.0))
                }

                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("Failed to download record \(recordID): \(error)")
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            privateDatabase.add(operation)
        }
    }

    private func createCKRecord(from encryptedRecord: EncryptedRecord) -> CKRecord {
        let record = CKRecord(
            recordType: encryptedRecord.recordType,
            recordID: CKRecord.ID(recordName: encryptedRecord.id)
        )

        record["encryptedData"] = encryptedRecord.encryptedData
        record["metadata"] = encryptedRecord.metadata
        record["version"] = encryptedRecord.version
        record["lastModified"] = encryptedRecord.lastModified

        return record
    }

    // MARK: - Conflict Resolution

    private func resolveConflicts<T: Codable>(_ data: [T]) async -> [T] {
        // Implement automatic conflict resolution using last-write-wins
        // or more sophisticated merging strategies
        return data
    }

    func resolveConflictManually(_ conflict: SyncConflict, choice: ConflictChoice) async {
        syncStatus = .resolving

        do {
            try await conflictResolver.resolveConflict(conflict, choice: choice)

            // Remove resolved conflict
            conflictResolutionNeeded.removeAll { $0.id == conflict.id }

            if conflictResolutionNeeded.isEmpty {
                syncStatus = .completed
            }

        } catch {
            syncStatus = .error("Failed to resolve conflict: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Management

    private func updateSyncState() async {
        encryptedRecordsCount += 1
        lastSyncDate = Date()

        // Update local sync metadata
        UserDefaults.standard.set(lastSyncDate, forKey: "lastZKSyncDate")
        UserDefaults.standard.set(encryptedRecordsCount, forKey: "encryptedRecordsCount")
    }

    private func resumeSync() async {
        if syncStatus == .offline {
            syncStatus = .idle
            // Resume any pending sync operations
            await performIncrementalSync()
        }
    }

    private func performIncrementalSync() async {
        guard let lastSync = lastSyncDate else { return }

        // Sync only changes since last sync
        let predicate = NSPredicate(format: "modificationDate > %@", lastSync as NSDate)
        // Implement incremental sync logic
    }

    // MARK: - Key Management

    func rotateEncryptionKeys() async throws {
        try await encryptionManager.rotateKeys()
        HapticManager.HapticType.success.trigger()
    }

    func exportBackupKeys() -> String {
        return encryptionManager.exportBackupKeys()
    }

    func importBackupKeys(_ keys: String) throws {
        try encryptionManager.importBackupKeys(keys)
    }
}

// MARK: - Zero Knowledge Encryption Manager

private class ZKEncryptionManager {
    private let keyStore = EncryptedKeyStore()

    struct ZKEncryptionKeys {
        let dataKey: SymmetricKey
        let metadataKey: SymmetricKey
        let authKey: SymmetricKey
    }

    func generateSyncKeys() async throws -> ZKEncryptionKeys {
        return ZKEncryptionKeys(
            dataKey: SymmetricKey(size: .bits256),
            metadataKey: SymmetricKey(size: .bits256),
            authKey: SymmetricKey(size: .bits256)
        )
    }

    func encryptForZKSync<T: Codable>(_ data: T, keys: ZKEncryptionKeys) async throws -> EncryptedRecord {
        // Serialize data
        let jsonData = try JSONEncoder().encode(data)

        // Encrypt with data key
        let sealedBox = try AES.GCM.seal(jsonData, using: keys.dataKey)

        // Create metadata
        let metadata = SyncMetadata(
            type: String(describing: T.self),
            size: jsonData.count,
            timestamp: Date(),
            deviceId: await getDeviceId()
        )

        let metadataData = try JSONEncoder().encode(metadata)
        let encryptedMetadata = try AES.GCM.seal(metadataData, using: keys.metadataKey)

        // Create authentication tag
        let authData = sealedBox.combined! + encryptedMetadata.combined!
        let authTag = HMAC<SHA256>.authenticationCode(for: authData, using: keys.authKey)

        return EncryptedRecord(
            id: UUID().uuidString,
            recordType: String(describing: T.self),
            encryptedData: sealedBox.combined!,
            metadata: encryptedMetadata.combined!,
            authenticationTag: Data(authTag),
            version: 1,
            lastModified: Date()
        )
    }

    func decryptFromZKSync<T: Codable>(_ record: CKRecord, type: T.Type) async throws -> T? {
        guard let encryptedData = record["encryptedData"] as? Data,
              let encryptedMetadata = record["metadata"] as? Data,
              let authTag = record["authenticationTag"] as? Data else {
            throw ZKSyncError.corruptedData
        }

        // Retrieve keys for this record
        let keys = try await retrieveKeys(for: record.recordID.recordName)

        // Verify authentication
        let authData = encryptedData + encryptedMetadata
        let expectedAuthTag = HMAC<SHA256>.authenticationCode(for: authData, using: keys.authKey)

        guard authTag == Data(expectedAuthTag) else {
            throw ZKSyncError.authenticationFailed
        }

        // Decrypt data
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: keys.dataKey)

        // Deserialize
        return try JSONDecoder().decode(T.self, from: decryptedData)
    }

    private func getDeviceId() async -> String {
        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private func retrieveKeys(for recordId: String) async throws -> ZKEncryptionKeys {
        // In production, retrieve keys from Keychain or Secure Enclave
        return ZKEncryptionKeys(
            dataKey: SymmetricKey(size: .bits256),
            metadataKey: SymmetricKey(size: .bits256),
            authKey: SymmetricKey(size: .bits256)
        )
    }

    func rotateKeys() async throws {
        // Implement key rotation logic
        try await keyStore.rotateAllKeys()
    }

    func exportBackupKeys() -> String {
        // Export keys for backup (encrypted with user password)
        return keyStore.exportKeys()
    }

    func importBackupKeys(_ keys: String) throws {
        // Import keys from backup
        try keyStore.importKeys(keys)
    }
}

// MARK: - Encrypted Key Store

private class EncryptedKeyStore {
    func rotateAllKeys() async throws {
        // Implement key rotation in Keychain
    }

    func exportKeys() -> String {
        // Export encrypted keys
        return "encrypted_keys_backup"
    }

    func importKeys(_ keys: String) throws {
        // Import and decrypt keys
    }
}

// MARK: - Conflict Resolution

private class ConflictResolver {
    var onConflictDetected: ((SyncConflict) -> Void)?

    func resolveConflict(_ conflict: SyncConflict, choice: ConflictChoice) async throws {
        switch choice {
        case .useLocal:
            try await applyLocalVersion(conflict)
        case .useRemote:
            try await applyRemoteVersion(conflict)
        case .merge:
            try await mergeVersions(conflict)
        }
    }

    private func applyLocalVersion(_ conflict: SyncConflict) async throws {
        // Keep local version, upload to remote
    }

    private func applyRemoteVersion(_ conflict: SyncConflict) async throws {
        // Keep remote version, update local
    }

    private func mergeVersions(_ conflict: SyncConflict) async throws {
        // Attempt automatic merge
    }
}

// MARK: - Data Structures

struct EncryptedRecord {
    let id: String
    let recordType: String
    let encryptedData: Data
    let metadata: Data
    let authenticationTag: Data
    let version: Int
    let lastModified: Date
}

struct SyncMetadata: Codable {
    let type: String
    let size: Int
    let timestamp: Date
    let deviceId: String
}

struct SyncConflict: Identifiable {
    let id = UUID()
    let recordId: String
    let localVersion: Date
    let remoteVersion: Date
    let conflictType: ConflictType

    enum ConflictType {
        case dataConflict
        case deletionConflict
        case schemaConflict
    }
}

enum ConflictChoice {
    case useLocal
    case useRemote
    case merge
}

// MARK: - Protocols

protocol ZeroKnowledgeSyncable {
    static var recordType: String { get }
    var syncId: String { get }
    var lastModified: Date { get }
}

// MARK: - Errors

enum ZKSyncError: LocalizedError {
    case offline
    case corruptedData
    case authenticationFailed
    case keyNotFound
    case conflictResolutionFailed

    var errorDescription: String? {
        switch self {
        case .offline:
            return "Device is offline"
        case .corruptedData:
            return "Sync data is corrupted"
        case .authenticationFailed:
            return "Authentication failed"
        case .keyNotFound:
            return "Encryption key not found"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflict"
        }
    }
}

#Preview {
    VStack {
        Text("Zero Knowledge Sync")
            .font(.title)
        Text("End-to-end encrypted cloud synchronization")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}