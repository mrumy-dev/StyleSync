import Foundation
import SwiftUI
import CoreML
import Vision
import AVFoundation
import Combine
import CryptoKit

// MARK: - AI Style Engine

@MainActor
class AIStyleEngine: ObservableObject {
    static let shared = AIStyleEngine()

    @Published var isAnalyzing = false
    @Published var confidence: Double = 0.0
    @Published var lastAnalysis: StyleAnalysis?
    @Published var personalShopper = PersonalShopperAI()
    @Published var styleDNA: StyleDNA?

    private let openAIProvider = OpenAIProvider()
    private let claudeProvider = ClaudeProvider()
    private let coreMLAnalyzer = CoreMLStyleAnalyzer()
    private let visionAnalyzer = VisionAnalyzer()
    private let trendPredictor = TrendPredictor()
    private let qualityAssessment = QualityAssessment()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupAIProviders()
    }

    private func setupAIProviders() {
        // Initialize AI providers with secure API keys
        Task {
            await openAIProvider.initialize()
            await claudeProvider.initialize()
            await coreMLAnalyzer.loadModels()
        }
    }

    // MARK: - Style Analysis Pipeline

    func analyzeStyle(for image: UIImage, context: AnalysisContext = .general) async -> StyleAnalysis {
        isAnalyzing = true

        do {
            // Multi-layered analysis approach
            async let coreMLResult = coreMLAnalyzer.analyze(image)
            async let visionResult = visionAnalyzer.detectObjects(in: image)
            async let fabricAnalysis = analyzeFabric(image)
            async let brandRecognition = recognizeBrand(image)
            async let qualityScore = qualityAssessment.assess(image)
            async let fitAnalysis = analyzeFit(image, context: context)
            async let colorSeason = detectColorSeason(image)

            // Combine results
            let analysis = StyleAnalysis(
                coreMLResults: try await coreMLResult,
                visionObjects: try await visionResult,
                fabricInfo: try await fabricAnalysis,
                brandInfo: try await brandRecognition,
                qualityScore: try await qualityScore,
                fitAnalysis: try await fitAnalysis,
                colorSeason: try await colorSeason,
                confidence: calculateConfidence(),
                timestamp: Date()
            )

            // AI Enhancement with multiple providers
            let enhancedAnalysis = await enhanceWithAI(analysis, context: context)

            lastAnalysis = enhancedAnalysis
            isAnalyzing = false

            // Update Style DNA
            await updateStyleDNA(with: enhancedAnalysis)

            return enhancedAnalysis

        } catch {
            isAnalyzing = false
            return StyleAnalysis.fallback(error: error)
        }
    }

    // MARK: - Real-time Outfit Scoring

    func scoreOutfit(_ items: [StyleItem], occasion: Occasion = .casual) async -> OutfitScore {
        let combinedImages = await combineItemImages(items)

        async let styleHarmony = calculateStyleHarmony(items)
        async let colorCoordination = analyzeColorCoordination(items)
        async let occasionFit = assessOccasionFitness(items, for: occasion)
        async let trendAlignment = checkTrendAlignment(items)
        async let personalFit = assessPersonalStyleFit(items)

        let score = OutfitScore(
            overall: try await (styleHarmony + colorCoordination + occasionFit + trendAlignment + personalFit) / 5,
            breakdown: OutfitScoreBreakdown(
                styleHarmony: try await styleHarmony,
                colorCoordination: try await colorCoordination,
                occasionFit: try await occasionFit,
                trendAlignment: try await trendAlignment,
                personalFit: try await personalFit
            ),
            suggestions: await generateOutfitSuggestions(items, score: try await styleHarmony),
            confidence: confidence
        )

        return score
    }

    // MARK: - Live Camera Analysis

    func provideLiveSuggestions(for frame: CVPixelBuffer) async -> LiveSuggestions {
        let image = UIImage(ciImage: CIImage(cvPixelBuffer: frame))

        // Real-time lightweight analysis
        async let quickAnalysis = coreMLAnalyzer.quickAnalyze(image)
        async let colorProfile = extractColorProfile(image)
        async let styleElements = detectStyleElements(image)

        let suggestions = LiveSuggestions(
            analysis: try await quickAnalysis,
            colorProfile: try await colorProfile,
            styleElements: try await styleElements,
            recommendations: await generateLiveRecommendations(image),
            confidence: confidence * 0.8 // Lower confidence for real-time
        )

        return suggestions
    }

    // MARK: - Wardrobe Gap Analysis

    func analyzeWardrobeGaps(for items: [StyleItem]) async -> WardrobeGapAnalysis {
        // Categorize existing items
        let categories = categorizeItems(items)
        let colorPalette = extractWardrobeColorPalette(items)
        let styleProfile = await createStyleProfile(from: items)

        // AI-powered gap detection
        let prompt = createWardrobeGapPrompt(categories: categories, palette: colorPalette, style: styleProfile)

        async let openAIGaps = openAIProvider.analyzeGaps(prompt: prompt)
        async let claudeGaps = claudeProvider.analyzeGaps(prompt: prompt)

        // Combine and validate results
        let combinedGaps = try await combineGapAnalyses(
            openAI: openAIGaps,
            claude: claudeGaps
        )

        let analysis = WardrobeGapAnalysis(
            missingCategories: combinedGaps.categories,
            colorGaps: combinedGaps.colors,
            styleGaps: combinedGaps.styles,
            seasonalGaps: combinedGaps.seasonal,
            recommendations: await generateGapRecommendations(combinedGaps),
            priorityScore: calculateGapPriority(combinedGaps),
            budget: estimateBudgetRequirements(combinedGaps)
        )

        return analysis
    }

    // MARK: - Style Evolution Tracking

    func trackStyleEvolution(over period: TimePeriod) async -> StyleEvolution {
        let historicalData = await fetchStyleHistory(period: period)
        let trendData = await trendPredictor.analyzeTrends(for: period)

        let evolution = StyleEvolution(
            timeframe: period,
            styleProgression: analyzeStyleProgression(historicalData),
            preferenceChanges: trackPreferenceChanges(historicalData),
            trendInfluence: calculateTrendInfluence(trendData),
            personalGrowth: assessPersonalGrowth(historicalData),
            futureProjections: await projectFutureStyle(based: historicalData)
        )

        return evolution
    }

    // MARK: - Personalized Fashion Reports

    func generatePersonalizedReport(for period: TimePeriod = .monthly) async -> FashionReport {
        async let styleAnalysis = analyzePersonalStyle()
        async let wearingPatterns = analyzeWearingPatterns(period)
        async let colorAnalysis = analyzeColorPreferences(period)
        async let trendAdoption = analyzeTrendAdoption(period)
        async let wardrobeUtilization = analyzeWardrobeUtilization(period)
        async let sustainabilityMetrics = calculateSustainabilityMetrics(period)
        async let recommendations = generatePersonalizedRecommendations()

        let report = FashionReport(
            period: period,
            styleProfile: try await styleAnalysis,
            wearingInsights: try await wearingPatterns,
            colorInsights: try await colorAnalysis,
            trendInsights: try await trendAdoption,
            wardrobeEfficiency: try await wardrobeUtilization,
            sustainability: try await sustainabilityMetrics,
            actionableRecommendations: try await recommendations,
            confidenceScore: confidence,
            generatedAt: Date()
        )

        return report
    }

    // MARK: - Style DNA Creation

    private func updateStyleDNA(with analysis: StyleAnalysis) async {
        guard var currentDNA = styleDNA else {
            styleDNA = await createInitialStyleDNA(from: analysis)
            return
        }

        // Evolve DNA based on new analysis
        currentDNA = await evolveStyleDNA(current: currentDNA, newData: analysis)
        styleDNA = currentDNA

        // Persist to secure storage
        await saveStyleDNA(currentDNA)
    }

    private func createInitialStyleDNA(from analysis: StyleAnalysis) async -> StyleDNA {
        let dna = StyleDNA(
            id: UUID(),
            primaryStyles: extractPrimaryStyles(from: analysis),
            colorProfile: analysis.colorProfile,
            bodyType: analysis.bodyTypeProfile,
            lifestyle: extractLifestyle(from: analysis),
            preferences: extractPreferences(from: analysis),
            confidenceFactors: analysis.confidenceFactors,
            createdAt: Date(),
            lastUpdated: Date()
        )

        return dna
    }

    private func evolveStyleDNA(current: StyleDNA, newData: StyleAnalysis) async -> StyleDNA {
        // Machine learning approach to DNA evolution
        var evolved = current
        evolved.lastUpdated = Date()

        // Update preferences based on new data with weighted averaging
        evolved.preferences = blendPreferences(
            current: current.preferences,
            new: extractPreferences(from: newData),
            weight: 0.1 // 10% influence from new data
        )

        // Update color profile
        evolved.colorProfile = blendColorProfiles(
            current: current.colorProfile,
            new: newData.colorProfile,
            weight: 0.15
        )

        // Update confidence factors
        evolved.confidenceFactors = updateConfidenceFactors(
            current: current.confidenceFactors,
            new: newData.confidenceFactors
        )

        return evolved
    }
}

// MARK: - AI Providers

class OpenAIProvider {
    private var apiKey: String?
    private let session = URLSession.shared

    func initialize() async {
        // Securely load API key from Keychain
        apiKey = await KeychainManager.shared.getAPIKey(for: "openai")
    }

    func analyzeStyle(_ prompt: String) async throws -> AIStyleResponse {
        guard let apiKey = apiKey else {
            throw AIError.noAPIKey
        }

        let request = OpenAIRequest(
            model: "gpt-4-vision-preview",
            messages: [
                OpenAIMessage(
                    role: "system",
                    content: "You are a world-class fashion AI assistant with expertise in style analysis, trend prediction, and personal shopping."
                ),
                OpenAIMessage(
                    role: "user",
                    content: prompt
                )
            ],
            maxTokens: 1000,
            temperature: 0.7
        )

        // Make API call
        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await session.data(for: urlRequest)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        return AIStyleResponse(
            provider: .openAI,
            content: response.choices.first?.message.content ?? "",
            confidence: 0.85,
            usage: response.usage
        )
    }

    func analyzeGaps(prompt: String) async throws -> GapAnalysisResult {
        let response = try await analyzeStyle(prompt)
        return try parseGapAnalysis(response.content)
    }

    private func parseGapAnalysis(_ content: String) throws -> GapAnalysisResult {
        // Parse structured response
        // Implementation would parse JSON or structured text response
        return GapAnalysisResult(
            categories: [],
            colors: [],
            styles: [],
            seasonal: []
        )
    }
}

class ClaudeProvider {
    private var apiKey: String?
    private let session = URLSession.shared

    func initialize() async {
        apiKey = await KeychainManager.shared.getAPIKey(for: "claude")
    }

    func analyzeStyle(_ prompt: String) async throws -> AIStyleResponse {
        guard let apiKey = apiKey else {
            throw AIError.noAPIKey
        }

        let request = ClaudeRequest(
            model: "claude-3-sonnet-20240229",
            maxTokens: 1000,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: prompt
                )
            ]
        )

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await session.data(for: urlRequest)
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        return AIStyleResponse(
            provider: .claude,
            content: response.content.first?.text ?? "",
            confidence: 0.90,
            usage: response.usage
        )
    }

    func analyzeGaps(prompt: String) async throws -> GapAnalysisResult {
        let response = try await analyzeStyle(prompt)
        return try parseGapAnalysis(response.content)
    }

    private func parseGapAnalysis(_ content: String) throws -> GapAnalysisResult {
        return GapAnalysisResult(
            categories: [],
            colors: [],
            styles: [],
            seasonal: []
        )
    }
}

// MARK: - Core ML Style Analyzer

class CoreMLStyleAnalyzer {
    private var styleClassifier: MLModel?
    private var fabricDetector: MLModel?
    private var brandRecognizer: MLModel?
    private var qualityAssessor: MLModel?

    func loadModels() async {
        do {
            // Load custom trained Core ML models
            styleClassifier = try await loadModel(named: "StyleClassifier")
            fabricDetector = try await loadModel(named: "FabricDetector")
            brandRecognizer = try await loadModel(named: "BrandRecognizer")
            qualityAssessor = try await loadModel(named: "QualityAssessor")
        } catch {
            print("Failed to load Core ML models: \(error)")
        }
    }

    private func loadModel(named name: String) async throws -> MLModel {
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            throw CoreMLError.modelNotFound(name)
        }
        return try MLModel(contentsOf: modelURL)
    }

    func analyze(_ image: UIImage) async throws -> CoreMLStyleResult {
        guard let styleClassifier = styleClassifier else {
            throw CoreMLError.modelNotLoaded
        }

        // Prepare image for model
        let processedImage = await preprocessImage(image)

        // Run inference
        async let styleResults = classifyStyle(processedImage, using: styleClassifier)
        async let fabricResults = detectFabric(processedImage)
        async let brandResults = recognizeBrand(processedImage)
        async let qualityResults = assessQuality(processedImage)

        return CoreMLStyleResult(
            styleClassification: try await styleResults,
            fabricInfo: try await fabricResults,
            brandInfo: try await brandResults,
            qualityScore: try await qualityResults,
            confidence: 0.95
        )
    }

    func quickAnalyze(_ image: UIImage) async throws -> QuickAnalysisResult {
        // Lightweight analysis for real-time use
        let processedImage = await preprocessImageForQuickAnalysis(image)

        guard let styleClassifier = styleClassifier else {
            throw CoreMLError.modelNotLoaded
        }

        let results = try await classifyStyle(processedImage, using: styleClassifier)

        return QuickAnalysisResult(
            primaryStyle: results.primaryStyle,
            confidence: results.confidence * 0.8,
            colors: await extractDominantColors(image),
            timestamp: Date()
        )
    }

    private func preprocessImage(_ image: UIImage) async -> MLMultiArray {
        // Implement image preprocessing for Core ML models
        // Resize, normalize, convert to MLMultiArray
        return MLMultiArray()
    }

    private func preprocessImageForQuickAnalysis(_ image: UIImage) async -> MLMultiArray {
        // Faster preprocessing for real-time use
        return MLMultiArray()
    }

    private func classifyStyle(_ input: MLMultiArray, using model: MLModel) async throws -> StyleClassificationResult {
        // Run style classification
        return StyleClassificationResult(
            primaryStyle: .casual,
            confidence: 0.85,
            alternativeStyles: []
        )
    }

    private func detectFabric(_ input: MLMultiArray) async throws -> FabricInfo {
        guard let fabricDetector = fabricDetector else {
            throw CoreMLError.modelNotLoaded
        }

        // Implement fabric detection
        return FabricInfo(
            type: .cotton,
            confidence: 0.90,
            texture: .smooth,
            quality: .high
        )
    }

    private func recognizeBrand(_ input: MLMultiArray) async throws -> BrandInfo {
        guard let brandRecognizer = brandRecognizer else {
            throw CoreMLError.modelNotLoaded
        }

        // Implement brand recognition
        return BrandInfo(
            name: "Unknown",
            confidence: 0.0,
            logoDetected: false
        )
    }

    private func assessQuality(_ input: MLMultiArray) async throws -> Double {
        guard let qualityAssessor = qualityAssessor else {
            throw CoreMLError.modelNotLoaded
        }

        // Implement quality assessment
        return 0.75
    }

    private func extractDominantColors(_ image: UIImage) async -> [Color] {
        // Extract dominant colors using Vision framework
        return [.blue, .white, .gray]
    }
}

// MARK: - Vision Analyzer

class VisionAnalyzer {
    func detectObjects(in image: UIImage) async throws -> [DetectedObject] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let objects = request.results?.compactMap { result in
                    guard let observation = result as? VNRectangleObservation else { return nil }
                    return DetectedObject(
                        boundingBox: observation.boundingBox,
                        confidence: observation.confidence,
                        type: .clothing
                    )
                } ?? []

                continuation.resume(returning: objects)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - Trend Predictor

class TrendPredictor {
    func analyzeTrends(for period: TimePeriod) async -> TrendAnalysis {
        // Analyze fashion trends using historical data and AI
        return TrendAnalysis(
            emergingTrends: [],
            decliningTrends: [],
            seasonalTrends: [],
            personalizedTrends: [],
            confidence: 0.80
        )
    }

    func predictNextSeasonTrends() async -> [Trend] {
        // Predict upcoming trends
        return []
    }
}

// MARK: - Quality Assessment

class QualityAssessment {
    func assess(_ image: UIImage) async throws -> Double {
        // Assess garment quality from image
        // Look for fabric texture, construction details, etc.
        return 0.75
    }
}

// MARK: - Personal Shopper AI

@MainActor
class PersonalShopperAI: ObservableObject {
    @Published var recommendations: [ShoppingRecommendation] = []
    @Published var budget: Budget?
    @Published var preferences: ShoppingPreferences = ShoppingPreferences()

    func generateRecommendations(based: WardrobeGapAnalysis) async -> [ShoppingRecommendation] {
        // AI-powered shopping recommendations
        return []
    }

    func findDeals(for items: [String]) async -> [Deal] {
        // Find deals and discounts
        return []
    }

    func trackPrices(for items: [String]) async -> [PriceAlert] {
        // Price tracking and alerts
        return []
    }
}

// MARK: - Keychain Manager

class KeychainManager {
    static let shared = KeychainManager()

    func getAPIKey(for service: String) async -> String? {
        // Retrieve API keys securely from Keychain
        return nil
    }

    func setAPIKey(_ key: String, for service: String) async -> Bool {
        // Store API keys securely in Keychain
        return false
    }
}

// MARK: - Data Models

struct StyleAnalysis {
    let coreMLResults: CoreMLStyleResult
    let visionObjects: [DetectedObject]
    let fabricInfo: FabricInfo
    let brandInfo: BrandInfo
    let qualityScore: Double
    let fitAnalysis: FitAnalysis
    let colorSeason: ColorSeason
    let confidence: Double
    let timestamp: Date

    var colorProfile: ColorProfile {
        ColorProfile(
            dominantColors: coreMLResults.dominantColors,
            season: colorSeason,
            temperature: colorSeason.temperature
        )
    }

    var bodyTypeProfile: BodyTypeProfile? {
        fitAnalysis.bodyTypeProfile
    }

    var confidenceFactors: [String: Double] {
        [
            "coreML": coreMLResults.confidence,
            "vision": visionObjects.map { $0.confidence }.average(),
            "fabric": fabricInfo.confidence,
            "quality": qualityScore,
            "fit": fitAnalysis.confidence
        ]
    }

    static func fallback(error: Error) -> StyleAnalysis {
        StyleAnalysis(
            coreMLResults: CoreMLStyleResult.fallback,
            visionObjects: [],
            fabricInfo: FabricInfo.unknown,
            brandInfo: BrandInfo.unknown,
            qualityScore: 0.0,
            fitAnalysis: FitAnalysis.unknown,
            colorSeason: .unknown,
            confidence: 0.0,
            timestamp: Date()
        )
    }
}

struct CoreMLStyleResult {
    let styleClassification: StyleClassificationResult
    let fabricInfo: FabricInfo
    let brandInfo: BrandInfo
    let qualityScore: Double
    let confidence: Double
    let dominantColors: [Color]

    static let fallback = CoreMLStyleResult(
        styleClassification: StyleClassificationResult(primaryStyle: .unknown, confidence: 0.0, alternativeStyles: []),
        fabricInfo: FabricInfo.unknown,
        brandInfo: BrandInfo.unknown,
        qualityScore: 0.0,
        confidence: 0.0,
        dominantColors: []
    )
}

struct StyleClassificationResult {
    let primaryStyle: StyleType
    let confidence: Double
    let alternativeStyles: [(StyleType, Double)]
}

struct FabricInfo {
    let type: FabricType
    let confidence: Double
    let texture: FabricTexture
    let quality: FabricQuality

    static let unknown = FabricInfo(type: .unknown, confidence: 0.0, texture: .unknown, quality: .unknown)
}

struct BrandInfo {
    let name: String
    let confidence: Double
    let logoDetected: Bool

    static let unknown = BrandInfo(name: "Unknown", confidence: 0.0, logoDetected: false)
}

struct FitAnalysis {
    let bodyTypeProfile: BodyTypeProfile?
    let fitQuality: FitQuality
    let recommendations: [FitRecommendation]
    let confidence: Double

    static let unknown = FitAnalysis(bodyTypeProfile: nil, fitQuality: .unknown, recommendations: [], confidence: 0.0)
}

struct DetectedObject {
    let boundingBox: CGRect
    let confidence: Float
    let type: ObjectType
}

struct OutfitScore {
    let overall: Double
    let breakdown: OutfitScoreBreakdown
    let suggestions: [OutfitSuggestion]
    let confidence: Double
}

struct OutfitScoreBreakdown {
    let styleHarmony: Double
    let colorCoordination: Double
    let occasionFit: Double
    let trendAlignment: Double
    let personalFit: Double
}

struct OutfitSuggestion {
    let type: SuggestionType
    let description: String
    let impact: ImpactLevel
    let alternatives: [StyleItem]
}

struct LiveSuggestions {
    let analysis: QuickAnalysisResult
    let colorProfile: ColorProfile
    let styleElements: [StyleElement]
    let recommendations: [LiveRecommendation]
    let confidence: Double
}

struct QuickAnalysisResult {
    let primaryStyle: StyleType
    let confidence: Double
    let colors: [Color]
    let timestamp: Date
}

struct LiveRecommendation {
    let type: RecommendationType
    let message: String
    let priority: Priority
    let actionable: Bool
}

struct WardrobeGapAnalysis {
    let missingCategories: [ClothingCategory]
    let colorGaps: [Color]
    let styleGaps: [StyleType]
    let seasonalGaps: [Season: [ClothingCategory]]
    let recommendations: [GapRecommendation]
    let priorityScore: Double
    let budget: BudgetEstimate
}

struct StyleEvolution {
    let timeframe: TimePeriod
    let styleProgression: StyleProgression
    let preferenceChanges: PreferenceChanges
    let trendInfluence: TrendInfluence
    let personalGrowth: PersonalGrowthMetrics
    let futureProjections: StyleProjections
}

struct FashionReport {
    let period: TimePeriod
    let styleProfile: PersonalStyleProfile
    let wearingInsights: WearingPatterns
    let colorInsights: ColorInsights
    let trendInsights: TrendAdoption
    let wardrobeEfficiency: WardrobeUtilization
    let sustainability: SustainabilityMetrics
    let actionableRecommendations: [ActionableRecommendation]
    let confidenceScore: Double
    let generatedAt: Date
}

struct StyleDNA {
    let id: UUID
    var primaryStyles: [StyleType]
    var colorProfile: ColorProfile
    var bodyType: BodyTypeProfile?
    var lifestyle: LifestyleProfile
    var preferences: StylePreferences
    var confidenceFactors: [String: Double]
    let createdAt: Date
    var lastUpdated: Date
}

struct AIStyleResponse {
    let provider: AIProvider
    let content: String
    let confidence: Double
    let usage: APIUsage?
}

struct GapAnalysisResult {
    let categories: [ClothingCategory]
    let colors: [Color]
    let styles: [StyleType]
    let seasonal: [Season: [ClothingCategory]]
}

// MARK: - Enums

enum AIProvider {
    case openAI
    case claude
    case coreML
}

enum StyleType {
    case casual, formal, business, creative, bohemian, minimalist, classic, trendy, athletic, unknown
}

enum FabricType {
    case cotton, wool, silk, polyester, linen, denim, leather, synthetic, unknown
}

enum FabricTexture {
    case smooth, rough, textured, ribbed, woven, knitted, unknown
}

enum FabricQuality {
    case high, medium, low, unknown
}

enum ColorSeason {
    case spring, summer, autumn, winter, unknown

    var temperature: ColorTemperature {
        switch self {
        case .spring, .autumn: return .warm
        case .summer, .winter: return .cool
        case .unknown: return .neutral
        }
    }
}

enum ColorTemperature {
    case warm, cool, neutral
}

enum FitQuality {
    case excellent, good, fair, poor, unknown
}

enum ObjectType {
    case clothing, accessory, shoe, bag
}

enum AnalysisContext {
    case general, shopping, outfit, realTime
}

enum Occasion {
    case casual, work, formal, date, party, travel
}

enum TimePeriod {
    case weekly, monthly, quarterly, yearly

    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        case .yearly: return 365
        }
    }
}

enum ClothingCategory {
    case tops, bottoms, dresses, outerwear, shoes, accessories
}

enum Season {
    case spring, summer, fall, winter
}

enum SuggestionType {
    case replacement, addition, styling, color
}

enum ImpactLevel {
    case high, medium, low
}

enum RecommendationType {
    case styling, fit, color, trend
}

enum Priority {
    case high, medium, low
}

// MARK: - Supporting Types

struct ColorProfile {
    let dominantColors: [Color]
    let season: ColorSeason
    let temperature: ColorTemperature
}

struct BodyTypeProfile {
    let type: BodyType
    let measurements: BodyMeasurements?
    let confidence: Double
}

struct BodyType {
    // Implemented with sensitivity and body positivity
    let silhouette: String
    let recommendations: [String]
}

struct BodyMeasurements {
    // Optional measurements for fit analysis
    let shoulderWidth: Double?
    let chestWidth: Double?
    let waistWidth: Double?
    let hipWidth: Double?
}

struct StyleElement {
    let name: String
    let confidence: Double
    let category: ElementCategory
}

struct ColorInsights {
    let favoriteColors: [Color]
    let colorEvolution: [Date: [Color]]
    let seasonalPreferences: [Season: [Color]]
}

struct PersonalStyleProfile {
    let dominantStyles: [StyleType]
    let evolution: StyleProgression
    let confidence: Double
}

struct WearingPatterns {
    let frequency: [ClothingCategory: Int]
    let seasonal: [Season: [ClothingCategory]]
    let weekly: [Weekday: StyleType]
}

struct TrendAdoption {
    let adoptedTrends: [Trend]
    let trendingScore: Double
    let earliness: AdoptionTiming
}

struct WardrobeUtilization {
    let utilizationRate: Double
    let underusedItems: [StyleItem]
    let favoriteItems: [StyleItem]
    let costPerWear: [StyleItem: Double]
}

struct SustainabilityMetrics {
    let sustainabilityScore: Double
    let carbonFootprint: CarbonFootprint
    let recommendations: [SustainabilityRecommendation]
}

struct ActionableRecommendation {
    let title: String
    let description: String
    let priority: Priority
    let category: RecommendationCategory
    let estimatedImpact: ImpactLevel
}

struct StyleProgression {
    let timeline: [Date: StyleType]
    let evolution: EvolutionDirection
}

struct PreferenceChanges {
    let colorShifts: [Color: Double]
    let styleShifts: [StyleType: Double]
    let categoryShifts: [ClothingCategory: Double]
}

struct TrendInfluence {
    let influenceScore: Double
    let adoptedTrends: [Trend]
    let trendSources: [TrendSource]
}

struct PersonalGrowthMetrics {
    let confidenceGrowth: Double
    let experimentationScore: Double
    let styleMaturityIndex: Double
}

struct StyleProjections {
    let nextSeasonPrediction: [StyleType]
    let longTermEvolution: StyleEvolution
    let recommendedDirection: StyleDirection
}

struct LifestyleProfile {
    let workStyle: WorkStyle
    let socialActivities: [SocialActivity]
    let travelFrequency: TravelFrequency
    let interests: [Interest]
}

struct StylePreferences {
    let colors: [Color]
    let styles: [StyleType]
    let brands: [String]
    let priceRange: PriceRange
    let sustainability: SustainabilityLevel
}

struct ShoppingRecommendation {
    let item: RecommendedItem
    let reason: String
    let priority: Priority
    let estimatedCost: Double
    let alternatives: [RecommendedItem]
}

struct Deal {
    let item: String
    let originalPrice: Double
    let salePrice: Double
    let discount: Double
    let validUntil: Date
}

struct PriceAlert {
    let item: String
    let targetPrice: Double
    let currentPrice: Double
    let priceHistory: [PricePoint]
}

struct Budget {
    let total: Double
    let categories: [ClothingCategory: Double]
    let timeframe: TimePeriod
}

struct ShoppingPreferences {
    let maxPrice: Double
    let preferredBrands: [String]
    let sustainabilityLevel: SustainabilityLevel
    let sizePreferences: SizePreferences
}

// MARK: - API Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: APIUsage
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
    let usage: APIUsage
}

struct ClaudeContent: Codable {
    let text: String
    let type: String
}

struct APIUsage: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Errors

enum AIError: Error {
    case noAPIKey
    case invalidResponse
    case networkError
    case rateLimited
}

enum CoreMLError: Error {
    case modelNotFound(String)
    case modelNotLoaded
    case inferenceError
}

enum VisionError: Error {
    case invalidImage
    case analysisError
}

// MARK: - Extensions

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }
}

extension Array where Element == Float {
    func average() -> Float {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Float(count)
    }
}

// MARK: - Additional Supporting Types

struct Trend {
    let name: String
    let description: String
    let season: Season
    let confidence: Double
    let adoptionRate: Double
}

struct TrendAnalysis {
    let emergingTrends: [Trend]
    let decliningTrends: [Trend]
    let seasonalTrends: [Season: [Trend]]
    let personalizedTrends: [Trend]
    let confidence: Double
}

struct TrendSource {
    let name: String
    let influence: Double
    let credibility: Double
}

struct FitRecommendation {
    let issue: String
    let solution: String
    let impact: ImpactLevel
}

struct GapRecommendation {
    let category: ClothingCategory
    let priority: Priority
    let estimatedCost: Double
    let reasoning: String
}

struct BudgetEstimate {
    let total: Double
    let breakdown: [ClothingCategory: Double]
    let timeframe: TimePeriod
}

struct CarbonFootprint {
    let totalKgCO2: Double
    let perItem: Double
    let comparison: String
}

struct SustainabilityRecommendation {
    let action: String
    let impact: Double
    let difficulty: DifficultyLevel
}

struct RecommendedItem {
    let name: String
    let category: ClothingCategory
    let estimatedPrice: Double
    let alternatives: [String]
}

struct PricePoint {
    let date: Date
    let price: Double
}

struct SizePreferences {
    let sizes: [ClothingCategory: String]
    let fit: FitPreference
}

// MARK: - Additional Enums

enum ElementCategory {
    case color, pattern, texture, silhouette
}

enum Weekday {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

enum AdoptionTiming {
    case early, mainstream, late
}

enum RecommendationCategory {
    case styling, shopping, organization, sustainability
}

enum EvolutionDirection {
    case evolving, stable, regressing
}

enum WorkStyle {
    case corporate, creative, casual, remote
}

enum SocialActivity {
    case dining, events, travel, sports, entertainment
}

enum TravelFrequency {
    case frequent, occasional, rare, none
}

enum Interest {
    case fashion, art, technology, fitness, music
}

enum PriceRange {
    case budget, mid, luxury, mixed
}

enum SustainabilityLevel {
    case high, medium, low, notImportant
}

enum StyleDirection {
    case classic, trendy, experimental, minimalist
}

enum DifficultyLevel {
    case easy, medium, hard
}

enum FitPreference {
    case tight, fitted, regular, loose, oversized
}

#Preview {
    ContentView()
}