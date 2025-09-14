import SwiftUI
import Foundation
import CoreLocation

class RegionalCustomization: ObservableObject {
    static let shared = RegionalCustomization()

    @Published var currentRegion: SwissRegion = .zurich
    @Published var fashionTrends: [SwissTrend] = []
    @Published var weatherSources: [WeatherSource] = []
    @Published var localBrands: [SwissBrand] = []
    @Published var culturalPreferences: CulturalPreferences?

    private init() {
        setupRegionalData()
    }

    private func setupRegionalData() {
        updateFashionTrends()
        updateWeatherSources()
        updateLocalBrands()
        updateCulturalPreferences()
    }

    func setRegion(_ region: SwissRegion) {
        currentRegion = region
        UserDefaults.standard.set(region.rawValue, forKey: "current_swiss_region")
        setupRegionalData()
    }

    private func updateFashionTrends() {
        let currentSeason = getCurrentSeason()
        var trends = SwissMarketFeatures.shared.getSwissFashionTrends(for: currentSeason)

        // Add region-specific trends
        switch currentRegion {
        case .zurich:
            trends.append(contentsOf: getZurichSpecificTrends())
        case .geneva:
            trends.append(contentsOf: getGenevaSpecificTrends())
        case .basel:
            trends.append(contentsOf: getBaselSpecificTrends())
        case .bern:
            trends.append(contentsOf: getBernSpecificTrends())
        case .alps:
            trends.append(contentsOf: getAlpineSpecificTrends())
        }

        fashionTrends = trends
    }

    private func updateWeatherSources() {
        weatherSources = SwissMarketFeatures.shared.getSwissWeatherSources()
    }

    private func updateLocalBrands() {
        localBrands = SwissMarketFeatures.shared.getSwissBrands()
            .filter { brand in
                // Filter brands based on regional availability
                switch currentRegion {
                case .zurich, .geneva:
                    return true // All brands available in major cities
                case .basel, .bern:
                    return brand.priceRange != .luxury // Exclude some luxury brands
                case .alps:
                    return brand.category.contains("Outdoor") || brand.sustainability == .high
                }
            }
    }

    private func updateCulturalPreferences() {
        culturalPreferences = getCulturalPreferences(for: currentRegion)
    }

    // MARK: - Regional Fashion Trends

    private func getZurichSpecificTrends() -> [SwissTrend] {
        return [
            SwissTrend(
                name: "Banking District Chic",
                description: "Sophisticated financial sector style",
                keywords: ["navy", "charcoal", "pinstripe", "luxury"],
                popularBrands: ["Hugo Boss", "Armani", "Zegna"]
            ),
            SwissTrend(
                name: "Tech Hub Casual",
                description: "Modern tech industry aesthetic",
                keywords: ["minimalist", "comfortable", "quality", "sustainable"],
                popularBrands: ["COS", "Uniqlo", "Patagonia"]
            ),
            SwissTrend(
                name: "Lake Zurich Elegance",
                description: "Waterfront lifestyle fashion",
                keywords: ["nautical", "preppy", "refined", "seasonal"],
                popularBrands: ["Polo Ralph Lauren", "Lacoste", "Barbour"]
            )
        ]
    }

    private func getGenevaSpecificTrends() -> [SwissTrend] {
        return [
            SwissTrend(
                name: "International Diplomacy",
                description: "Sophisticated international style",
                keywords: ["elegant", "formal", "multicultural", "luxurious"],
                popularBrands: ["Hermès", "Chanel", "Dior"]
            ),
            SwissTrend(
                name: "French-Swiss Fusion",
                description: "Blend of French flair and Swiss precision",
                keywords: ["chic", "artistic", "refined", "cultured"],
                popularBrands: ["Sandro", "Maje", "Isabel Marant"]
            ),
            SwissTrend(
                name: "Watch Industry Heritage",
                description: "Precision and luxury aesthetic",
                keywords: ["timeless", "craftsmanship", "premium", "traditional"],
                popularBrands: ["Breitling", "Tag Heuer", "Omega"]
            )
        ]
    }

    private func getBaselSpecificTrends() -> [SwissTrend] {
        return [
            SwissTrend(
                name: "Art Basel Contemporary",
                description: "Modern art scene influence",
                keywords: ["avant-garde", "artistic", "bold", "experimental"],
                popularBrands: ["Acne Studios", "Ganni", "Stine Goya"]
            ),
            SwissTrend(
                name: "Pharmaceutical Professional",
                description: "Clean, professional industry style",
                keywords: ["clean", "professional", "reliable", "modern"],
                popularBrands: ["Theory", "J.Crew", "Everlane"]
            )
        ]
    }

    private func getBernSpecificTrends() -> [SwissTrend] {
        return [
            SwissTrend(
                name: "Federal Capital Style",
                description: "Government and diplomatic fashion",
                keywords: ["conservative", "traditional", "quality", "reliable"],
                popularBrands: ["Brooks Brothers", "Paul Smith", "Brunello Cucinelli"]
            ),
            SwissTrend(
                name: "Old Town Charm",
                description: "Historic city center aesthetic",
                keywords: ["heritage", "artisanal", "timeless", "authentic"],
                popularBrands: ["Bally", "Akris", "Zimmerli"]
            )
        ]
    }

    private func getAlpineSpecificTrends() -> [SwissTrend] {
        return [
            SwissTrend(
                name: "Luxury Mountain Resort",
                description: "High-end alpine lifestyle",
                keywords: ["luxurious", "functional", "warm", "stylish"],
                popularBrands: ["Moncler", "Canada Goose", "Stone Island"]
            ),
            SwissTrend(
                name: "Sustainable Alpine",
                description: "Eco-conscious mountain living",
                keywords: ["sustainable", "organic", "local", "functional"],
                popularBrands: ["Patagonia", "Mammut", "Ortovox"]
            ),
            SwissTrend(
                name: "Apres-Ski Luxury",
                description: "Post-skiing social style",
                keywords: ["cozy", "luxurious", "social", "warming"],
                popularBrands: ["Bogner", "Fusalp", "Perfect Moment"]
            )
        ]
    }

    // MARK: - Weather Integration

    func getRegionalWeatherData() -> RegionalWeather? {
        guard let location = getRegionCoordinates(currentRegion) else { return nil }

        return RegionalWeather(
            region: currentRegion,
            coordinates: location,
            elevation: getRegionElevation(currentRegion),
            microclimate: getRegionMicroclimate(currentRegion),
            seasonalPatterns: getSeasonalPatterns(currentRegion)
        )
    }

    private func getRegionCoordinates(_ region: SwissRegion) -> CLLocationCoordinate2D? {
        switch region {
        case .zurich: return CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)
        case .geneva: return CLLocationCoordinate2D(latitude: 46.2044, longitude: 6.1432)
        case .basel: return CLLocationCoordinate2D(latitude: 47.5596, longitude: 7.5886)
        case .bern: return CLLocationCoordinate2D(latitude: 46.9480, longitude: 7.4474)
        case .alps: return CLLocationCoordinate2D(latitude: 46.5197, longitude: 9.7964)
        }
    }

    private func getRegionElevation(_ region: SwissRegion) -> Double {
        switch region {
        case .zurich: return 408
        case .geneva: return 372
        case .basel: return 260
        case .bern: return 542
        case .alps: return 1650 // Average alpine elevation
        }
    }

    private func getRegionMicroclimate(_ region: SwissRegion) -> Microclimate {
        switch region {
        case .zurich:
            return Microclimate(
                type: "Continental",
                characteristics: ["Moderate humidity", "Four distinct seasons", "Occasional föhn winds"],
                outfitConsiderations: ["Layer-friendly", "Weather-resistant outer layer", "Versatile pieces"]
            )
        case .geneva:
            return Microclimate(
                type: "Temperate Oceanic",
                characteristics: ["Lake influence", "Mild winters", "Variable spring weather"],
                outfitConsiderations: ["Lake breeze protection", "Transitional layering", "Elegant versatility"]
            )
        case .basel:
            return Microclimate(
                type: "Temperate Continental",
                characteristics: ["Rhine valley influence", "Moderate precipitation", "Urban heat island"],
                outfitConsiderations: ["Urban practicality", "Professional versatility", "Weather adaptability"]
            )
        case .bern:
            return Microclimate(
                type: "Continental Mountain",
                characteristics: ["Higher elevation", "Cooler temperatures", "Snow in winter"],
                outfitConsiderations: ["Warm layering", "Quality outerwear", "Winter-ready footwear"]
            )
        case .alps:
            return Microclimate(
                type: "Alpine",
                characteristics: ["High altitude", "Extreme weather changes", "Strong UV at elevation"],
                outfitConsiderations: ["Technical fabrics", "UV protection", "Layering system", "Weather resistance"]
            )
        }
    }

    private func getSeasonalPatterns(_ region: SwissRegion) -> SeasonalPatterns {
        let basePatterns = SeasonalPatterns(
            winter: SeasonInfo(
                averageTemp: getAverageTemp(region: region, season: .winter),
                precipitation: "High",
                keyFactors: ["Snow possible", "Cold winds", "Short days"],
                outfitRecommendations: ["Heavy coats", "Warm accessories", "Waterproof boots"]
            ),
            spring: SeasonInfo(
                averageTemp: getAverageTemp(region: region, season: .spring),
                precipitation: "Variable",
                keyFactors: ["Unpredictable weather", "Rain showers", "Temperature swings"],
                outfitRecommendations: ["Layering pieces", "Light jackets", "Waterproof options"]
            ),
            summer: SeasonInfo(
                averageTemp: getAverageTemp(region: region, season: .summer),
                precipitation: "Moderate",
                keyFactors: ["Occasional thunderstorms", "UV exposure at altitude", "Lake activities"],
                outfitRecommendations: ["Breathable fabrics", "Sun protection", "Comfortable footwear"]
            ),
            autumn: SeasonInfo(
                averageTemp: getAverageTemp(region: region, season: .autumn),
                precipitation: "Increasing",
                keyFactors: ["Cooling temperatures", "Colorful foliage", "Preparation for winter"],
                outfitRecommendations: ["Transitional layers", "Warm accessories", "Weather-resistant pieces"]
            )
        )

        return basePatterns
    }

    private func getAverageTemp(region: SwissRegion, season: Season) -> String {
        let baseTemps: [SwissRegion: [Season: String]] = [
            .zurich: [.winter: "2°C", .spring: "12°C", .summer: "20°C", .autumn: "10°C"],
            .geneva: [.winter: "3°C", .spring: "13°C", .summer: "21°C", .autumn: "11°C"],
            .basel: [.winter: "3°C", .spring: "13°C", .summer: "21°C", .autumn: "11°C"],
            .bern: [.winter: "0°C", .spring: "10°C", .summer: "18°C", .autumn: "8°C"],
            .alps: [.winter: "-5°C", .spring: "5°C", .summer: "15°C", .autumn: "3°C"]
        ]

        return baseTemps[region]?[season] ?? "10°C"
    }

    // MARK: - Size Charts

    func getRegionalSizeCharts() -> [SizeChart] {
        return [
            SizeChart(
                category: "Women's Clothing",
                region: "Switzerland",
                conversions: [
                    "32": ["US": "XS/2", "UK": "6", "FR": "34", "IT": "38"],
                    "34": ["US": "S/4", "UK": "8", "FR": "36", "IT": "40"],
                    "36": ["US": "M/6", "UK": "10", "FR": "38", "IT": "42"],
                    "38": ["US": "L/8", "UK": "12", "FR": "40", "IT": "44"],
                    "40": ["US": "XL/10", "UK": "14", "FR": "42", "IT": "46"]
                ]
            ),
            SizeChart(
                category: "Men's Clothing",
                region: "Switzerland",
                conversions: [
                    "44": ["US": "XS/32", "UK": "32", "FR": "42", "IT": "42"],
                    "46": ["US": "S/34", "UK": "34", "FR": "44", "IT": "44"],
                    "48": ["US": "M/36", "UK": "36", "FR": "46", "IT": "46"],
                    "50": ["US": "L/38", "UK": "38", "FR": "48", "IT": "48"],
                    "52": ["US": "XL/40", "UK": "40", "FR": "50", "IT": "50"]
                ]
            ),
            SizeChart(
                category: "Shoes",
                region: "Switzerland",
                conversions: [
                    "37": ["US Women": "6", "US Men": "5", "UK": "4"],
                    "38": ["US Women": "7", "US Men": "6", "UK": "5"],
                    "39": ["US Women": "8", "US Men": "7", "UK": "6"],
                    "40": ["US Women": "9", "US Men": "8", "UK": "7"],
                    "41": ["US Women": "10", "US Men": "9", "UK": "8"],
                    "42": ["US Women": "11", "US Men": "10", "UK": "9"]
                ]
            )
        ]
    }

    // MARK: - Cultural Preferences

    private func getCulturalPreferences(for region: SwissRegion) -> CulturalPreferences {
        switch region {
        case .zurich:
            return CulturalPreferences(
                workStyle: "International business casual to formal",
                socialStyle: "Understated elegance with quality focus",
                colorPreferences: ["Navy", "Charcoal", "White", "Burgundy"],
                fabricPreferences: ["Wool", "Cashmere", "Cotton", "Silk"],
                sustainabilityImportance: .high,
                brandLoyalty: .high,
                priceConsciousness: .medium,
                trendAdoption: .conservative
            )

        case .geneva:
            return CulturalPreferences(
                workStyle: "Diplomatic elegance and international sophistication",
                socialStyle: "French-influenced chic with Swiss quality",
                colorPreferences: ["Black", "Navy", "Cream", "Burgundy", "Forest Green"],
                fabricPreferences: ["Silk", "Wool", "Cashmere", "Linen"],
                sustainabilityImportance: .high,
                brandLoyalty: .high,
                priceConsciousness: .low,
                trendAdoption: .moderate
            )

        case .basel:
            return CulturalPreferences(
                workStyle: "Professional with creative undertones",
                socialStyle: "Artistic and culturally aware",
                colorPreferences: ["Black", "White", "Gray", "Bold accents"],
                fabricPreferences: ["Contemporary materials", "Sustainable options"],
                sustainabilityImportance: .high,
                brandLoyalty: .medium,
                priceConsciousness: .medium,
                trendAdoption: .progressive
            )

        case .bern:
            return CulturalPreferences(
                workStyle: "Conservative governmental and professional",
                socialStyle: "Traditional with quality emphasis",
                colorPreferences: ["Navy", "Brown", "Forest Green", "Cream"],
                fabricPreferences: ["Wool", "Leather", "Natural fibers"],
                sustainabilityImportance: .high,
                brandLoyalty: .high,
                priceConsciousness: .high,
                trendAdoption: .conservative
            )

        case .alps:
            return CulturalPreferences(
                workStyle: "Functional luxury and outdoor performance",
                socialStyle: "Mountain chic and resort elegance",
                colorPreferences: ["Earth tones", "Deep greens", "Mountain blues", "Natural colors"],
                fabricPreferences: ["Technical fabrics", "Merino wool", "Sustainable materials"],
                sustainabilityImportance: .high,
                brandLoyalty: .medium,
                priceConsciousness: .low,
                trendAdoption: .moderate
            )
        }
    }

    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .spring
        }
    }
}

// MARK: - Data Models

enum SwissRegion: String, CaseIterable {
    case zurich = "zurich"
    case geneva = "geneva"
    case basel = "basel"
    case bern = "bern"
    case alps = "alps"

    var displayName: String {
        switch self {
        case .zurich: return "Zürich"
        case .geneva: return "Geneva"
        case .basel: return "Basel"
        case .bern: return "Bern"
        case .alps: return "Swiss Alps"
        }
    }

    var description: String {
        switch self {
        case .zurich: return "International business hub and largest city"
        case .geneva: return "Diplomatic center and French-speaking region"
        case .basel: return "Cultural and pharmaceutical center"
        case .bern: return "Federal capital and traditional Swiss culture"
        case .alps: return "Mountain regions and luxury resorts"
        }
    }
}

struct RegionalWeather {
    let region: SwissRegion
    let coordinates: CLLocationCoordinate2D
    let elevation: Double
    let microclimate: Microclimate
    let seasonalPatterns: SeasonalPatterns
}

struct Microclimate {
    let type: String
    let characteristics: [String]
    let outfitConsiderations: [String]
}

struct SeasonalPatterns {
    let winter: SeasonInfo
    let spring: SeasonInfo
    let summer: SeasonInfo
    let autumn: SeasonInfo
}

struct SeasonInfo {
    let averageTemp: String
    let precipitation: String
    let keyFactors: [String]
    let outfitRecommendations: [String]
}

struct SizeChart {
    let category: String
    let region: String
    let conversions: [String: [String: String]]
}

struct CulturalPreferences {
    let workStyle: String
    let socialStyle: String
    let colorPreferences: [String]
    let fabricPreferences: [String]
    let sustainabilityImportance: ImportanceLevel
    let brandLoyalty: LoyaltyLevel
    let priceConsciousness: ConsciousnessLevel
    let trendAdoption: AdoptionSpeed
}

enum ImportanceLevel {
    case low, medium, high
}

enum LoyaltyLevel {
    case low, medium, high
}

enum ConsciousnessLevel {
    case low, medium, high
}

enum AdoptionSpeed {
    case conservative, moderate, progressive
}