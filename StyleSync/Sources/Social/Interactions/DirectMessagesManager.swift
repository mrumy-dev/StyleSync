import Foundation
import SwiftUI
import Combine

// MARK: - Direct Messages Manager
@MainActor
final class DirectMessagesManager: ObservableObject {
    static let shared = DirectMessagesManager()

    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var currentMessages: [DirectMessage] = []
    @Published var isLoading = false
    @Published var isLoadingMessages = false
    @Published var messagesError: MessagesError?
    @Published var unreadCount: Int = 0

    // MARK: - Private Properties
    private let privacyManager = PrivacyControlsManager.shared
    private let profileManager = ProfileManager.shared
    private let cryptoEngine = CryptoEngine.shared
    private let storageManager = SandboxedStorageManager.shared
    private var currentConversationId: UUID?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants
    private enum Constants {
        static let conversationsCacheKey = "conversations_cache"
        static let messagesCachePrefix = "messages_cache"
        static let maxMessagesPerConversation = 1000
        static let messageRetentionDays = 30
        static let typingIndicatorTimeout: TimeInterval = 3.0
    }

    private init() {
        setupMessagingMonitoring()
        loadCachedConversations()
    }

    // MARK: - Conversation Management
    func loadConversations() {
        guard !isLoading else { return }

        Task {
            await fetchConversations()
        }
    }

    func refreshConversations() async {
        await fetchConversations(refresh: true)
    }

    func createConversation(with participantId: String) async throws -> Conversation {
        // Check if conversation already exists
        if let existingConversation = conversations.first(where: { conv in
            !conv.isGroupChat && conv.participants.contains(participantId)
        }) {
            return existingConversation
        }

        // Create new conversation
        let conversation = Conversation(
            participants: [await getCurrentUserId(), participantId],
            settings: ConversationSettings()
        )

        conversations.insert(conversation, at: 0)
        await saveConversations()

        return conversation
    }

    func createGroupConversation(
        with participantIds: [String],
        groupName: String,
        groupImage: UIImage? = nil
    ) async throws -> Conversation {
        var groupImageData: Data?
        if let groupImage = groupImage {
            groupImageData = groupImage.jpegData(compressionQuality: 0.8)
        }

        let conversation = Conversation(
            participants: [await getCurrentUserId()] + participantIds,
            isGroupChat: true,
            groupName: groupName,
            groupImageData: groupImageData,
            adminIDs: [await getCurrentUserId()],
            settings: ConversationSettings()
        )

        conversations.insert(conversation, at: 0)
        await saveConversations()

        return conversation
    }

    func archiveConversation(_ conversationId: UUID) async {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].isArchived = true
            await saveConversations()
        }
    }

    func deleteConversation(_ conversationId: UUID) async {
        conversations.removeAll { $0.id == conversationId }
        await saveConversations()

        // Also delete cached messages
        try? await storageManager.delete(at: "\(Constants.messagesCachePrefix)_\(conversationId.uuidString)")
    }

    func muteConversation(_ conversationId: UUID, mute: Bool) async {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].isMuted = mute
            await saveConversations()
        }
    }

    // MARK: - Message Management
    func loadMessages(for conversationId: UUID) {
        currentConversationId = conversationId

        Task {
            await fetchMessages(for: conversationId)
        }
    }

    func sendMessage(_ message: DirectMessage) {
        guard let conversationId = currentConversationId else { return }

        // Add message immediately to UI
        currentMessages.append(message)

        // Update conversation's last message and activity
        updateConversationActivity(conversationId, with: message)

        Task {
            await processOutgoingMessage(message)
        }
    }

    func sendTextMessage(to conversationId: UUID, text: String) async throws {
        let message = DirectMessage(
            conversationID: conversationId,
            senderID: await getCurrentUserId(),
            content: .text(text)
        )

        await sendMessageAsync(message)
    }

    func sendImageMessage(
        to conversationId: UUID,
        image: UIImage,
        caption: String? = nil
    ) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw MessagesError.imageSendFailed
        }

        let imageMessage = ImageMessage(
            imageData: imageData,
            caption: caption,
            isOutfit: false,
            analysisResults: nil
        )

        let message = DirectMessage(
            conversationID: conversationId,
            senderID: await getCurrentUserId(),
            content: .image(imageMessage)
        )

        await sendMessageAsync(message)
    }

    func sendOutfitMessage(to conversationId: UUID, outfit: OutfitMessage) async throws {
        let message = DirectMessage(
            conversationID: conversationId,
            senderID: await getCurrentUserId(),
            content: .outfit(outfit)
        )

        await sendMessageAsync(message)
    }

    func sendVoiceMessage(to conversationId: UUID, voiceMessage: VoiceMessage) async throws {
        let message = DirectMessage(
            conversationID: conversationId,
            senderID: await getCurrentUserId(),
            content: .voice(voiceMessage)
        )

        await sendMessageAsync(message)
    }

    private func sendMessageAsync(_ message: DirectMessage) async {
        // Add to current messages if this is the active conversation
        if currentConversationId == message.conversationID {
            currentMessages.append(message)
        }

        updateConversationActivity(message.conversationID, with: message)
        await processOutgoingMessage(message)
    }

    // MARK: - Message Reactions
    func addReaction(to messageId: UUID, emoji: String) async {
        if let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) {
            let reaction = MessageReaction(
                emoji: emoji,
                sender: .user, // Would be proper sender
                timestamp: Date()
            )

            currentMessages[messageIndex].reactions.append(reaction)
            await saveCurrentMessages()
        }
    }

    func removeReaction(from messageId: UUID, emoji: String) async {
        if let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) {
            currentMessages[messageIndex].reactions.removeAll { reaction in
                reaction.emoji == emoji && reaction.sender == .user
            }
            await saveCurrentMessages()
        }
    }

    // MARK: - Message Status Updates
    func markMessageAsRead(_ messageId: UUID) async {
        if let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) {
            currentMessages[messageIndex].status = .read
            await saveCurrentMessages()
        }
    }

    func markConversationAsRead(_ conversationId: UUID) async {
        // Mark all messages in conversation as read
        for index in currentMessages.indices {
            if currentMessages[index].conversationID == conversationId {
                currentMessages[index].status = .read
            }
        }

        await saveCurrentMessages()
        updateUnreadCount()
    }

    // MARK: - Typing Indicators
    func startTyping(in conversationId: UUID) {
        // Send typing indicator to other participants
        print("User started typing in conversation: \(conversationId)")
    }

    func stopTyping(in conversationId: UUID) {
        // Stop typing indicator
        print("User stopped typing in conversation: \(conversationId)")
    }

    // MARK: - Search
    func searchMessages(query: String) async -> [DirectMessage] {
        let allMessages = await getAllMessages()
        return allMessages.filter { message in
            switch message.content {
            case .text(let text):
                return text.localizedCaseInsensitiveContains(query)
            default:
                return false
            }
        }
    }

    func searchConversations(query: String) -> [Conversation] {
        return conversations.filter { conversation in
            if conversation.isGroupChat {
                return conversation.groupName?.localizedCaseInsensitiveContains(query) ?? false
            } else {
                // Would search participant names
                return true
            }
        }
    }

    // MARK: - Message Encryption
    private func encryptMessage(_ message: DirectMessage) async throws -> DirectMessage {
        guard privacyManager.privacySettings.requireEncryptedCommunication else {
            return message
        }

        // Encrypt message content based on type
        var encryptedMessage = message

        switch message.content {
        case .text(let text):
            let encryptedText = try await encryptText(text)
            encryptedMessage.content = .text(encryptedText)

        case .image(var imageMessage):
            imageMessage.imageData = try await encryptData(imageMessage.imageData)
            encryptedMessage.content = .image(imageMessage)

        case .voice(var voiceMessage):
            let encryptedAudioData = try await encryptURL(voiceMessage.audioURL)
            // Would update URL with encrypted version
            encryptedMessage.content = .voice(voiceMessage)

        default:
            break
        }

        return encryptedMessage
    }

    private func decryptMessage(_ message: DirectMessage) async throws -> DirectMessage {
        guard privacyManager.privacySettings.requireEncryptedCommunication else {
            return message
        }

        // Decrypt message content
        var decryptedMessage = message

        switch message.content {
        case .text(let encryptedText):
            let decryptedText = try await decryptText(encryptedText)
            decryptedMessage.content = .text(decryptedText)

        case .image(var imageMessage):
            imageMessage.imageData = try await decryptData(imageMessage.imageData)
            decryptedMessage.content = .image(imageMessage)

        default:
            break
        }

        return decryptedMessage
    }

    // MARK: - Data Fetching
    private func fetchConversations(refresh: Bool = false) async {
        isLoading = true
        messagesError = nil

        do {
            // Check privacy permissions
            guard await privacyManager.permissionsGranted.contains(.socialFeatures) else {
                throw MessagesError.permissionDenied
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let fetchedConversations = generateMockConversations()
            conversations = fetchedConversations

            await saveConversations()
            updateUnreadCount()

            isLoading = false

        } catch {
            messagesError = MessagesError.loadingFailed(error)
            isLoading = false

            // Try to load cached data if network fails
            if !refresh {
                await loadCachedConversations()
            }
        }
    }

    private func fetchMessages(for conversationId: UUID) async {
        isLoadingMessages = true

        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000)

            let fetchedMessages = generateMockMessages(for: conversationId)
            currentMessages = fetchedMessages

            await saveMessages(fetchedMessages, for: conversationId)

            isLoadingMessages = false

        } catch {
            messagesError = MessagesError.loadingFailed(error)
            isLoadingMessages = false

            // Try to load cached messages
            await loadCachedMessages(for: conversationId)
        }
    }

    private func processOutgoingMessage(_ message: DirectMessage) async {
        do {
            // Encrypt message if required
            let processedMessage = try await encryptMessage(message)

            // Update message status
            if let messageIndex = currentMessages.firstIndex(where: { $0.id == message.id }) {
                currentMessages[messageIndex].status = .sent

                // Simulate delivery confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    Task {
                        await self.updateMessageStatus(message.id, to: .delivered)
                    }
                }
            }

            await saveCurrentMessages()

        } catch {
            // Mark message as failed
            if let messageIndex = currentMessages.firstIndex(where: { $0.id == message.id }) {
                currentMessages[messageIndex].status = .failed
            }

            messagesError = MessagesError.sendingFailed(error)
        }
    }

    private func updateMessageStatus(_ messageId: UUID, to status: MessageStatus) async {
        if let messageIndex = currentMessages.firstIndex(where: { $0.id == messageId }) {
            currentMessages[messageIndex].status = status
            await saveCurrentMessages()
        }
    }

    // MARK: - Mock Data Generation
    private func generateMockConversations() -> [Conversation] {
        var mockConversations: [Conversation] = []

        for i in 0..<8 {
            let isGroup = i % 4 == 0

            let conversation = Conversation(
                participants: isGroup ? ["user_\(i)", "user_\(i+1)", "user_\(i+2)"] : ["user_\(i)"],
                isGroupChat: isGroup,
                groupName: isGroup ? "Style Group \(i/4 + 1)" : nil,
                groupImageData: nil,
                adminIDs: isGroup ? ["user_\(i)"] : [],
                settings: ConversationSettings()
            )

            // Add a mock last message
            let lastMessage = DirectMessage(
                conversationID: conversation.id,
                senderID: conversation.participants.randomElement() ?? "user_\(i)",
                content: .text(generateMockMessageText(index: i)),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )

            var updatedConversation = conversation
            updatedConversation.lastMessage = lastMessage
            updatedConversation.lastActivity = lastMessage.timestamp

            mockConversations.append(updatedConversation)
        }

        return mockConversations.sorted { $0.lastActivity > $1.lastActivity }
    }

    private func generateMockMessages(for conversationId: UUID) -> [DirectMessage] {
        var mockMessages: [DirectMessage] = []

        for i in 0..<20 {
            let messageType = i % 4
            let senderId = i % 2 == 0 ? "current_user" : "other_user"

            let content: MessageContent
            switch messageType {
            case 0:
                content = .text(generateMockMessageText(index: i))
            case 1:
                content = .image(ImageMessage(
                    imageData: generateMockImageData(),
                    caption: i % 6 == 0 ? "Check out this outfit!" : nil,
                    isOutfit: i % 6 == 0,
                    analysisResults: nil
                ))
            case 2:
                content = .voice(VoiceMessage(
                    audioURL: URL(string: "https://example.com/voice.m4a")!,
                    duration: Double.random(in: 5...30),
                    waveform: generateMockWaveform(),
                    transcription: i % 8 == 0 ? generateMockMessageText(index: i) : nil,
                    isTranscribing: false
                ))
            default:
                content = .text(generateMockMessageText(index: i))
            }

            let message = DirectMessage(
                conversationID: conversationId,
                senderID: senderId,
                content: content,
                timestamp: Date().addingTimeInterval(-Double(19 - i) * 3600),
                status: senderId == "current_user" ? .delivered : .read
            )

            mockMessages.append(message)
        }

        return mockMessages
    }

    private func generateMockMessageText(index: Int) -> String {
        let messages = [
            "Hey! How are you doing?",
            "Love that outfit you posted! 😍",
            "Where did you get that jacket?",
            "Thanks for the style tips!",
            "Looking forward to our shopping trip",
            "That color looks amazing on you",
            "Can you help me pick an outfit?",
            "Just bought those shoes you recommended",
            "Your style inspiration is on point! ✨",
            "Ready for the fashion show tonight?"
        ]

        return messages[index % messages.count]
    }

    private func generateMockImageData() -> Data {
        let image = UIImage(systemName: "photo") ?? UIImage()
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    private func generateMockWaveform() -> [Float] {
        return (0..<20).map { _ in Float.random(in: 0.1...1.0) }
    }

    // MARK: - Helper Methods
    private func updateConversationActivity(_ conversationId: UUID, with message: DirectMessage) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].lastMessage = message
            conversations[index].lastActivity = message.timestamp

            // Move conversation to top
            let conversation = conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
        }
    }

    private func updateUnreadCount() {
        // Calculate unread messages count
        unreadCount = conversations.reduce(0) { count, conversation in
            // Would count actual unread messages
            return count + (conversation.isMuted ? 0 : Int.random(in: 0...5))
        }
    }

    // MARK: - Encryption Helpers
    private func encryptText(_ text: String) async throws -> String {
        let data = text.data(using: .utf8) ?? Data()
        let encryptedData = try cryptoEngine.encrypt(data: data)
        return try JSONEncoder().encode(encryptedData).base64EncodedString()
    }

    private func decryptText(_ encryptedText: String) async throws -> String {
        guard let data = Data(base64Encoded: encryptedText) else {
            throw MessagesError.decryptionFailed
        }
        let encryptedData = try JSONDecoder().decode(EncryptedData.self, from: data)
        let decryptedData = try cryptoEngine.decrypt(encryptedData: encryptedData)
        return String(data: decryptedData, encoding: .utf8) ?? ""
    }

    private func encryptData(_ data: Data) async throws -> Data {
        let encryptedData = try cryptoEngine.encrypt(data: data)
        return try JSONEncoder().encode(encryptedData)
    }

    private func decryptData(_ encryptedData: Data) async throws -> Data {
        let encryptedObject = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
        return try cryptoEngine.decrypt(encryptedData: encryptedObject)
    }

    private func encryptURL(_ url: URL) async throws -> URL {
        // Would encrypt audio file and return new URL
        return url
    }

    // MARK: - Storage Operations
    private func saveConversations() async {
        do {
            let conversationsData = ConversationsCacheData(
                conversations: conversations,
                timestamp: Date()
            )

            let encodedData = try JSONEncoder().encode(conversationsData)
            let encryptedData = try cryptoEngine.encrypt(data: encodedData)

            try await storageManager.storeSecurely(
                data: try JSONEncoder().encode(encryptedData),
                at: Constants.conversationsCacheKey
            )
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }

    private func loadCachedConversations() async {
        do {
            let encryptedData = try await storageManager.loadSecurely(from: Constants.conversationsCacheKey)
            let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
            let conversationsData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
            let cacheData = try JSONDecoder().decode(ConversationsCacheData.self, from: conversationsData)

            conversations = cacheData.conversations
            updateUnreadCount()

        } catch {
            print("Failed to load cached conversations: \(error)")
        }
    }

    private func loadCachedConversations() {
        Task {
            await loadCachedConversations()
        }
    }

    private func saveMessages(_ messages: [DirectMessage], for conversationId: UUID) async {
        do {
            let messagesData = MessagesCacheData(
                messages: messages,
                conversationId: conversationId,
                timestamp: Date()
            )

            let encodedData = try JSONEncoder().encode(messagesData)
            let encryptedData = try cryptoEngine.encrypt(data: encodedData)

            try await storageManager.storeSecurely(
                data: try JSONEncoder().encode(encryptedData),
                at: "\(Constants.messagesCachePrefix)_\(conversationId.uuidString)"
            )
        } catch {
            print("Failed to save messages: \(error)")
        }
    }

    private func saveCurrentMessages() async {
        guard let conversationId = currentConversationId else { return }
        await saveMessages(currentMessages, for: conversationId)
    }

    private func loadCachedMessages(for conversationId: UUID) async {
        do {
            let encryptedData = try await storageManager.loadSecurely(
                from: "\(Constants.messagesCachePrefix)_\(conversationId.uuidString)"
            )
            let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
            let messagesData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
            let cacheData = try JSONDecoder().decode(MessagesCacheData.self, from: messagesData)

            currentMessages = cacheData.messages

        } catch {
            print("Failed to load cached messages: \(error)")
        }
    }

    private func getAllMessages() async -> [DirectMessage] {
        var allMessages: [DirectMessage] = []

        for conversation in conversations {
            do {
                let encryptedData = try await storageManager.loadSecurely(
                    from: "\(Constants.messagesCachePrefix)_\(conversation.id.uuidString)"
                )
                let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
                let messagesData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
                let cacheData = try JSONDecoder().decode(MessagesCacheData.self, from: messagesData)

                allMessages.append(contentsOf: cacheData.messages)
            } catch {
                // Conversation messages not cached yet
            }
        }

        return allMessages
    }

    // MARK: - Monitoring
    private func setupMessagingMonitoring() {
        // Monitor privacy changes
        privacyManager.$privacyLevel
            .sink { [weak self] newLevel in
                Task {
                    await self?.handlePrivacyLevelChange(newLevel)
                }
            }
            .store(in: &cancellables)

        // Auto-cleanup old messages
        Timer.publish(every: 86400, on: .main, in: .common) // Daily
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.cleanupOldMessages()
                }
            }
            .store(in: &cancellables)
    }

    private func handlePrivacyLevelChange(_ newLevel: PrivacyLevel) async {
        switch newLevel {
        case .maximum:
            // Enable disappearing messages by default
            for index in conversations.indices {
                conversations[index].settings.autoDeleteMessages = true
                conversations[index].settings.deleteAfterDays = 1
            }

        case .high:
            // Shorter message retention
            for index in conversations.indices {
                conversations[index].settings.deleteAfterDays = 7
            }

        default:
            break
        }

        await saveConversations()
    }

    private func cleanupOldMessages() async {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(Constants.messageRetentionDays * 24 * 3600))

        for conversation in conversations {
            if conversation.settings.autoDeleteMessages {
                let conversationCutoffDate = Date().addingTimeInterval(
                    -TimeInterval(conversation.settings.deleteAfterDays * 24 * 3600)
                )

                // Would clean up messages older than cutoff date
                print("Cleaning up old messages for conversation: \(conversation.id)")
            }
        }
    }

    private func getCurrentUserId() async -> String {
        return await profileManager.currentProfile?.anonymousID ?? "anonymous"
    }
}

// MARK: - Supporting Types
struct ConversationsCacheData: Codable {
    let conversations: [Conversation]
    let timestamp: Date
}

struct MessagesCacheData: Codable {
    let messages: [DirectMessage]
    let conversationId: UUID
    let timestamp: Date
}

// MARK: - Messages Errors
enum MessagesError: LocalizedError {
    case loadingFailed(Error)
    case sendingFailed(Error)
    case permissionDenied
    case conversationNotFound
    case imageSendFailed
    case voiceSendFailed
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .loadingFailed(let error):
            return "Failed to load messages: \(error.localizedDescription)"
        case .sendingFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied for messaging"
        case .conversationNotFound:
            return "Conversation not found"
        case .imageSendFailed:
            return "Failed to send image"
        case .voiceSendFailed:
            return "Failed to send voice message"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        }
    }
}