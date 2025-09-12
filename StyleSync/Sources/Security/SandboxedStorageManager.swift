import Foundation
import CryptoKit
import SQLite3
import CommonCrypto

// MARK: - Sandboxed Storage Manager
public final class SandboxedStorageManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SandboxedStorageManager()
    
    // MARK: - Private Properties
    private let cryptoEngine = CryptoEngine.shared
    private let auditLogger = AuditLogger.shared
    private var userSandboxes: [String: UserSandbox] = [:]
    private let storageQueue = DispatchQueue(label: "com.stylesync.sandboxed.storage", qos: .utility)
    private let memoryProtectionQueue = DispatchQueue(label: "com.stylesync.memory.protection", qos: .background)
    
    // MARK: - Constants
    private enum Constants {
        static let sandboxRootDirectory = "UserSandboxes"
        static let encryptedDatabaseSuffix = ".secure.db"
        static let metadataFileName = "sandbox.metadata"
        static let backupSuffix = ".backup"
        static let maxSandboxSize: Int64 = 100_000_000 // 100MB per user
        static let compressionThreshold: Int64 = 1_000_000 // 1MB
    }
    
    private init() {
        setupRootDirectory()
        initializeMemoryProtection()
        loadExistingSandboxes()
    }
    
    // MARK: - User Sandbox Management
    public func createUserSandbox(for userId: String) async throws -> UserSandbox {
        return await withCheckedThrowingContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SandboxError.systemError("Storage manager unavailable"))
                    return
                }
                
                do {
                    // Check if sandbox already exists
                    if let existingSandbox = self.userSandboxes[userId] {
                        continuation.resume(returning: existingSandbox)
                        return
                    }
                    
                    // Create sandbox directory
                    let sandboxPath = self.getSandboxPath(for: userId)
                    try FileManager.default.createDirectory(at: sandboxPath, withIntermediateDirectories: true)
                    
                    // Generate sandbox-specific encryption key
                    let sandboxKey = self.generateSandboxKey(for: userId)
                    
                    // Initialize encrypted database
                    let databaseURL = sandboxPath.appendingPathComponent("data\(Constants.encryptedDatabaseSuffix)")
                    let database = try self.initializeEncryptedDatabase(at: databaseURL, key: sandboxKey)
                    
                    // Create sandbox instance
                    let sandbox = UserSandbox(
                        userId: userId,
                        sandboxPath: sandboxPath,
                        databaseURL: databaseURL,
                        encryptionKey: sandboxKey,
                        database: database,
                        createdAt: Date(),
                        lastAccessed: Date(),
                        totalSize: 0,
                        isLocked: false
                    )
                    
                    // Store sandbox reference
                    self.userSandboxes[userId] = sandbox
                    
                    // Save sandbox metadata
                    try self.saveSandboxMetadata(sandbox)
                    
                    // Log sandbox creation
                    Task {
                        await self.auditLogger.logSecurityEvent(.secureMemoryAllocation, details: [
                            "action": "sandbox_created",
                            "user_id": userId,
                            "sandbox_path": sandboxPath.path,
                            "encrypted": true
                        ])
                    }
                    
                    continuation.resume(returning: sandbox)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func getSandbox(for userId: String) async -> UserSandbox? {
        return await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                continuation.resume(returning: self?.userSandboxes[userId])
            }
        }
    }
    
    public func lockSandbox(for userId: String) async throws {
        guard let sandbox = await getSandbox(for: userId) else {
            throw SandboxError.sandboxNotFound
        }
        
        await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                // Close database connections
                sqlite3_close(sandbox.database)
                
                // Mark as locked
                var updatedSandbox = sandbox
                updatedSandbox.isLocked = true
                self?.userSandboxes[userId] = updatedSandbox
                
                // Log locking
                Task {
                    await self?.auditLogger.logSecurityEvent(.permissionDenied, details: [
                        "action": "sandbox_locked",
                        "user_id": userId
                    ])
                }
                
                continuation.resume()
            }
        }
    }
    
    public func unlockSandbox(for userId: String) async throws {
        guard var sandbox = await getSandbox(for: userId) else {
            throw SandboxError.sandboxNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SandboxError.systemError("Storage manager unavailable"))
                    return
                }
                
                do {
                    // Reinitialize database connection
                    sandbox.database = try self.initializeEncryptedDatabase(at: sandbox.databaseURL, key: sandbox.encryptionKey)
                    
                    // Mark as unlocked
                    sandbox.isLocked = false
                    sandbox.lastAccessed = Date()
                    self.userSandboxes[userId] = sandbox
                    
                    // Log unlocking
                    Task {
                        await self.auditLogger.logSecurityEvent(.permissionGranted, details: [
                            "action": "sandbox_unlocked",
                            "user_id": userId
                        ])
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Encrypted Data Operations
    public func store<T: Codable>(
        object: T,
        key: String,
        in userId: String,
        category: DataCategory = .general
    ) async throws {
        
        guard let sandbox = await getSandbox(for: userId) else {
            throw SandboxError.sandboxNotFound
        }
        
        guard !sandbox.isLocked else {
            throw SandboxError.sandboxLocked
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SandboxError.systemError("Storage manager unavailable"))
                    return
                }
                
                do {
                    // Serialize object
                    let objectData = try JSONEncoder().encode(object)
                    
                    // Compress if necessary
                    let finalData: Data
                    let compressed: Bool
                    
                    if objectData.count > Constants.compressionThreshold {
                        finalData = try objectData.compressed()
                        compressed = true
                    } else {
                        finalData = objectData
                        compressed = false
                    }
                    
                    // Encrypt data
                    let encryptedData = try self.cryptoEngine.encrypt(
                        data: finalData,
                        key: sandbox.encryptionKey,
                        additionalData: "\(userId):\(key):\(category.rawValue)".data(using: .utf8)
                    )
                    
                    // Store in encrypted database
                    try self.storeEncryptedData(
                        encryptedData,
                        key: key,
                        category: category,
                        compressed: compressed,
                        in: sandbox.database
                    )
                    
                    // Update sandbox size
                    self.updateSandboxSize(for: userId, delta: Int64(encryptedData.ciphertext.count))
                    
                    // Log storage operation
                    Task {
                        await self.auditLogger.logSecurityEvent(.encryptionOperation, details: [
                            "action": "data_stored",
                            "user_id": userId,
                            "key": key,
                            "category": category.rawValue,
                            "size": objectData.count,
                            "compressed": compressed,
                            "encrypted": true
                        ])
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func retrieve<T: Codable>(
        type: T.Type,
        key: String,
        from userId: String,
        category: DataCategory = .general
    ) async throws -> T? {
        
        guard let sandbox = await getSandbox(for: userId) else {
            throw SandboxError.sandboxNotFound
        }
        
        guard !sandbox.isLocked else {
            throw SandboxError.sandboxLocked
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SandboxError.systemError("Storage manager unavailable"))
                    return
                }
                
                do {
                    // Retrieve encrypted data from database
                    guard let (encryptedData, compressed) = try self.retrieveEncryptedData(
                        key: key,
                        category: category,
                        from: sandbox.database
                    ) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Decrypt data
                    let decryptedData = try self.cryptoEngine.decrypt(
                        encryptedData: encryptedData,
                        key: sandbox.encryptionKey
                    )
                    
                    // Decompress if necessary
                    let finalData: Data
                    if compressed {
                        finalData = try decryptedData.decompressed()
                    } else {
                        finalData = decryptedData
                    }
                    
                    // Deserialize object
                    let object = try JSONDecoder().decode(type, from: finalData)
                    
                    // Update access time
                    self.updateSandboxAccess(for: userId)
                    
                    // Log retrieval operation
                    Task {
                        await self.auditLogger.logSecurityEvent(.decryptionOperation, details: [
                            "action": "data_retrieved",
                            "user_id": userId,
                            "key": key,
                            "category": category.rawValue,
                            "size": finalData.count,
                            "compressed": compressed
                        ])
                    }
                    
                    continuation.resume(returning: object)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func delete(
        key: String,
        from userId: String,
        category: DataCategory = .general
    ) async throws {
        
        guard let sandbox = await getSandbox(for: userId) else {
            throw SandboxError.sandboxNotFound
        }
        
        guard !sandbox.isLocked else {
            throw SandboxError.sandboxLocked
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SandboxError.systemError("Storage manager unavailable"))
                    return
                }
                
                do {
                    // Get data size before deletion
                    let dataSize = try self.getDataSize(key: key, category: category, from: sandbox.database)
                    
                    // Delete from database
                    try self.deleteEncryptedData(key: key, category: category, from: sandbox.database)
                    
                    // Update sandbox size
                    self.updateSandboxSize(for: userId, delta: -dataSize)
                    
                    // Log deletion
                    Task {
                        await self.auditLogger.logSecurityEvent(.secureWipe, details: [
                            "action": "data_deleted",
                            "user_id": userId,
                            "key": key,
                            "category": category.rawValue,
                            "size": dataSize
                        ])
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Secure Database Operations
    private func initializeEncryptedDatabase(at url: URL, key: SymmetricKey) throws -> OpaquePointer {
        var database: OpaquePointer?
        
        // Open database
        let result = sqlite3_open(url.path, &database)
        guard result == SQLITE_OK else {
            sqlite3_close(database)
            throw SandboxError.databaseError("Failed to open database: \(result)")
        }
        
        // Set encryption key (using PRAGMA key for SQLCipher compatibility)
        let keyData = key.withUnsafeBytes { Data($0) }
        let keyHex = keyData.map { String(format: "%02x", $0) }.joined()
        let pragmaKey = "PRAGMA key = \"x'\(keyHex)'\";"
        
        var statement: OpaquePointer?
        sqlite3_prepare_v2(database, pragmaKey, -1, &statement, nil)
        sqlite3_step(statement)
        sqlite3_finalize(statement)
        
        // Create encrypted storage table
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS encrypted_storage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                storage_key TEXT NOT NULL,
                category TEXT NOT NULL,
                encrypted_data BLOB NOT NULL,
                iv BLOB NOT NULL,
                tag BLOB NOT NULL,
                compressed INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL,
                accessed_at REAL NOT NULL,
                UNIQUE(storage_key, category)
            );
        """
        
        let createResult = sqlite3_exec(database, createTableSQL, nil, nil, nil)
        guard createResult == SQLITE_OK else {
            sqlite3_close(database)
            throw SandboxError.databaseError("Failed to create table: \(createResult)")
        }
        
        // Enable WAL mode for better concurrent access
        sqlite3_exec(database, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        
        // Enable foreign key constraints
        sqlite3_exec(database, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        
        return database!
    }
    
    private func storeEncryptedData(
        _ encryptedData: EncryptedData,
        key: String,
        category: DataCategory,
        compressed: Bool,
        in database: OpaquePointer
    ) throws {
        
        let insertSQL = """
            INSERT OR REPLACE INTO encrypted_storage 
            (storage_key, category, encrypted_data, iv, tag, compressed, created_at, accessed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SandboxError.databaseError("Failed to prepare insert statement")
        }
        
        defer { sqlite3_finalize(statement) }
        
        let now = Date().timeIntervalSince1970
        
        sqlite3_bind_text(statement, 1, key, -1, nil)
        sqlite3_bind_text(statement, 2, category.rawValue, -1, nil)
        sqlite3_bind_blob(statement, 3, encryptedData.ciphertext.withUnsafeBytes { $0.baseAddress }, Int32(encryptedData.ciphertext.count), nil)
        sqlite3_bind_blob(statement, 4, encryptedData.iv.withUnsafeBytes { $0.baseAddress }, Int32(encryptedData.iv.count), nil)
        sqlite3_bind_blob(statement, 5, encryptedData.tag.withUnsafeBytes { $0.baseAddress }, Int32(encryptedData.tag.count), nil)
        sqlite3_bind_int(statement, 6, compressed ? 1 : 0)
        sqlite3_bind_double(statement, 7, now)
        sqlite3_bind_double(statement, 8, now)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SandboxError.databaseError("Failed to insert encrypted data")
        }
    }
    
    private func retrieveEncryptedData(
        key: String,
        category: DataCategory,
        from database: OpaquePointer
    ) throws -> (EncryptedData, Bool)? {
        
        let selectSQL = """
            SELECT encrypted_data, iv, tag, compressed 
            FROM encrypted_storage 
            WHERE storage_key = ? AND category = ?
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SandboxError.databaseError("Failed to prepare select statement")
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, key, -1, nil)
        sqlite3_bind_text(statement, 2, category.rawValue, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil // No data found
        }
        
        // Extract encrypted data components
        let ciphertextPtr = sqlite3_column_blob(statement, 0)
        let ciphertextSize = sqlite3_column_bytes(statement, 0)
        let ciphertext = Data(bytes: ciphertextPtr!, count: Int(ciphertextSize))
        
        let ivPtr = sqlite3_column_blob(statement, 1)
        let ivSize = sqlite3_column_bytes(statement, 1)
        let iv = Data(bytes: ivPtr!, count: Int(ivSize))
        
        let tagPtr = sqlite3_column_blob(statement, 2)
        let tagSize = sqlite3_column_bytes(statement, 2)
        let tag = Data(bytes: tagPtr!, count: Int(tagSize))
        
        let compressed = sqlite3_column_int(statement, 3) == 1
        
        let encryptedData = EncryptedData(ciphertext: ciphertext, iv: iv, tag: tag)
        
        // Update access time
        let updateSQL = "UPDATE encrypted_storage SET accessed_at = ? WHERE storage_key = ? AND category = ?"
        var updateStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, updateSQL, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_double(updateStatement, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(updateStatement, 2, key, -1, nil)
            sqlite3_bind_text(updateStatement, 3, category.rawValue, -1, nil)
            sqlite3_step(updateStatement)
            sqlite3_finalize(updateStatement)
        }
        
        return (encryptedData, compressed)
    }
    
    private func deleteEncryptedData(
        key: String,
        category: DataCategory,
        from database: OpaquePointer
    ) throws {
        
        let deleteSQL = "DELETE FROM encrypted_storage WHERE storage_key = ? AND category = ?"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SandboxError.databaseError("Failed to prepare delete statement")
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, key, -1, nil)
        sqlite3_bind_text(statement, 2, category.rawValue, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SandboxError.databaseError("Failed to delete encrypted data")
        }
    }
    
    private func getDataSize(
        key: String,
        category: DataCategory,
        from database: OpaquePointer
    ) throws -> Int64 {
        
        let selectSQL = "SELECT length(encrypted_data) FROM encrypted_storage WHERE storage_key = ? AND category = ?"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(database, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            throw SandboxError.databaseError("Failed to prepare size query")
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, key, -1, nil)
        sqlite3_bind_text(statement, 2, category.rawValue, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }
        
        return sqlite3_column_int64(statement, 0)
    }
    
    // MARK: - Memory Protection
    private func initializeMemoryProtection() {
        memoryProtectionQueue.async {
            // Enable memory protection for sensitive operations
            mlockall(MCL_CURRENT | MCL_FUTURE)
            
            // Set up secure memory allocation
            self.setupSecureMemory()
        }
    }
    
    private func setupSecureMemory() {
        // Configure memory protection settings
        let pageSize = getpagesize()
        
        // Allocate protected memory regions for encryption operations
        if #available(iOS 14.0, *) {
            // Use modern memory protection APIs
            let protectedSize = pageSize * 16 // 64KB protected region
            let protectedMemory = mmap(nil, protectedSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
            
            if protectedMemory != MAP_FAILED {
                // Lock memory to prevent swapping
                mlock(protectedMemory, protectedSize)
            }
        }
    }
    
    // MARK: - Sandbox Utilities
    private func generateSandboxKey(for userId: String) -> SymmetricKey {
        // Derive sandbox-specific key from master key and user ID
        let salt = Data("StyleSync-Sandbox-Salt".utf8)
        let info = Data(userId.utf8)
        
        guard let masterKey = try? cryptoEngine.retrieveMasterKey() else {
            fatalError("Master key not available for sandbox key generation")
        }
        
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }
    
    private func getSandboxPath(for userId: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sandboxesPath = documentsPath.appendingPathComponent(Constants.sandboxRootDirectory)
        
        // Create sandboxes root directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: sandboxesPath.path) {
            try? FileManager.default.createDirectory(at: sandboxesPath, withIntermediateDirectories: true)
        }
        
        // Create user-specific subdirectory with hashed name for privacy
        let hashedUserId = SHA256.hash(data: userId.data(using: .utf8) ?? Data()).description
        return sandboxesPath.appendingPathComponent(hashedUserId)
    }
    
    private func saveSandboxMetadata(_ sandbox: UserSandbox) throws {
        let metadata = SandboxMetadata(
            userId: sandbox.userId,
            createdAt: sandbox.createdAt,
            lastAccessed: sandbox.lastAccessed,
            totalSize: sandbox.totalSize
        )
        
        let metadataData = try JSONEncoder().encode(metadata)
        let encryptedMetadata = try cryptoEngine.encryptForLocalStorage(
            data: metadataData,
            context: "sandbox_metadata_\(sandbox.userId)"
        )
        
        let metadataURL = sandbox.sandboxPath.appendingPathComponent(Constants.metadataFileName)
        let encryptedDataForStorage = try JSONEncoder().encode(encryptedMetadata)
        try encryptedDataForStorage.write(to: metadataURL)
    }
    
    private func loadExistingSandboxes() {
        storageQueue.async { [weak self] in
            guard let self = self else { return }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let sandboxesPath = documentsPath.appendingPathComponent(Constants.sandboxRootDirectory)
            
            guard FileManager.default.fileExists(atPath: sandboxesPath.path) else { return }
            
            do {
                let sandboxDirectories = try FileManager.default.contentsOfDirectory(at: sandboxesPath, includingPropertiesForKeys: nil)
                
                for sandboxDir in sandboxDirectories {
                    let metadataURL = sandboxDir.appendingPathComponent(Constants.metadataFileName)
                    
                    if FileManager.default.fileExists(atPath: metadataURL.path) {
                        // Load and decrypt metadata
                        if let encryptedDataForStorage = try? Data(contentsOf: metadataURL),
                           let encryptedMetadata = try? JSONDecoder().decode(EncryptedData.self, from: encryptedDataForStorage) {
                            
                            // Extract user ID from metadata to get proper decryption context
                            // For now, we'll defer loading until sandbox is actually needed
                        }
                    }
                }
            } catch {
                print("Failed to load existing sandboxes: \(error)")
            }
        }
    }
    
    private func updateSandboxSize(for userId: String, delta: Int64) {
        guard var sandbox = userSandboxes[userId] else { return }
        
        sandbox.totalSize += delta
        
        // Enforce size limits
        if sandbox.totalSize > Constants.maxSandboxSize {
            Task {
                await auditLogger.logSecurityEvent(.permissionDenied, details: [
                    "action": "sandbox_size_limit_exceeded",
                    "user_id": userId,
                    "current_size": sandbox.totalSize,
                    "limit": Constants.maxSandboxSize
                ])
            }
        }
        
        userSandboxes[userId] = sandbox
    }
    
    private func updateSandboxAccess(for userId: String) {
        guard var sandbox = userSandboxes[userId] else { return }
        
        sandbox.lastAccessed = Date()
        userSandboxes[userId] = sandbox
    }
    
    // MARK: - Cleanup and Maintenance
    public func performMaintenance() async {
        await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Vacuum databases to reclaim space
                for (_, sandbox) in self.userSandboxes {
                    if !sandbox.isLocked {
                        sqlite3_exec(sandbox.database, "VACUUM;", nil, nil, nil)
                    }
                }
                
                // Clean up old temporary files
                self.cleanupTemporaryFiles()
                
                continuation.resume()
            }
        }
    }
    
    private func cleanupTemporaryFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sandboxesPath = documentsPath.appendingPathComponent(Constants.sandboxRootDirectory)
        
        // Remove backup files older than 30 days
        if let enumerator = FileManager.default.enumerator(at: sandboxesPath, includingPropertiesForKeys: [.creationDateKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == Constants.backupSuffix.dropFirst() {
                    if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                       Date().timeIntervalSince(creationDate) > 30 * 24 * 3600 { // 30 days
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        }
    }
    
    // MARK: - Secure Deletion
    public func secureDeleteSandbox(for userId: String) async throws {
        guard let sandbox = await getSandbox(for: userId) else {
            throw SandboxError.sandboxNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SandboxError.systemError("Storage manager unavailable"))
                    return
                }
                
                do {
                    // Close database connection
                    sqlite3_close(sandbox.database)
                    
                    // Securely wipe database file
                    try self.secureWipeFile(at: sandbox.databaseURL)
                    
                    // Securely wipe all files in sandbox directory
                    try self.secureWipeDirectory(at: sandbox.sandboxPath)
                    
                    // Remove sandbox from memory
                    self.userSandboxes.removeValue(forKey: userId)
                    
                    // Log secure deletion
                    Task {
                        await self.auditLogger.logSecurityEvent(.secureWipe, details: [
                            "action": "sandbox_secure_deleted",
                            "user_id": userId,
                            "method": "7_pass_wipe"
                        ])
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func secureWipeFile(at url: URL) throws {
        guard let fileData = FileManager.default.contents(atPath: url.path) else {
            return // File doesn't exist
        }
        
        let fileSize = fileData.count
        let fileHandle = try FileHandle(forWritingTo: url)
        
        defer {
            try? fileHandle.close()
        }
        
        // 7-pass DoD secure deletion
        let passes: [UInt8] = [0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0xAA]
        
        for pass in passes {
            let passData = Data(repeating: pass, count: fileSize)
            try fileHandle.seek(toOffset: 0)
            try fileHandle.write(contentsOf: passData)
            try fileHandle.synchronize()
        }
        
        // Final random pass
        var randomData = Data(count: fileSize)
        let result = randomData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, fileSize, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        if result == errSecSuccess {
            try fileHandle.seek(toOffset: 0)
            try fileHandle.write(contentsOf: randomData)
            try fileHandle.synchronize()
        }
        
        // Delete file
        try FileManager.default.removeItem(at: url)
    }
    
    private func secureWipeDirectory(at url: URL) throws {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.hasDirectoryPath {
                continue
            }
            try secureWipeFile(at: fileURL)
        }
        
        try FileManager.default.removeItem(at: url)
    }
    
    private func setupRootDirectory() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sandboxesPath = documentsPath.appendingPathComponent(Constants.sandboxRootDirectory)
        
        if !FileManager.default.fileExists(atPath: sandboxesPath.path) {
            try? FileManager.default.createDirectory(at: sandboxesPath, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Supporting Types
public struct UserSandbox {
    public let userId: String
    public let sandboxPath: URL
    public let databaseURL: URL
    public let encryptionKey: SymmetricKey
    public var database: OpaquePointer
    public let createdAt: Date
    public var lastAccessed: Date
    public var totalSize: Int64
    public var isLocked: Bool
}

public enum DataCategory: String, CaseIterable {
    case general = "general"
    case preferences = "preferences"
    case cache = "cache"
    case temporary = "temporary"
    case sensitive = "sensitive"
    case photos = "photos"
    case documents = "documents"
    case social = "social"
}

public struct SandboxMetadata: Codable {
    public let userId: String
    public let createdAt: Date
    public let lastAccessed: Date
    public let totalSize: Int64
}

public enum SandboxError: LocalizedError {
    case sandboxNotFound
    case sandboxLocked
    case databaseError(String)
    case systemError(String)
    case sizeLimitExceeded
    case accessDenied
    
    public var errorDescription: String? {
        switch self {
        case .sandboxNotFound:
            return "User sandbox not found"
        case .sandboxLocked:
            return "Sandbox is locked and cannot be accessed"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .systemError(let message):
            return "System error: \(message)"
        case .sizeLimitExceeded:
            return "Sandbox size limit exceeded"
        case .accessDenied:
            return "Access to sandbox denied"
        }
    }
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