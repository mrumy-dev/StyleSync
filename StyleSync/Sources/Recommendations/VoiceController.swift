import SwiftUI
import Speech
import AVFoundation
import Combine

struct VoiceInteraction: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let isUserSpeech: Bool
    let confidence: Float
}

enum VoiceControlStatus {
    case idle
    case listening
    case processing
    case speaking
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Ready to listen"
        case .listening: return "Listening..."
        case .processing: return "Processing..."
        case .speaking: return "Speaking..."
        case .error(let message): return message
        }
    }
}

enum VoiceAction: String, CaseIterable {
    case showRecommendations = "show_recommendations"
    case filterByCategory = "filter_category"
    case filterByColor = "filter_color"
    case filterByPrice = "filter_price"
    case filterByBrand = "filter_brand"
    case likeProduct = "like_product"
    case dislikeProduct = "dislike_product"
    case saveProduct = "save_product"
    case explainRecommendation = "explain_recommendation"
    case showSimilarProducts = "show_similar"
    case changeMood = "change_mood"
    case showOutfit = "show_outfit"
    case compareProducts = "compare_products"
    case openCart = "open_cart"
    case openProfile = "open_profile"
    case toggleTheme = "toggle_theme"

    var description: String {
        switch self {
        case .showRecommendations: return "Show recommendations"
        case .filterByCategory: return "Filter by category"
        case .filterByColor: return "Filter by color"
        case .filterByPrice: return "Filter by price"
        case .filterByBrand: return "Filter by brand"
        case .likeProduct: return "Like current product"
        case .dislikeProduct: return "Dislike current product"
        case .saveProduct: return "Save current product"
        case .explainRecommendation: return "Explain recommendation"
        case .showSimilarProducts: return "Show similar products"
        case .changeMood: return "Change mood"
        case .showOutfit: return "Show complete outfit"
        case .compareProducts: return "Compare products"
        case .openCart: return "Open shopping cart"
        case .openProfile: return "Open user profile"
        case .toggleTheme: return "Toggle app theme"
        }
    }

    var requiresParameters: Bool {
        switch self {
        case .filterByCategory, .filterByColor, .filterByPrice, .filterByBrand, .changeMood:
            return true
        default:
            return false
        }
    }
}

struct CustomVoiceCommand: Identifiable, Codable {
    let id: UUID
    let phrase: String
    let action: VoiceAction
    let parameters: String?
    let isEnabled: Bool
    let createdAt: Date
}

class VoiceSettings: ObservableObject {
    static let shared = VoiceSettings()

    @Published var continuousListening = false
    @Published var recognitionLanguage = "en-US"
    @Published var sensitivity = Sensitivity.medium
    @Published var speakResponses = true
    @Published var selectedVoice = "com.apple.ttsbundle.Samantha-compact"
    @Published var speechRate: Float = 0.5
    @Published var customWakeWord = false
    @Published var wakeWord = "Hey StyleSync"
    @Published var storeVoiceData = false
    @Published var improveRecognition = true

    enum Sensitivity: String, CaseIterable {
        case low, medium, high
    }

    struct SupportedLanguage {
        let code: String
        let name: String
    }

    static let supportedLanguages = [
        SupportedLanguage(code: "en-US", name: "English (US)"),
        SupportedLanguage(code: "en-GB", name: "English (UK)"),
        SupportedLanguage(code: "es-ES", name: "Spanish"),
        SupportedLanguage(code: "fr-FR", name: "French"),
        SupportedLanguage(code: "de-DE", name: "German"),
        SupportedLanguage(code: "it-IT", name: "Italian"),
        SupportedLanguage(code: "pt-BR", name: "Portuguese"),
        SupportedLanguage(code: "ja-JP", name: "Japanese"),
        SupportedLanguage(code: "ko-KR", name: "Korean"),
        SupportedLanguage(code: "zh-CN", name: "Chinese (Simplified)")
    ]

    lazy var availableVoices: [AVSpeechSynthesisVoice] = {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(String(recognitionLanguage.prefix(2))) }
    }()

    func clearVoiceHistory() {
        // Implementation to clear stored voice data
        UserDefaults.standard.removeObject(forKey: "voice_history")
    }
}

class CustomCommandManager: ObservableObject {
    static let shared = CustomCommandManager()

    @Published var customCommands: [CustomVoiceCommand] = []

    private let userDefaults = UserDefaults.standard
    private let commandsKey = "custom_voice_commands"

    init() {
        loadCommands()
    }

    func addCommand(_ command: CustomVoiceCommand) {
        customCommands.append(command)
        saveCommands()
    }

    func deleteCommand(_ command: CustomVoiceCommand) {
        customCommands.removeAll { $0.id == command.id }
        saveCommands()
    }

    func deleteCommands(at offsets: IndexSet) {
        customCommands.remove(atOffsets: offsets)
        saveCommands()
    }

    private func loadCommands() {
        if let data = userDefaults.data(forKey: commandsKey),
           let commands = try? JSONDecoder().decode([CustomVoiceCommand].self, from: data) {
            customCommands = commands
        }
    }

    private func saveCommands() {
        if let data = try? JSONEncoder().encode(customCommands) {
            userDefaults.set(data, forKey: commandsKey)
        }
    }
}

@MainActor
class VoiceController: ObservableObject {
    @Published var status: VoiceControlStatus = .idle
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var isSpeaking = false
    @Published var hasPermission = false
    @Published var audioLevel: CGFloat = 0
    @Published var currentSpeechText = ""
    @Published var lastResponse = ""
    @Published var conversationHistory: [VoiceInteraction] = []

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioLevelTimer: Timer?

    private let voiceCommandProcessor = VoiceCommandProcessor()
    private let nlpProcessor = NLPProcessor()

    let suggestedCommands = [
        "Show me summer dresses",
        "Find blue tops under $50",
        "I like this product",
        "Explain why this matches",
        "Show similar items",
        "What's trending now?",
        "Filter by sustainable brands",
        "Show me my saved items"
    ]

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: VoiceSettings.shared.recognitionLanguage))
        self.speechSynthesizer.delegate = self

        // Configure audio session
        configureAudioSession()
        checkPermissions()
    }

    func checkPermissions() {
        Task {
            let speechPermission = await requestSpeechPermission()
            let microphonePermission = await requestMicrophonePermission()

            hasPermission = speechPermission && microphonePermission

            if !hasPermission {
                status = .error("Permissions required")
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard hasPermission && !isListening else { return }

        // Reset previous session
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)

            // Calculate audio level for visualization
            self?.updateAudioLevel(from: buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            handleError("Audio engine failed to start: \(error)")
            return
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                self?.currentSpeechText = spokenText

                // Process command if speech is final
                if result.isFinal {
                    Task {
                        await self?.processSpokenCommand(spokenText)
                    }
                }
            }

            if let error = error {
                self?.handleError("Recognition failed: \(error)")
            }
        }

        // Update state
        isListening = true
        status = .listening
        currentSpeechText = ""

        // Start audio level monitoring
        startAudioLevelMonitoring()

        // Auto-stop after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if self?.isListening == true {
                self?.stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        status = .idle

        stopAudioLevelMonitoring()
    }

    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Audio level is updated in the audio tap callback
        }
    }

    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frames = buffer.frameLength
        var sum: Float = 0

        for i in 0..<Int(frames) {
            sum += abs(channelData[i])
        }

        let averageLevel = sum / Float(frames)
        let normalizedLevel = min(max(averageLevel * 10, 0), 1)

        DispatchQueue.main.async {
            self.audioLevel = CGFloat(normalizedLevel)
        }
    }

    private func processSpokenCommand(_ spokenText: String) async {
        status = .processing
        isProcessing = true

        // Add user speech to conversation history
        let userInteraction = VoiceInteraction(
            text: spokenText,
            timestamp: Date(),
            isUserSpeech: true,
            confidence: 1.0
        )
        conversationHistory.append(userInteraction)

        do {
            // Process command using NLP
            let processedCommand = await nlpProcessor.processNaturalLanguage(spokenText)

            // Execute command
            let response = await voiceCommandProcessor.executeCommand(processedCommand)

            // Generate response text
            lastResponse = response.responseText

            // Add AI response to conversation history
            let aiInteraction = VoiceInteraction(
                text: lastResponse,
                timestamp: Date(),
                isUserSpeech: false,
                confidence: response.confidence
            )
            conversationHistory.append(aiInteraction)

            // Speak response if enabled
            if VoiceSettings.shared.speakResponses {
                speakResponse(lastResponse)
            }

        } catch {
            handleError("Command processing failed: \(error)")
        }

        isProcessing = false
        status = .idle
        currentSpeechText = ""
    }

    func processCommand(_ command: String) {
        Task {
            await processSpokenCommand(command)
        }
    }

    func speakLastResponse() {
        if !lastResponse.isEmpty {
            speakResponse(lastResponse)
        }
    }

    private func speakResponse(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)

        // Configure speech
        if let voice = AVSpeechSynthesisVoice(identifier: VoiceSettings.shared.selectedVoice) {
            utterance.voice = voice
        }

        utterance.rate = VoiceSettings.shared.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        status = .speaking

        speechSynthesizer.speak(utterance)
    }

    func clearConversation() {
        conversationHistory.removeAll()
        lastResponse = ""
        currentSpeechText = ""
    }

    private func handleError(_ message: String) {
        print("Voice Control Error: \(message)")
        status = .error(message)
        isListening = false
        isProcessing = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        status = .idle
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        status = .idle
    }
}

// MARK: - Supporting Classes
struct ProcessedCommand {
    let intent: VoiceAction
    let entities: [String: String]
    let confidence: Float
    let originalText: String
}

struct CommandResponse {
    let responseText: String
    let confidence: Float
    let actionTaken: Bool
    let additionalData: [String: Any]?
}

class NLPProcessor {
    func processNaturalLanguage(_ text: String) async -> ProcessedCommand {
        // Simplified NLP processing
        // In a real implementation, this would use advanced NLP libraries

        let lowercaseText = text.lowercased()
        var intent: VoiceAction = .showRecommendations
        var entities: [String: String] = [:]
        var confidence: Float = 0.5

        // Intent classification
        if lowercaseText.contains("show") && (lowercaseText.contains("dress") || lowercaseText.contains("top") || lowercaseText.contains("clothes")) {
            intent = .showRecommendations
            confidence = 0.8
        } else if lowercaseText.contains("like") {
            intent = .likeProduct
            confidence = 0.9
        } else if lowercaseText.contains("don't like") || lowercaseText.contains("dislike") {
            intent = .dislikeProduct
            confidence = 0.9
        } else if lowercaseText.contains("save") || lowercaseText.contains("bookmark") {
            intent = .saveProduct
            confidence = 0.8
        } else if lowercaseText.contains("explain") || lowercaseText.contains("why") {
            intent = .explainRecommendation
            confidence = 0.8
        } else if lowercaseText.contains("similar") {
            intent = .showSimilarProducts
            confidence = 0.8
        } else if lowercaseText.contains("filter") || lowercaseText.contains("find") {
            if lowercaseText.contains("color") || extractColors(from: lowercaseText).count > 0 {
                intent = .filterByColor
                entities["color"] = extractColors(from: lowercaseText).first ?? ""
            } else if lowercaseText.contains("brand") {
                intent = .filterByBrand
                entities["brand"] = extractBrands(from: lowercaseText).first ?? ""
            } else if lowercaseText.contains("price") || lowercaseText.contains("$") || lowercaseText.contains("under") {
                intent = .filterByPrice
                entities["price"] = extractPrice(from: lowercaseText)
            } else {
                intent = .filterByCategory
                entities["category"] = extractCategory(from: lowercaseText)
            }
            confidence = 0.7
        }

        return ProcessedCommand(
            intent: intent,
            entities: entities,
            confidence: confidence,
            originalText: text
        )
    }

    private func extractColors(from text: String) -> [String] {
        let colors = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "brown", "black", "white", "gray", "navy"]
        return colors.filter { text.lowercased().contains($0) }
    }

    private func extractBrands(from text: String) -> [String] {
        let brands = ["zara", "h&m", "uniqlo", "nike", "adidas", "levi's", "gucci", "prada"]
        return brands.filter { text.lowercased().contains($0) }
    }

    private func extractPrice(from text: String) -> String {
        // Simple price extraction
        let patterns = ["\\$\\d+", "under \\d+", "below \\d+", "less than \\d+"]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        return ""
    }

    private func extractCategory(from text: String) -> String {
        let categories = ["dress", "top", "shirt", "pants", "jeans", "shoes", "jacket", "sweater", "skirt"]
        for category in categories {
            if text.lowercased().contains(category) {
                return category
            }
        }
        return "clothing"
    }
}

class VoiceCommandProcessor {
    func executeCommand(_ command: ProcessedCommand) async -> CommandResponse {
        switch command.intent {
        case .showRecommendations:
            return await showRecommendations(entities: command.entities)

        case .filterByCategory:
            return await filterByCategory(category: command.entities["category"] ?? "")

        case .filterByColor:
            return await filterByColor(color: command.entities["color"] ?? "")

        case .filterByPrice:
            return await filterByPrice(price: command.entities["price"] ?? "")

        case .filterByBrand:
            return await filterByBrand(brand: command.entities["brand"] ?? "")

        case .likeProduct:
            return await likeCurrentProduct()

        case .dislikeProduct:
            return await dislikeCurrentProduct()

        case .saveProduct:
            return await saveCurrentProduct()

        case .explainRecommendation:
            return await explainCurrentRecommendation()

        case .showSimilarProducts:
            return await showSimilarProducts()

        default:
            return CommandResponse(
                responseText: "I understand, but I can't perform that action yet.",
                confidence: 0.5,
                actionTaken: false,
                additionalData: nil
            )
        }
    }

    private func showRecommendations(entities: [String: String]) async -> CommandResponse {
        // Implementation would trigger recommendation display
        let category = entities["category"] ?? "items"
        return CommandResponse(
            responseText: "Here are some \(category) recommendations for you!",
            confidence: 0.9,
            actionTaken: true,
            additionalData: ["action": "show_recommendations"]
        )
    }

    private func filterByCategory(category: String) async -> CommandResponse {
        return CommandResponse(
            responseText: "Filtering by \(category). Let me find the best options for you.",
            confidence: 0.8,
            actionTaken: true,
            additionalData: ["action": "filter", "type": "category", "value": category]
        )
    }

    private func filterByColor(color: String) async -> CommandResponse {
        return CommandResponse(
            responseText: "Showing \(color) items. Great choice!",
            confidence: 0.8,
            actionTaken: true,
            additionalData: ["action": "filter", "type": "color", "value": color]
        )
    }

    private func filterByPrice(price: String) async -> CommandResponse {
        return CommandResponse(
            responseText: "Filtering by price range \(price). Looking for great deals!",
            confidence: 0.8,
            actionTaken: true,
            additionalData: ["action": "filter", "type": "price", "value": price]
        )
    }

    private func filterByBrand(brand: String) async -> CommandResponse {
        return CommandResponse(
            responseText: "Showing items from \(brand). They have great style!",
            confidence: 0.8,
            actionTaken: true,
            additionalData: ["action": "filter", "type": "brand", "value": brand]
        )
    }

    private func likeCurrentProduct() async -> CommandResponse {
        return CommandResponse(
            responseText: "Great choice! I've noted that you like this item and will recommend similar styles.",
            confidence: 0.9,
            actionTaken: true,
            additionalData: ["action": "like_product"]
        )
    }

    private func dislikeCurrentProduct() async -> CommandResponse {
        return CommandResponse(
            responseText: "Thanks for the feedback! I'll avoid recommending similar items in the future.",
            confidence: 0.9,
            actionTaken: true,
            additionalData: ["action": "dislike_product"]
        )
    }

    private func saveCurrentProduct() async -> CommandResponse {
        return CommandResponse(
            responseText: "I've saved this item to your wishlist. You can find it later in your saved items.",
            confidence: 0.9,
            actionTaken: true,
            additionalData: ["action": "save_product"]
        )
    }

    private func explainCurrentRecommendation() async -> CommandResponse {
        return CommandResponse(
            responseText: "I recommended this because it matches your style preferences, fits your budget, and is perfect for the current season. The color complements your wardrobe beautifully!",
            confidence: 0.8,
            actionTaken: true,
            additionalData: ["action": "explain_recommendation"]
        )
    }

    private func showSimilarProducts() async -> CommandResponse {
        return CommandResponse(
            responseText: "Here are some similar items you might love! They share the same style aesthetic and quality.",
            confidence: 0.8,
            actionTaken: true,
            additionalData: ["action": "show_similar"]
        )
    }
}