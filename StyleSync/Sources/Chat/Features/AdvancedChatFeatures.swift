import Foundation
import SwiftUI
import UserNotifications

@MainActor
class AdvancedChatFeaturesManager: ObservableObject {
    @Published var savedConversations: [SavedConversation] = []
    @Published var scheduledReminders: [OutfitReminder] = []
    @Published var favoriteAdvice: [FavoriteAdvice] = []
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    
    private let persistenceManager = ChatPersistenceManager()
    private let reminderManager = ReminderManager()
    private let exportManager = ChatExportManager()
    private let searchEngine = ChatSearchEngine()
    
    // MARK: - Save Conversations
    
    func saveConversation(_ session: ChatSession, title: String? = nil) async {
        let savedConversation = SavedConversation(
            id: UUID(),
            originalSessionId: session.id,
            title: title ?? generateConversationTitle(from: session),
            summary: generateConversationSummary(from: session),
            messageCount: session.messages.count,
            savedDate: Date(),
            tags: extractTags(from: session),
            thumbnail: await generateConversationThumbnail(from: session),
            isStarred: false,
            messages: session.messages
        )
        
        savedConversations.append(savedConversation)
        await persistenceManager.saveChatConversation(savedConversation)
    }
    
    func starConversation(_ conversationId: UUID) {
        if let index = savedConversations.firstIndex(where: { $0.id == conversationId }) {
            savedConversations[index].isStarred.toggle()
            Task {
                await persistenceManager.updateConversation(savedConversations[index])
            }
        }
    }
    
    func deleteConversation(_ conversationId: UUID) async {
        savedConversations.removeAll { $0.id == conversationId }
        await persistenceManager.deleteConversation(conversationId)
    }
    
    // MARK: - Export Functionality
    
    func exportConversation(_ conversationId: UUID, format: ExportFormat) async -> URL? {
        guard let conversation = savedConversations.first(where: { $0.id == conversationId }) else {
            return nil
        }
        
        return await exportManager.exportConversation(conversation, format: format)
    }
    
    func exportAllConversations(format: ExportFormat) async -> URL? {
        let exportData = ChatExportData(
            exportDate: Date(),
            conversationsCount: savedConversations.count,
            totalMessages: savedConversations.reduce(0) { $0 + $1.messageCount },
            conversations: savedConversations
        )
        
        return await exportManager.exportAllConversations(exportData, format: format)
    }
    
    // MARK: - Outfit Reminders
    
    func scheduleOutfitReminder(
        title: String,
        message: String,
        date: Date,
        outfitId: UUID? = nil,
        repeating: ReminderRepeatOption = .none
    ) async -> Bool {
        let reminder = OutfitReminder(
            id: UUID(),
            title: title,
            message: message,
            scheduledDate: date,
            outfitId: outfitId,
            repeatOption: repeating,
            isActive: true,
            createdDate: Date()
        )
        
        let success = await reminderManager.scheduleReminder(reminder)
        if success {
            scheduledReminders.append(reminder)
            await persistenceManager.saveReminder(reminder)
        }
        
        return success
    }
    
    func cancelReminder(_ reminderId: UUID) async {
        await reminderManager.cancelReminder(reminderId)
        scheduledReminders.removeAll { $0.id == reminderId }
        await persistenceManager.deleteReminder(reminderId)
    }
    
    func updateReminder(_ reminder: OutfitReminder) async {
        if let index = scheduledReminders.firstIndex(where: { $0.id == reminder.id }) {
            scheduledReminders[index] = reminder
            await reminderManager.updateReminder(reminder)
            await persistenceManager.updateReminder(reminder)
        }
    }
    
    // MARK: - Favorite Advice
    
    func saveFavoriteAdvice(_ message: ChatMessage, category: String? = nil) {
        guard case .text(let adviceText) = message.content else { return }
        
        let favoriteAdvice = FavoriteAdvice(
            id: UUID(),
            originalMessageId: message.id,
            advice: adviceText,
            category: category ?? "General",
            savedDate: Date(),
            tags: extractAdviceTags(from: adviceText),
            aiPersona: extractPersonaFromMessage(message),
            isArchived: false
        )
        
        favoriteAdvice.append(favoriteAdvice)
        Task {
            await persistenceManager.saveFavoriteAdvice(favoriteAdvice)
        }
    }
    
    func organizeFavoriteAdviceByCategory() -> [String: [FavoriteAdvice]] {
        Dictionary(grouping: favoriteAdvice, by: \.category)
    }
    
    func searchFavoriteAdvice(_ query: String) -> [FavoriteAdvice] {
        return favoriteAdvice.filter { advice in
            advice.advice.localizedCaseInsensitiveContains(query) ||
            advice.category.localizedCaseInsensitiveContains(query) ||
            advice.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    // MARK: - Chat Search
    
    func searchInConversation(_ session: ChatSession, query: String) async {
        isSearching = true
        searchResults = await searchEngine.searchInConversation(session, query: query)
        isSearching = false
    }
    
    func searchAllConversations(_ query: String) async {
        isSearching = true
        searchResults = await searchEngine.searchAllConversations(savedConversations, query: query)
        isSearching = false
    }
    
    func searchByCategory(_ category: MessageCategory) async {
        isSearching = true
        searchResults = await searchEngine.searchByCategory(savedConversations, category: category)
        isSearching = false
    }
    
    func advancedSearch(_ criteria: AdvancedSearchCriteria) async {
        isSearching = true
        searchResults = await searchEngine.advancedSearch(savedConversations, criteria: criteria)
        isSearching = false
    }
    
    // MARK: - Thread Organization
    
    func createThreadFromMessage(_ messageId: UUID, in session: ChatSession) -> UUID {
        let threadId = UUID()
        
        // Update message with thread ID
        if let index = session.messages.firstIndex(where: { $0.id == messageId }) {
            session.messages[index].threadId = threadId
        }
        
        return threadId
    }
    
    func getThreadMessages(_ threadId: UUID, from session: ChatSession) -> [ChatMessage] {
        return session.messages.filter { $0.threadId == threadId }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    func getThreadSummary(_ threadId: UUID, from session: ChatSession) -> ThreadSummary {
        let messages = getThreadMessages(threadId, from: session)
        
        return ThreadSummary(
            threadId: threadId,
            messageCount: messages.count,
            participants: Array(Set(messages.map(\.sender))),
            startDate: messages.first?.timestamp ?? Date(),
            lastActivity: messages.last?.timestamp ?? Date(),
            topic: extractThreadTopic(from: messages)
        )
    }
    
    // MARK: - Shopping Integration
    
    func createShoppingListFromConversation(_ session: ChatSession) -> ShoppingList {
        let recommendations = extractShoppingRecommendations(from: session)
        
        return ShoppingList(
            id: UUID(),
            title: "Style Recommendations",
            items: recommendations,
            createdDate: Date(),
            totalEstimatedPrice: recommendations.reduce(0) { $0 + ($1.estimatedPrice ?? 0) },
            priority: .medium
        )
    }
    
    func findShoppingLinksInMessage(_ message: ChatMessage) -> [ShoppingLink] {
        // Extract shopping recommendations and find purchase links
        var links: [ShoppingLink] = []
        
        switch message.content {
        case .suggestion(let suggestion):
            if suggestion.actionType == .shopItem {
                links = findShoppingLinksForSuggestion(suggestion)
            }
        case .text(let text):
            links = extractShoppingLinksFromText(text)
        default:
            break
        }
        
        return links
    }
    
    // MARK: - Mood Board Creation
    
    func createMoodBoardFromConversation(_ session: ChatSession) async -> MoodBoard {
        let images = extractImagesFromConversation(session)
        let colors = await extractDominantColorsFromConversation(session)
        let styleKeywords = extractStyleKeywords(from: session)
        
        return MoodBoard(
            id: UUID(),
            title: "Conversation Mood Board",
            images: images,
            colors: colors,
            styleKeywords: styleKeywords,
            createdDate: Date(),
            inspiration: generateInspirationText(from: session)
        )
    }
    
    // MARK: - Analytics and Insights
    
    func generateConversationInsights(_ session: ChatSession) -> ConversationInsights {
        let messageCount = session.messages.count
        let userMessages = session.messages.filter { !$0.sender.isAI }
        let aiMessages = session.messages.filter { $0.sender.isAI }
        
        let dominantTopics = extractDominantTopics(from: session)
        let styleEvolution = trackStyleEvolution(from: session)
        let engagementScore = calculateEngagementScore(session)
        
        return ConversationInsights(
            totalMessages: messageCount,
            userMessages: userMessages.count,
            aiMessages: aiMessages.count,
            conversationDuration: session.lastActivity.timeIntervalSince(session.createdAt),
            dominantTopics: dominantTopics,
            styleEvolution: styleEvolution,
            engagementScore: engagementScore,
            recommendationsGiven: countRecommendations(in: session),
            outfitsDiscussed: countOutfits(in: session)
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateConversationTitle(from session: ChatSession) -> String {
        // Extract key topics and create a meaningful title
        let messages = Array(session.messages.prefix(5))
        let keywords = messages.compactMap { message -> [String]? in
            if case .text(let text) = message.content {
                return extractKeywords(from: text)
            }
            return nil
        }.flatMap { $0 }
        
        let dominantKeywords = Array(Set(keywords)).prefix(3)
        
        if dominantKeywords.isEmpty {
            return "Style Chat - \(DateFormatter.shortDate.string(from: session.createdAt))"
        } else {
            return dominantKeywords.joined(separator: ", ") + " Discussion"
        }
    }
    
    private func generateConversationSummary(from session: ChatSession) -> String {
        let messageCount = session.messages.count
        let topics = extractTags(from: session)
        
        if topics.isEmpty {
            return "A style conversation with \(messageCount) messages"
        } else {
            return "Discussed \(topics.joined(separator: ", ")) in \(messageCount) messages"
        }
    }
    
    private func extractTags(from session: ChatSession) -> [String] {
        let allText = session.messages.compactMap { message -> String? in
            if case .text(let text) = message.content {
                return text
            }
            return nil
        }.joined(separator: " ")
        
        return extractStyleTags(from: allText)
    }
    
    private func generateConversationThumbnail(from session: ChatSession) async -> Data? {
        // Find the first image in the conversation or generate a color-based thumbnail
        for message in session.messages {
            if case .image(let imageMessage) = message.content {
                return imageMessage.imageData
            }
        }
        
        // Generate color-based thumbnail from dominant colors
        let colors = extractColorsFromSession(session)
        return await generateColorThumbnail(colors: colors)
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndPunctuation)
            .filter { $0.count > 3 }
        
        let styleKeywords = [
            "outfit", "dress", "shirt", "pants", "skirt", "jacket", "blazer",
            "color", "style", "fashion", "trend", "vintage", "modern", "casual",
            "formal", "elegant", "chic", "boho", "minimalist", "edgy"
        ]
        
        return words.filter { styleKeywords.contains($0) }
    }
    
    private func extractStyleTags(from text: String) -> [String] {
        let keywords = extractKeywords(from: text)
        return Array(Set(keywords)).sorted()
    }
    
    private func extractAdviceTags(from advice: String) -> [String] {
        return extractStyleTags(from: advice)
    }
    
    private func extractPersonaFromMessage(_ message: ChatMessage) -> String {
        if case .ai(let persona) = message.sender {
            return persona.name
        }
        return "Unknown"
    }
    
    private func extractShoppingRecommendations(from session: ChatSession) -> [ShoppingItem] {
        var items: [ShoppingItem] = []
        
        for message in session.messages {
            switch message.content {
            case .suggestion(let suggestion):
                if suggestion.actionType == .shopItem {
                    let item = ShoppingItem(
                        id: UUID(),
                        name: suggestion.title,
                        description: suggestion.description,
                        category: determineItemCategory(suggestion.title),
                        estimatedPrice: estimatePrice(for: suggestion.title),
                        priority: determinePriority(from: suggestion.confidence),
                        url: nil,
                        addedDate: message.timestamp
                    )
                    items.append(item)
                }
            case .text(let text):
                let recommendations = extractShoppingItemsFromText(text)
                items.append(contentsOf: recommendations)
            default:
                break
            }
        }
        
        return items
    }
    
    private func findShoppingLinksForSuggestion(_ suggestion: SuggestionMessage) -> [ShoppingLink] {
        // In a real implementation, this would search shopping APIs
        return [
            ShoppingLink(
                title: suggestion.title,
                url: URL(string: "https://example.com/shop")!,
                price: estimatePrice(for: suggestion.title),
                store: "Fashion Store",
                imageURL: nil
            )
        ]
    }
    
    private func extractShoppingLinksFromText(_ text: String) -> [ShoppingLink] {
        // Extract potential shopping items from text
        let items = extractPotentialShoppingItems(from: text)
        return items.map { item in
            ShoppingLink(
                title: item,
                url: URL(string: "https://example.com/search?q=\(item.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!,
                price: estimatePrice(for: item),
                store: "Online Store",
                imageURL: nil
            )
        }
    }
    
    private func extractImagesFromConversation(_ session: ChatSession) -> [Data] {
        return session.messages.compactMap { message in
            if case .image(let imageMessage) = message.content {
                return imageMessage.imageData
            }
            return nil
        }
    }
    
    private func extractDominantColorsFromConversation(_ session: ChatSession) async -> [Color] {
        var colors: [Color] = []
        
        for message in session.messages {
            switch message.content {
            case .color(let colorMessage):
                colors.append(colorMessage.color.color)
            case .image(let imageMessage):
                // Extract colors from image (simplified)
                colors.append(.blue) // Placeholder
            default:
                break
            }
        }
        
        return Array(Set(colors).prefix(5))
    }
    
    private func extractStyleKeywords(from session: ChatSession) -> [String] {
        let allText = session.messages.compactMap { message -> String? in
            if case .text(let text) = message.content {
                return text
            }
            return nil
        }.joined(separator: " ")
        
        return extractStyleTags(from: allText)
    }
    
    private func generateInspirationText(from session: ChatSession) -> String {
        let topics = extractTags(from: session)
        let styles = topics.filter { ["casual", "formal", "elegant", "boho", "minimalist"].contains($0) }
        
        if styles.isEmpty {
            return "A collection of style inspirations from your conversations"
        } else {
            return "Inspired by \(styles.joined(separator: ", ")) styles"
        }
    }
    
    private func extractDominantTopics(from session: ChatSession) -> [String] {
        return Array(extractTags(from: session).prefix(5))
    }
    
    private func trackStyleEvolution(from session: ChatSession) -> StyleEvolution {
        // Track how style preferences changed over time
        let chronologicalMessages = session.messages.sorted { $0.timestamp < $1.timestamp }
        let styles = extractStyleEvolutionPoints(from: chronologicalMessages)
        
        return StyleEvolution(
            timeline: styles,
            overallTrend: determineOverallTrend(styles),
            consistencyScore: calculateStyleConsistency(styles)
        )
    }
    
    private func calculateEngagementScore(_ session: ChatSession) -> Float {
        let messageCount = session.messages.count
        let conversationDuration = session.lastActivity.timeIntervalSince(session.createdAt)
        let avgTimeBetweenMessages = conversationDuration / Double(max(messageCount - 1, 1))
        
        // Lower time between messages = higher engagement
        let engagementScore = min(1.0, 60.0 / avgTimeBetweenMessages) // Normalize to 0-1
        
        return Float(max(0.1, engagementScore))
    }
    
    private func countRecommendations(in session: ChatSession) -> Int {
        return session.messages.count { message in
            switch message.content {
            case .suggestion, .analysis:
                return true
            default:
                return false
            }
        }
    }
    
    private func countOutfits(in session: ChatSession) -> Int {
        return session.messages.count { message in
            switch message.content {
            case .outfit, .image(let imageMessage):
                return imageMessage.isOutfit
            default:
                return false
            }
        }
    }
    
    // MARK: - Placeholder Helper Methods
    
    private func generateColorThumbnail(colors: [Color]) async -> Data? {
        // Generate a simple color grid thumbnail
        return nil // Placeholder
    }
    
    private func extractColorsFromSession(_ session: ChatSession) -> [Color] {
        return [.blue, .white, .black] // Placeholder
    }
    
    private func extractThreadTopic(from messages: [ChatMessage]) -> String {
        return "General Discussion" // Placeholder
    }
    
    private func determineItemCategory(_ itemName: String) -> String {
        let name = itemName.lowercased()
        if name.contains("dress") || name.contains("skirt") {
            return "Dresses & Skirts"
        } else if name.contains("top") || name.contains("shirt") || name.contains("blouse") {
            return "Tops"
        } else if name.contains("pants") || name.contains("jeans") {
            return "Bottoms"
        } else if name.contains("shoe") || name.contains("boot") {
            return "Shoes"
        } else {
            return "Accessories"
        }
    }
    
    private func estimatePrice(for item: String) -> Double? {
        // Simplified price estimation
        let name = item.lowercased()
        if name.contains("dress") {
            return 80.0
        } else if name.contains("shirt") {
            return 45.0
        } else if name.contains("pants") {
            return 60.0
        } else {
            return 50.0
        }
    }
    
    private func determinePriority(from confidence: Float) -> ShoppingPriority {
        if confidence > 0.8 {
            return .high
        } else if confidence > 0.6 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func extractShoppingItemsFromText(_ text: String) -> [ShoppingItem] {
        // Extract potential shopping items from text
        return [] // Placeholder
    }
    
    private func extractPotentialShoppingItems(from text: String) -> [String] {
        // Extract potential shopping items
        return [] // Placeholder
    }
    
    private func extractStyleEvolutionPoints(from messages: [ChatMessage]) -> [StylePoint] {
        return [] // Placeholder
    }
    
    private func determineOverallTrend(_ styles: [StylePoint]) -> String {
        return "Evolving" // Placeholder
    }
    
    private func calculateStyleConsistency(_ styles: [StylePoint]) -> Float {
        return 0.8 // Placeholder
    }
}

// MARK: - Data Models

struct SavedConversation: Identifiable, Codable {
    let id: UUID
    let originalSessionId: UUID
    let title: String
    let summary: String
    let messageCount: Int
    let savedDate: Date
    let tags: [String]
    let thumbnail: Data?
    var isStarred: Bool
    let messages: [ChatMessage]
}

struct OutfitReminder: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let scheduledDate: Date
    let outfitId: UUID?
    let repeatOption: ReminderRepeatOption
    var isActive: Bool
    let createdDate: Date
}

enum ReminderRepeatOption: String, Codable, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct FavoriteAdvice: Identifiable, Codable {
    let id: UUID
    let originalMessageId: UUID
    let advice: String
    let category: String
    let savedDate: Date
    let tags: [String]
    let aiPersona: String
    var isArchived: Bool
}

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case pdf = "PDF"
    case html = "HTML"
    case markdown = "Markdown"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .pdf: return "pdf"
        case .html: return "html"
        case .markdown: return "md"
        }
    }
}

struct ChatExportData: Codable {
    let exportDate: Date
    let conversationsCount: Int
    let totalMessages: Int
    let conversations: [SavedConversation]
}

struct SearchResult: Identifiable {
    let id = UUID()
    let messageId: UUID
    let conversationId: UUID
    let conversationTitle: String
    let messageContent: String
    let messageDate: Date
    let matchType: SearchMatchType
    let context: String
}

enum SearchMatchType {
    case exact, partial, semantic, category
}

enum MessageCategory: String, CaseIterable {
    case outfit = "Outfit"
    case color = "Color"
    case advice = "Advice"
    case question = "Question"
    case compliment = "Compliment"
    case suggestion = "Suggestion"
}

struct AdvancedSearchCriteria {
    let query: String?
    let dateRange: DateInterval?
    let messageTypes: [MessageCategory]
    let senders: [MessageSender]
    let tags: [String]
}

struct ThreadSummary {
    let threadId: UUID
    let messageCount: Int
    let participants: [MessageSender]
    let startDate: Date
    let lastActivity: Date
    let topic: String
}

struct ShoppingList: Identifiable, Codable {
    let id: UUID
    let title: String
    let items: [ShoppingItem]
    let createdDate: Date
    let totalEstimatedPrice: Double
    let priority: ShoppingPriority
}

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let estimatedPrice: Double?
    let priority: ShoppingPriority
    let url: URL?
    let addedDate: Date
}

enum ShoppingPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct ShoppingLink {
    let title: String
    let url: URL
    let price: Double?
    let store: String
    let imageURL: URL?
}

struct MoodBoard: Identifiable, Codable {
    let id: UUID
    let title: String
    let images: [Data]
    let colors: [CodableColor]
    let styleKeywords: [String]
    let createdDate: Date
    let inspiration: String
}

struct ConversationInsights {
    let totalMessages: Int
    let userMessages: Int
    let aiMessages: Int
    let conversationDuration: TimeInterval
    let dominantTopics: [String]
    let styleEvolution: StyleEvolution
    let engagementScore: Float
    let recommendationsGiven: Int
    let outfitsDiscussed: Int
}

struct StyleEvolution {
    let timeline: [StylePoint]
    let overallTrend: String
    let consistencyScore: Float
}

struct StylePoint {
    let date: Date
    let style: String
    let confidence: Float
}

// MARK: - Manager Classes

class ChatPersistenceManager {
    func saveChatConversation(_ conversation: SavedConversation) async {
        // Save to Core Data or other persistence layer
    }
    
    func updateConversation(_ conversation: SavedConversation) async {
        // Update in persistence layer
    }
    
    func deleteConversation(_ conversationId: UUID) async {
        // Delete from persistence layer
    }
    
    func saveReminder(_ reminder: OutfitReminder) async {
        // Save reminder to persistence
    }
    
    func updateReminder(_ reminder: OutfitReminder) async {
        // Update reminder in persistence
    }
    
    func deleteReminder(_ reminderId: UUID) async {
        // Delete reminder from persistence
    }
    
    func saveFavoriteAdvice(_ advice: FavoriteAdvice) async {
        // Save favorite advice to persistence
    }
}

class ReminderManager {
    func scheduleReminder(_ reminder: OutfitReminder) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminder.scheduledDate.timeIntervalSinceNow,
            repeats: reminder.repeatOption != .none
        )
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("Failed to schedule reminder: \(error)")
            return false
        }
    }
    
    func cancelReminder(_ reminderId: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminderId.uuidString]
        )
    }
    
    func updateReminder(_ reminder: OutfitReminder) async {
        await cancelReminder(reminder.id)
        _ = await scheduleReminder(reminder)
    }
}

class ChatExportManager {
    func exportConversation(_ conversation: SavedConversation, format: ExportFormat) async -> URL? {
        switch format {
        case .json:
            return await exportAsJSON(conversation)
        case .pdf:
            return await exportAsPDF(conversation)
        case .html:
            return await exportAsHTML(conversation)
        case .markdown:
            return await exportAsMarkdown(conversation)
        }
    }
    
    func exportAllConversations(_ exportData: ChatExportData, format: ExportFormat) async -> URL? {
        // Export all conversations in the specified format
        return await exportConversation(exportData.conversations.first!, format: format) // Placeholder
    }
    
    private func exportAsJSON(_ conversation: SavedConversation) async -> URL? {
        do {
            let data = try JSONEncoder().encode(conversation)
            return try saveToDocuments(data, filename: "\(conversation.title).json")
        } catch {
            print("JSON export failed: \(error)")
            return nil
        }
    }
    
    private func exportAsPDF(_ conversation: SavedConversation) async -> URL? {
        // Generate PDF from conversation
        return nil // Placeholder
    }
    
    private func exportAsHTML(_ conversation: SavedConversation) async -> URL? {
        // Generate HTML from conversation
        return nil // Placeholder
    }
    
    private func exportAsMarkdown(_ conversation: SavedConversation) async -> URL? {
        // Generate Markdown from conversation
        return nil // Placeholder
    }
    
    private func saveToDocuments(_ data: Data, filename: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
}

class ChatSearchEngine {
    func searchInConversation(_ session: ChatSession, query: String) async -> [SearchResult] {
        return session.messages.compactMap { message in
            if messageMatches(message, query: query) {
                return SearchResult(
                    messageId: message.id,
                    conversationId: session.id,
                    conversationTitle: "Current Chat",
                    messageContent: message.content.displayText,
                    messageDate: message.timestamp,
                    matchType: .partial,
                    context: generateContext(for: message, in: session)
                )
            }
            return nil
        }
    }
    
    func searchAllConversations(_ conversations: [SavedConversation], query: String) async -> [SearchResult] {
        var results: [SearchResult] = []
        
        for conversation in conversations {
            for message in conversation.messages {
                if messageMatches(message, query: query) {
                    results.append(SearchResult(
                        messageId: message.id,
                        conversationId: conversation.id,
                        conversationTitle: conversation.title,
                        messageContent: message.content.displayText,
                        messageDate: message.timestamp,
                        matchType: .partial,
                        context: generateContext(for: message, in: conversation.messages)
                    ))
                }
            }
        }
        
        return results.sorted { $0.messageDate > $1.messageDate }
    }
    
    func searchByCategory(_ conversations: [SavedConversation], category: MessageCategory) async -> [SearchResult] {
        var results: [SearchResult] = []
        
        for conversation in conversations {
            for message in conversation.messages {
                if messageMatchesCategory(message, category: category) {
                    results.append(SearchResult(
                        messageId: message.id,
                        conversationId: conversation.id,
                        conversationTitle: conversation.title,
                        messageContent: message.content.displayText,
                        messageDate: message.timestamp,
                        matchType: .category,
                        context: generateContext(for: message, in: conversation.messages)
                    ))
                }
            }
        }
        
        return results.sorted { $0.messageDate > $1.messageDate }
    }
    
    func advancedSearch(_ conversations: [SavedConversation], criteria: AdvancedSearchCriteria) async -> [SearchResult] {
        var results: [SearchResult] = []
        
        for conversation in conversations {
            for message in conversation.messages {
                if messageMatchesCriteria(message, criteria: criteria, conversationTags: conversation.tags) {
                    results.append(SearchResult(
                        messageId: message.id,
                        conversationId: conversation.id,
                        conversationTitle: conversation.title,
                        messageContent: message.content.displayText,
                        messageDate: message.timestamp,
                        matchType: .semantic,
                        context: generateContext(for: message, in: conversation.messages)
                    ))
                }
            }
        }
        
        return results.sorted { $0.messageDate > $1.messageDate }
    }
    
    private func messageMatches(_ message: ChatMessage, query: String) -> Bool {
        return message.content.displayText.localizedCaseInsensitiveContains(query)
    }
    
    private func messageMatchesCategory(_ message: ChatMessage, category: MessageCategory) -> Bool {
        switch category {
        case .outfit:
            return message.content.displayText.lowercased().contains("outfit")
        case .color:
            return message.content.displayText.lowercased().contains("color")
        case .advice:
            return message.content.displayText.lowercased().contains("suggest") ||
                   message.content.displayText.lowercased().contains("recommend")
        case .question:
            return message.content.displayText.contains("?")
        case .compliment:
            return message.content.displayText.lowercased().contains("love") ||
                   message.content.displayText.lowercased().contains("beautiful")
        case .suggestion:
            if case .suggestion = message.content {
                return true
            }
            return false
        }
    }
    
    private func messageMatchesCriteria(_ message: ChatMessage, criteria: AdvancedSearchCriteria, conversationTags: [String]) -> Bool {
        // Check query
        if let query = criteria.query, !query.isEmpty {
            if !messageMatches(message, query: query) {
                return false
            }
        }
        
        // Check date range
        if let dateRange = criteria.dateRange {
            if !dateRange.contains(message.timestamp) {
                return false
            }
        }
        
        // Check message types
        if !criteria.messageTypes.isEmpty {
            let matchesType = criteria.messageTypes.contains { category in
                messageMatchesCategory(message, category: category)
            }
            if !matchesType {
                return false
            }
        }
        
        // Check senders
        if !criteria.senders.isEmpty {
            if !criteria.senders.contains(where: { sender in
                switch (sender, message.sender) {
                case (.user, .user):
                    return true
                case (.ai(let persona1), .ai(let persona2)):
                    return persona1.id == persona2.id
                default:
                    return false
                }
            }) {
                return false
            }
        }
        
        // Check tags
        if !criteria.tags.isEmpty {
            let messageText = message.content.displayText.lowercased()
            let hasMatchingTag = criteria.tags.contains { tag in
                messageText.contains(tag.lowercased()) || conversationTags.contains(tag)
            }
            if !hasMatchingTag {
                return false
            }
        }
        
        return true
    }
    
    private func generateContext(for message: ChatMessage, in session: ChatSession) -> String {
        return generateContext(for: message, in: session.messages)
    }
    
    private func generateContext(for message: ChatMessage, in messages: [ChatMessage]) -> String {
        guard let messageIndex = messages.firstIndex(where: { $0.id == message.id }) else {
            return ""
        }
        
        let contextRange = max(0, messageIndex - 1)...min(messages.count - 1, messageIndex + 1)
        let contextMessages = Array(messages[contextRange])
        
        return contextMessages.map { $0.content.displayText }.joined(separator: " | ")
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}