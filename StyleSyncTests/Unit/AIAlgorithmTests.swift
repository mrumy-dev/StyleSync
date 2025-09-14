import XCTest
@testable import StyleSync

final class AIAlgorithmTests: XCTestCase {

    var aiStyleEngine: AIStyleEngine!
    var sampleOutfitData: [OutfitItem]!

    override func setUp() {
        super.setUp()
        aiStyleEngine = AIStyleEngine()
        sampleOutfitData = [
            OutfitItem(id: "1", type: .top, color: .blue, brand: "TestBrand", fit: .regular),
            OutfitItem(id: "2", type: .bottom, color: .navy, brand: "TestBrand", fit: .slim),
            OutfitItem(id: "3", type: .shoes, color: .brown, brand: "TestBrand", fit: .regular)
        ]
    }

    override func tearDown() {
        aiStyleEngine = nil
        sampleOutfitData = nil
        super.tearDown()
    }

    // MARK: - Style Recommendation Tests

    func testGenerateOutfitRecommendations() {
        // Given
        let userPreferences = UserStylePreferences(
            preferredColors: [.blue, .navy, .white],
            styleType: .professional,
            occasionTypes: [.work, .business]
        )
        let weatherConditions = WeatherConditions(
            temperature: 72,
            humidity: 60,
            windSpeed: 5,
            condition: .partlyCloudy
        )

        // When
        let recommendations = aiStyleEngine.generateRecommendations(
            userPreferences: userPreferences,
            weatherConditions: weatherConditions,
            availableItems: sampleOutfitData
        )

        // Then
        XCTAssertNotNil(recommendations)
        XCTAssertGreaterThan(recommendations.count, 0)
        XCTAssertLessThanOrEqual(recommendations.count, 10)

        // Verify all recommendations have required components
        for recommendation in recommendations {
            XCTAssertNotNil(recommendation.topItem)
            XCTAssertNotNil(recommendation.bottomItem)
            XCTAssertGreaterThan(recommendation.confidenceScore, 0.0)
            XCTAssertLessThanOrEqual(recommendation.confidenceScore, 1.0)
        }
    }

    func testColorHarmonyAlgorithm() {
        // Given
        let colors: [StyleColor] = [.blue, .navy, .white]

        // When
        let harmonyScore = aiStyleEngine.calculateColorHarmony(colors: colors)

        // Then
        XCTAssertGreaterThanOrEqual(harmonyScore, 0.0)
        XCTAssertLessThanOrEqual(harmonyScore, 1.0)
        XCTAssertGreaterThan(harmonyScore, 0.7) // Blue, navy, white should have high harmony
    }

    func testSeasonalFitness() {
        // Given
        let outfit = OutfitRecommendation(
            topItem: sampleOutfitData[0],
            bottomItem: sampleOutfitData[1],
            shoesItem: sampleOutfitData[2]
        )
        let season = Season.winter

        // When
        let fitnessScore = aiStyleEngine.calculateSeasonalFitness(outfit: outfit, season: season)

        // Then
        XCTAssertGreaterThanOrEqual(fitnessScore, 0.0)
        XCTAssertLessThanOrEqual(fitnessScore, 1.0)
    }

    func testStyleConsistencyCheck() {
        // Given
        let mixedStyleOutfit = OutfitRecommendation(
            topItem: OutfitItem(id: "formal", type: .top, color: .black, brand: "Formal", fit: .regular),
            bottomItem: OutfitItem(id: "casual", type: .bottom, color: .blue, brand: "Casual", fit: .relaxed),
            shoesItem: OutfitItem(id: "athletic", type: .shoes, color: .white, brand: "Athletic", fit: .regular)
        )

        // When
        let consistencyScore = aiStyleEngine.calculateStyleConsistency(outfit: mixedStyleOutfit)

        // Then
        XCTAssertGreaterThanOrEqual(consistencyScore, 0.0)
        XCTAssertLessThanOrEqual(consistencyScore, 1.0)
        XCTAssertLessThan(consistencyScore, 0.5) // Mixed styles should have low consistency
    }

    // MARK: - Machine Learning Model Tests

    func testOutfitRatingPrediction() {
        // Given
        let outfit = OutfitRecommendation(
            topItem: sampleOutfitData[0],
            bottomItem: sampleOutfitData[1],
            shoesItem: sampleOutfitData[2]
        )
        let userHistory = UserRatingHistory(
            averageRating: 4.2,
            preferredStyles: [.professional, .casual],
            dislikedCombinations: []
        )

        // When
        let predictedRating = aiStyleEngine.predictOutfitRating(
            outfit: outfit,
            userHistory: userHistory
        )

        // Then
        XCTAssertGreaterThanOrEqual(predictedRating, 1.0)
        XCTAssertLessThanOrEqual(predictedRating, 5.0)
    }

    func testPersonalizationEngine() {
        // Given
        let userInteractions = [
            UserInteraction(outfitId: "1", rating: 5, timestamp: Date()),
            UserInteraction(outfitId: "2", rating: 3, timestamp: Date()),
            UserInteraction(outfitId: "3", rating: 4, timestamp: Date())
        ]

        // When
        let personalizedPreferences = aiStyleEngine.updatePersonalization(
            currentPreferences: UserStylePreferences.default,
            interactions: userInteractions
        )

        // Then
        XCTAssertNotNil(personalizedPreferences)
        XCTAssertNotEqual(personalizedPreferences, UserStylePreferences.default)
    }

    // MARK: - Edge Cases and Error Handling

    func testEmptyWardrobe() {
        // Given
        let emptyWardrobe: [OutfitItem] = []
        let userPreferences = UserStylePreferences.default

        // When
        let recommendations = aiStyleEngine.generateRecommendations(
            userPreferences: userPreferences,
            weatherConditions: WeatherConditions.default,
            availableItems: emptyWardrobe
        )

        // Then
        XCTAssertTrue(recommendations.isEmpty)
    }

    func testInvalidColorCombination() {
        // Given
        let invalidColors: [StyleColor] = []

        // When
        let harmonyScore = aiStyleEngine.calculateColorHarmony(colors: invalidColors)

        // Then
        XCTAssertEqual(harmonyScore, 0.0)
    }

    func testPerformanceWithLargeWardrobe() {
        // Given
        let largeWardrobe = generateLargeWardrobe(itemCount: 1000)
        let userPreferences = UserStylePreferences.default

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let recommendations = aiStyleEngine.generateRecommendations(
            userPreferences: userPreferences,
            weatherConditions: WeatherConditions.default,
            availableItems: largeWardrobe
        )
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Then
        XCTAssertNotNil(recommendations)
        XCTAssertLessThan(timeElapsed, 2.0) // Should complete within 2 seconds
    }

    // MARK: - Helper Methods

    private func generateLargeWardrobe(itemCount: Int) -> [OutfitItem] {
        return (0..<itemCount).map { index in
            OutfitItem(
                id: "item_\(index)",
                type: OutfitItemType.allCases.randomElement()!,
                color: StyleColor.allCases.randomElement()!,
                brand: "TestBrand",
                fit: FitType.allCases.randomElement()!
            )
        }
    }
}

// MARK: - Test Data Models

extension OutfitItem {
    init(id: String, type: OutfitItemType, color: StyleColor, brand: String, fit: FitType) {
        self.id = id
        self.type = type
        self.color = color
        self.brand = brand
        self.fit = fit
        self.size = "M"
        self.price = 50.0
        self.imageURL = nil
        self.tags = []
        self.seasonality = [.spring, .fall]
    }
}

extension UserStylePreferences {
    static let `default` = UserStylePreferences(
        preferredColors: [.blue, .white, .black],
        styleType: .casual,
        occasionTypes: [.everyday, .work]
    )
}

extension WeatherConditions {
    static let `default` = WeatherConditions(
        temperature: 70,
        humidity: 50,
        windSpeed: 3,
        condition: .sunny
    )
}

enum OutfitItemType: CaseIterable {
    case top, bottom, shoes, accessory, outerwear
}

enum StyleColor: CaseIterable {
    case black, white, navy, blue, gray, brown, red, green, yellow, pink
}

enum FitType: CaseIterable {
    case regular, slim, relaxed, oversized
}

enum Season: CaseIterable {
    case spring, summer, fall, winter
}

enum StyleType {
    case casual, professional, formal, athletic, bohemian
}

struct UserStylePreferences: Equatable {
    let preferredColors: [StyleColor]
    let styleType: StyleType
    let occasionTypes: [OccasionType]
}

enum OccasionType {
    case everyday, work, business, date, party, travel
}

struct WeatherConditions {
    let temperature: Double
    let humidity: Int
    let windSpeed: Double
    let condition: WeatherCondition
}

enum WeatherCondition {
    case sunny, cloudy, partlyCloudy, rainy, snowy, windy
}

struct OutfitRecommendation {
    let topItem: OutfitItem
    let bottomItem: OutfitItem
    let shoesItem: OutfitItem
    let accessoryItem: OutfitItem?
    let outerwearItem: OutfitItem?
    let confidenceScore: Double

    init(topItem: OutfitItem, bottomItem: OutfitItem, shoesItem: OutfitItem, accessoryItem: OutfitItem? = nil, outerwearItem: OutfitItem? = nil, confidenceScore: Double = 0.8) {
        self.topItem = topItem
        self.bottomItem = bottomItem
        self.shoesItem = shoesItem
        self.accessoryItem = accessoryItem
        self.outerwearItem = outerwearItem
        self.confidenceScore = confidenceScore
    }
}

struct UserRatingHistory {
    let averageRating: Double
    let preferredStyles: [StyleType]
    let dislikedCombinations: [String]
}

struct UserInteraction {
    let outfitId: String
    let rating: Int
    let timestamp: Date
}