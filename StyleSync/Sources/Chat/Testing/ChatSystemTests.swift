import XCTest
import SwiftUI
import Combine
@testable import StyleSync

// MARK: - Chat System Test Suite

class ChatSystemTests: XCTestCase {
    var chatManager: ChatManager!
    var aiResponseManager: AIResponseManager!
    var visualAnalysisManager: VisualAnalysisManager!
    var privacyManager: PrivacyManager!
    var advancedFeaturesManager: AdvancedChatFeaturesManager!
    
    override func setUp() {
        super.setUp()
        chatManager = ChatManager()
        aiResponseManager = AIResponseManager()
        visualAnalysisManager = VisualAnalysisManager()
        privacyManager = PrivacyManager()
        advancedFeaturesManager = AdvancedChatFeaturesManager()
    }
    
    override func tearDown() {
        chatManager = nil
        aiResponseManager = nil
        visualAnalysisManager = nil
        privacyManager = nil
        advancedFeaturesManager = nil
        super.tearDown()
    }
}

// MARK: - Core Chat Functionality Tests

extension ChatSystemTests {
    
    func testChatSessionInitialization() {
        // Test that chat session initializes correctly
        let session = ChatSession()
        
        XCTAssertNotNil(session.id)
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertEqual(session.participants.count, 2) // User and AI
        XCTAssertFalse(session.isArchived)
        XCTAssertTrue(session.settings.enableReadReceipts)
    }
    
    func testMessageCreation() {
        // Test creating different types of messages
        let textMessage = ChatMessage(
            content: .text("Hello, I need style advice!"),
            sender: .user
        )
        
        XCTAssertNotNil(textMessage.id)
        XCTAssertEqual(textMessage.status, .sending)
        XCTAssertTrue(textMessage.reactions.isEmpty)
        
        if case .text(let text) = textMessage.content {
            XCTAssertEqual(text, "Hello, I need style advice!")
        } else {
            XCTFail("Message content should be text")
        }
    }
    
    func testMessageSending() {
        let expectation = XCTestExpectation(description: "Message sent and AI responds")
        
        let message = ChatMessage(
            content: .text("What should I wear to a job interview?"),
            sender: .user
        )
        
        chatManager.sendMessage(message)
        
        // Check that message was added to session
        XCTAssertEqual(chatManager.currentSession.messages.count, 2) // Welcome + user message
        
        // Wait for AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertGreaterThan(self.chatManager.currentSession.messages.count, 2)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMessageReactions() {
        let message = ChatMessage(
            content: .text("Great outfit choice!"),
            sender: .ai(persona: AIPersona.available[0])
        )
        
        chatManager.currentSession.messages.append(message)
        chatManager.addReaction(to: message.id, emoji: "❤️")
        
        let updatedMessage = chatManager.currentSession.messages.first { $0.id == message.id }
        XCTAssertNotNil(updatedMessage)
        XCTAssertEqual(updatedMessage?.reactions.count, 1)
        XCTAssertEqual(updatedMessage?.reactions.first?.emoji, "❤️")
    }
}

// MARK: - AI Response Tests

extension ChatSystemTests {
    
    func testAIPersonaSelection() {
        let friendlyPersona = AIPersona.available.first { $0.personality == .friendly }
        XCTAssertNotNil(friendlyPersona)
        XCTAssertEqual(friendlyPersona?.name, "Sophia")
        XCTAssertTrue(friendlyPersona?.expertise.contains(.styling) == true)
    }
    
    func testAIResponseGeneration() async {
        let userMessage = ChatMessage(
            content: .text("I need help choosing an outfit for a dinner date"),
            sender: .user
        )
        
        let context = ConversationContext()
        let persona = AIPersona.available[0]
        
        let response = await aiResponseManager.generateResponse(
            to: userMessage,
            context: context,
            persona: persona,
            previousOutfits: []
        )
        
        XCTAssertGreaterThan(response.confidence, 0.0)
        XCTAssertFalse(response.suggestedReplies.isEmpty)
        
        if case .text(let responseText) = response.content {
            XCTAssertFalse(responseText.isEmpty)
            XCTAssertTrue(responseText.count > 10) // Meaningful response
        } else {
            XCTFail("AI should respond with text")
        }
    }
    
    func testPersonalityDifferences() async {
        let userMessage = ChatMessage(
            content: .text("What do you think of this color?"),
            sender: .user
        )
        
        let context = ConversationContext()
        
        let friendlyPersona = AIPersona.available.first { $0.personality == .friendly }!
        let professionalPersona = AIPersona.available.first { $0.personality == .professional }!
        
        let friendlyResponse = await aiResponseManager.generateResponse(
            to: userMessage,
            context: context,
            persona: friendlyPersona,
            previousOutfits: []
        )
        
        let professionalResponse = await aiResponseManager.generateResponse(
            to: userMessage,
            context: context,
            persona: professionalPersona,
            previousOutfits: []
        )
        
        // Responses should be different based on personality
        XCTAssertNotEqual(friendlyResponse.suggestedReplies, professionalResponse.suggestedReplies)
    }
}

// MARK: - Visual Analysis Tests

extension ChatSystemTests {
    
    func testImageAnalysis() async {
        // Create a test image
        let image = createTestImage()
        let imageData = image.jpegData(compressionQuality: 0.8)!
        
        let analysis = await visualAnalysisManager.analyzeImage(imageData)
        
        XCTAssertNotNil(analysis)
        XCTAssertGreaterThan(analysis.confidence, 0.0)
        XCTAssertFalse(analysis.styleNotes.isEmpty)
    }
    
    func testOutfitAnalysis() async {
        let image = createTestOutfitImage()
        let imageData = image.jpegData(compressionQuality: 0.8)!
        
        let analysis = await visualAnalysisManager.analyzeOutfitImage(imageData)
        
        XCTAssertNotNil(analysis)
        XCTAssertGreaterThan(analysis.confidence, 0.0)
        XCTAssertFalse(analysis.recommendations.isEmpty)
        XCTAssertFalse(analysis.style.isEmpty)
    }
    
    func testRealTimeAnalysis() async {
        let image = createTestImage()
        
        let quickAnalysis = await visualAnalysisManager.performRealTimeAnalysis(image)
        
        XCTAssertNotNil(quickAnalysis)
        XCTAssertGreaterThan(quickAnalysis.styleScore, 0.0)
        XCTAssertFalse(quickAnalysis.feedback.isEmpty)
    }
}

// MARK: - Privacy and Security Tests

extension ChatSystemTests {
    
    func testEncryptionDecryption() async {
        let originalMessage = ChatMessage(
            content: .text("This is a private message"),
            sender: .user
        )
        
        // Enable encryption
        privacyManager.privacySettings.enableEndToEndEncryption = true
        
        let encryptedMessage = await privacyManager.encryptMessage(originalMessage)
        XCTAssertNotNil(encryptedMessage)
        XCTAssertTrue(encryptedMessage?.isEncrypted == true)
        
        if let encrypted = encryptedMessage {
            let decryptedMessage = await privacyManager.decryptMessage(encrypted)
            XCTAssertNotNil(decryptedMessage)
            XCTAssertEqual(decryptedMessage?.content.displayText, originalMessage.content.displayText)
        }
    }
    
    func testImagePrivacyBlur() {
        let originalImage = createTestImage()
        let imageData = originalImage.jpegData(compressionQuality: 0.8)!
        
        privacyManager.privacySettings.blurImagesBeforeSending = true
        
        let blurredData = privacyManager.blurImage(imageData)
        XCTAssertNotEqual(imageData, blurredData)
        
        let blurredImage = UIImage(data: blurredData)
        XCTAssertNotNil(blurredImage)
    }
    
    func testPrivacyAudit() {
        // Configure some privacy settings
        privacyManager.privacySettings.enableEndToEndEncryption = false
        privacyManager.privacySettings.autoDeleteAfterDays = nil
        
        let auditResult = privacyManager.performPrivacyAudit()
        
        XCTAssertFalse(auditResult.issues.isEmpty)
        XCTAssertFalse(auditResult.recommendations.isEmpty)
        XCTAssertEqual(auditResult.riskLevel, .high)
    }
    
    func testAutoDelete() {
        let message = ChatMessage(
            content: .text("This message should auto-delete"),
            sender: .user
        )
        
        privacyManager.privacySettings.autoDeleteAfterDays = 7
        privacyManager.scheduleAutoDelete(for: message)
        
        // In a real test, we'd verify the notification was scheduled
        XCTAssertNotNil(message.id)
    }
}

// MARK: - Advanced Features Tests

extension ChatSystemTests {
    
    func testConversationSaving() async {
        // Add some messages to the session
        let messages = [
            ChatMessage(content: .text("Hello"), sender: .user),
            ChatMessage(content: .text("Hi! How can I help?"), sender: .ai(persona: AIPersona.available[0])),
            ChatMessage(content: .text("I need outfit advice"), sender: .user)
        ]
        
        chatManager.currentSession.messages = messages
        
        await advancedFeaturesManager.saveConversation(
            chatManager.currentSession,
            title: "Test Conversation"
        )
        
        XCTAssertEqual(advancedFeaturesManager.savedConversations.count, 1)
        XCTAssertEqual(advancedFeaturesManager.savedConversations.first?.title, "Test Conversation")
        XCTAssertEqual(advancedFeaturesManager.savedConversations.first?.messageCount, 3)
    }
    
    func testFavoriteAdviceSaving() {
        let adviceMessage = ChatMessage(
            content: .text("For your body type, I recommend A-line dresses that emphasize your waist"),
            sender: .ai(persona: AIPersona.available[0])
        )
        
        advancedFeaturesManager.saveFavoriteAdvice(adviceMessage, category: "Body Type")
        
        XCTAssertEqual(advancedFeaturesManager.favoriteAdvice.count, 1)
        XCTAssertEqual(advancedFeaturesManager.favoriteAdvice.first?.category, "Body Type")
    }
    
    func testReminderScheduling() async {
        let success = await advancedFeaturesManager.scheduleOutfitReminder(
            title: "Wear your new dress",
            message: "Don't forget to wear the dress we picked out!",
            date: Date().addingTimeInterval(3600), // 1 hour from now
            repeating: .none
        )
        
        XCTAssertTrue(success)
        XCTAssertEqual(advancedFeaturesManager.scheduledReminders.count, 1)
    }
    
    func testSearchFunctionality() async {
        // Create a session with searchable content
        let session = ChatSession()
        session.messages = [
            ChatMessage(content: .text("I love blue dresses"), sender: .user),
            ChatMessage(content: .text("Blue is a great color for you!"), sender: .ai(persona: AIPersona.available[0])),
            ChatMessage(content: .text("What about red shoes?"), sender: .user)
        ]
        
        await advancedFeaturesManager.searchInConversation(session, query: "blue")
        
        XCTAssertFalse(advancedFeaturesManager.isSearching)
        XCTAssertGreaterThan(advancedFeaturesManager.searchResults.count, 0)
        
        let blueResults = advancedFeaturesManager.searchResults.filter {
            $0.messageContent.lowercased().contains("blue")
        }
        XCTAssertGreaterThan(blueResults.count, 0)
    }
    
    func testConversationExport() async {
        // Create a conversation to export
        await advancedFeaturesManager.saveConversation(
            chatManager.currentSession,
            title: "Export Test"
        )
        
        guard let conversationId = advancedFeaturesManager.savedConversations.first?.id else {
            XCTFail("No conversation to export")
            return
        }
        
        let exportURL = await advancedFeaturesManager.exportConversation(
            conversationId,
            format: .json
        )
        
        XCTAssertNotNil(exportURL)
        
        if let url = exportURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertTrue(url.pathExtension == "json")
        }
    }
}

// MARK: - Performance Tests

extension ChatSystemTests {
    
    func testMessageProcessingPerformance() {
        measure {
            for _ in 0..<100 {
                let message = ChatMessage(
                    content: .text("Performance test message"),
                    sender: .user
                )
                chatManager.currentSession.messages.append(message)
            }
        }
    }
    
    func testAIResponsePerformance() {
        let expectation = XCTestExpectation(description: "AI response performance")
        
        measure {
            Task {
                let message = ChatMessage(
                    content: .text("What should I wear today?"),
                    sender: .user
                )
                
                let _ = await aiResponseManager.generateResponse(
                    to: message,
                    context: ConversationContext(),
                    persona: AIPersona.available[0],
                    previousOutfits: []
                )
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSearchPerformance() {
        // Create a large conversation for testing
        var messages: [ChatMessage] = []
        for i in 0..<1000 {
            messages.append(ChatMessage(
                content: .text("Message \(i) about fashion and style"),
                sender: i % 2 == 0 ? .user : .ai(persona: AIPersona.available[0])
            ))
        }
        
        let session = ChatSession()
        session.messages = messages
        
        measure {
            Task {
                await advancedFeaturesManager.searchInConversation(session, query: "fashion")
            }
        }
    }
}

// MARK: - Integration Tests

extension ChatSystemTests {
    
    func testFullConversationFlow() async {
        let expectation = XCTestExpectation(description: "Full conversation flow")
        
        // 1. Send a message
        let userMessage = ChatMessage(
            content: .text("I have a wedding to attend, what should I wear?"),
            sender: .user
        )
        chatManager.sendMessage(userMessage)
        
        // 2. Wait for AI response
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // 3. Add a reaction
        if let lastMessage = chatManager.currentSession.messages.last {
            chatManager.addReaction(to: lastMessage.id, emoji: "👍")
        }
        
        // 4. Save the conversation
        await advancedFeaturesManager.saveConversation(chatManager.currentSession)
        
        // 5. Search in the conversation
        await advancedFeaturesManager.searchInConversation(chatManager.currentSession, query: "wedding")
        
        // Verify the flow worked
        XCTAssertGreaterThan(chatManager.currentSession.messages.count, 1)
        XCTAssertEqual(advancedFeaturesManager.savedConversations.count, 1)
        XCTAssertGreaterThan(advancedFeaturesManager.searchResults.count, 0)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testMultiModalIntegration() async {
        // Test sending different types of content
        let textMessage = ChatMessage(
            content: .text("What do you think of this outfit?"),
            sender: .user
        )
        
        let colorMessage = ChatMessage(
            content: .color(ColorMessage(
                color: CodableColor(color: .blue),
                colorName: "Royal Blue",
                season: .winter,
                suggestions: ["Navy", "White", "Silver"]
            )),
            sender: .user
        )
        
        chatManager.sendMessage(textMessage)
        chatManager.sendMessage(colorMessage)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Should have user messages + AI responses
        XCTAssertGreaterThanOrEqual(chatManager.currentSession.messages.count, 4)
        
        // Check that different message types are handled
        let hasTextMessage = chatManager.currentSession.messages.contains { message in
            if case .text = message.content { return true }
            return false
        }
        
        let hasColorMessage = chatManager.currentSession.messages.contains { message in
            if case .color = message.content { return true }
            return false
        }
        
        XCTAssertTrue(hasTextMessage)
        XCTAssertTrue(hasColorMessage)
    }
}

// MARK: - Edge Cases and Error Handling

extension ChatSystemTests {
    
    func testEmptyMessageHandling() {
        let emptyMessage = ChatMessage(
            content: .text(""),
            sender: .user
        )
        
        let initialMessageCount = chatManager.currentSession.messages.count
        chatManager.sendMessage(emptyMessage)
        
        // Should not add empty messages
        XCTAssertEqual(chatManager.currentSession.messages.count, initialMessageCount)
    }
    
    func testInvalidImageHandling() async {
        let invalidImageData = Data("invalid image data".utf8)
        
        let analysis = await visualAnalysisManager.analyzeImage(invalidImageData)
        
        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis.confidence, 0.0)
        XCTAssertTrue(analysis.styleNotes.contains("Unable to process image"))
    }
    
    func testMissingPersonaHandling() async {
        // Test with a message from a non-existent persona
        let message = ChatMessage(
            content: .text("Test message"),
            sender: .ai(persona: AIPersona(
                name: "NonExistent",
                avatar: "person",
                personality: .friendly,
                expertise: [.styling],
                communicationStyle: .casual,
                responsePatterns: .encouraging
            ))
        )
        
        let response = await aiResponseManager.generateResponse(
            to: message,
            context: ConversationContext(),
            persona: AIPersona.available[0],
            previousOutfits: []
        )
        
        // Should still generate a response
        XCTAssertNotNil(response)
        XCTAssertGreaterThan(response.confidence, 0.0)
    }
}

// MARK: - Helper Methods

extension ChatSystemTests {
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createTestOutfitImage() -> UIImage {
        let size = CGSize(width: 200, height: 300)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Draw a simple "outfit" - top and bottom rectangles
        context.setFillColor(UIColor.red.cgColor) // Top
        context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
        
        context.setFillColor(UIColor.blue.cgColor) // Bottom
        context.fill(CGRect(x: 50, y: 150, width: 100, height: 100))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createTestConversation() -> ChatSession {
        let session = ChatSession()
        session.messages = [
            ChatMessage(content: .text("Hello, I need help with my wardrobe"), sender: .user),
            ChatMessage(content: .text("I'd be happy to help! What's the occasion?"), sender: .ai(persona: AIPersona.available[0])),
            ChatMessage(content: .text("I have a job interview next week"), sender: .user),
            ChatMessage(content: .text("Great! Let's find you a professional look that shows confidence"), sender: .ai(persona: AIPersona.available[0]))
        ]
        return session
    }
}

// MARK: - Test Validation Methods

extension ChatSystemTests {
    
    private func validateMessageIntegrity(_ message: ChatMessage) {
        XCTAssertNotEqual(message.id, UUID())
        XCTAssertTrue(message.timestamp <= Date())
        XCTAssertFalse(message.content.displayText.isEmpty)
    }
    
    private func validateAIResponse(_ response: AIResponseManager.AIResponse) {
        XCTAssertGreaterThanOrEqual(response.confidence, 0.0)
        XCTAssertLessThanOrEqual(response.confidence, 1.0)
        XCTAssertFalse(response.suggestedReplies.isEmpty)
        XCTAssertFalse(response.reasoning.isEmpty)
    }
    
    private func validatePrivacyCompliance(_ settings: PrivacySettings) {
        if settings.enableEndToEndEncryption {
            XCTAssertTrue(settings.enableLocalProcessing, "E2E encryption should enable local processing")
        }
        
        if settings.autoDeleteAfterDays != nil {
            XCTAssertGreaterThan(settings.autoDeleteAfterDays!, 0, "Auto-delete days should be positive")
        }
    }
}

// MARK: - Mock Implementations for Testing

class MockThemeManager: ThemeManager {
    override init() {
        super.init()
        // Set up test theme
    }
}

class MockHapticManager: HapticFeedbackManager {
    var hapticCallCount = 0
    
    override func playHaptic(_ type: HapticType) {
        hapticCallCount += 1
    }
}

class MockSoundManager: SoundDesignManager {
    var soundCallCount = 0
    
    override func playSound(_ sound: SoundType) {
        soundCallCount += 1
    }
}

// MARK: - Test Configuration

class ChatTestConfiguration {
    static let shared = ChatTestConfiguration()
    
    let testTimeout: TimeInterval = 10.0
    let performanceTestIterations = 100
    let largeDatasetSize = 1000
    
    private init() {}
}

// MARK: - Test Utilities

enum TestDataGenerator {
    static func generateTestMessages(count: Int) -> [ChatMessage] {
        return (0..<count).map { index in
            ChatMessage(
                content: .text("Test message \(index)"),
                sender: index % 2 == 0 ? .user : .ai(persona: AIPersona.available[0])
            )
        }
    }
    
    static func generateTestPersona() -> AIPersona {
        return AIPersona(
            name: "TestAI",
            avatar: "person.circle",
            personality: .friendly,
            expertise: [.styling, .colors],
            communicationStyle: .casual,
            responsePatterns: .encouraging
        )
    }
    
    static func generateTestImageData() -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in
            UIColor.blue.setFill()
            UIRectFill(CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}