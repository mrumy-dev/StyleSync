import SwiftUI
import Foundation

struct SwissMarketFeatures {
    static let shared = SwissMarketFeatures()

    private init() {}

    // MARK: - Swiss Fashion Trends

    func getSwissFashionTrends(for season: Season) -> [SwissTrend] {
        switch season {
        case .winter:
            return [
                SwissTrend(
                    name: "Alpine Elegance",
                    description: "Sophisticated mountain-inspired fashion",
                    keywords: ["cashmere", "wool", "neutral", "structured"],
                    popularBrands: ["Akris", "Bally", "Zimmerli"]
                ),
                SwissTrend(
                    name: "Swiss Urban Chic",
                    description: "Minimalist city style with Swiss precision",
                    keywords: ["black", "white", "clean lines", "quality"],
                    popularBrands: ["Freitag", "Qwstion", "NIKIN"]
                ),
                SwissTrend(
                    name: "Apres-Ski Luxe",
                    description: "Luxury comfort for mountain lifestyle",
                    keywords: ["fur", "leather", "warm", "luxurious"],
                    popularBrands: ["Bogner", "Moncler", "Canada Goose"]
                )
            ]

        case .spring:
            return [
                SwissTrend(
                    name: "Fresh Alpine",
                    description: "Light layers inspired by spring in the mountains",
                    keywords: ["pastels", "lightweight", "breathable", "layered"],
                    popularBrands: ["Odlo", "Mammut", "Ortovox"]
                ),
                SwissTrend(
                    name: "Swiss Minimalism",
                    description: "Clean, functional design principles",
                    keywords: ["simple", "functional", "quality", "timeless"],
                    popularBrands: ["COS", "Arket", "Filippa K"]
                )
            ]

        case .summer:
            return [
                SwissTrend(
                    name: "Lake Geneva Style",
                    description: "Sophisticated summer elegance",
                    keywords: ["linen", "white", "flowing", "elegant"],
                    popularBrands: ["Hermès", "Brunello Cucinelli", "Loro Piana"]
                ),
                SwissTrend(
                    name: "Swiss Outdoor",
                    description: "Technical fashion for active lifestyle",
                    keywords: ["performance", "breathable", "UV protection", "quick-dry"],
                    popularBrands: ["Patagonia", "Arc'teryx", "Salomon"]
                )
            ]

        case .autumn:
            return [
                SwissTrend(
                    name: "Harvest Sophistication",
                    description: "Rich autumn colors with Swiss precision",
                    keywords: ["burgundy", "forest green", "structured", "quality"],
                    popularBrands: ["Max Mara", "Jil Sander", "The Row"]
                ),
                SwissTrend(
                    name: "Alpine Prep",
                    description: "Preparing for winter with style",
                    keywords: ["layering", "wool", "plaid", "boots"],
                    popularBrands: ["Barbour", "Burberry", "Ralph Lauren"]
                )
            ]
        }
    }

    // MARK: - Swiss Weather Integration

    func getSwissWeatherSources() -> [WeatherSource] {
        return [
            WeatherSource(
                name: "MeteoSchweiz",
                apiKey: "swiss_meteo_api",
                regions: [
                    "Zürich", "Geneva", "Basel", "Bern", "Lausanne",
                    "St. Gallen", "Lucerne", "Lugano", "Winterthur", "Thun"
                ]
            ),
            WeatherSource(
                name: "SRF Meteo",
                apiKey: "srf_weather_api",
                regions: ["German-speaking Switzerland"]
            ),
            WeatherSource(
                name: "RTS Météo",
                apiKey: "rts_weather_api",
                regions: ["French-speaking Switzerland"]
            )
        ]
    }

    func getAlpineWeatherFactors() -> [WeatherFactor] {
        return [
            WeatherFactor(
                name: "Altitude",
                description: "Temperature drops with elevation",
                adjustmentPerMeter: -0.0065 // Celsius per meter
            ),
            WeatherFactor(
                name: "Föhn Wind",
                description: "Warm, dry wind affecting outfit choice",
                impactOnStyle: "Lighter layers, wind protection"
            ),
            WeatherFactor(
                name: "Microclimates",
                description: "Varied conditions across regions",
                impactOnStyle: "Versatile layering system"
            )
        ]
    }

    // MARK: - Currency and Pricing

    func formatSwissFrancs(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CHF"
        formatter.locale = Locale(identifier: "de_CH")
        return formatter.string(from: NSNumber(value: amount)) ?? "CHF \(amount)"
    }

    func getSwissPriceRanges() -> [PriceRange] {
        return [
            PriceRange(category: "Budget", min: 20, max: 100, currency: "CHF"),
            PriceRange(category: "Mid-range", min: 100, max: 500, currency: "CHF"),
            PriceRange(category: "Premium", min: 500, max: 2000, currency: "CHF"),
            PriceRange(category: "Luxury", min: 2000, max: 10000, currency: "CHF")
        ]
    }

    // MARK: - Swiss Brands Directory

    func getSwissBrands() -> [SwissBrand] {
        return [
            SwissBrand(
                name: "Akris",
                category: "Luxury Fashion",
                founded: 1922,
                specialty: "Women's high-end fashion",
                priceRange: .luxury,
                sustainability: .high
            ),
            SwissBrand(
                name: "Bally",
                category: "Luxury Leather Goods",
                founded: 1851,
                specialty: "Shoes and leather accessories",
                priceRange: .premium,
                sustainability: .medium
            ),
            SwissBrand(
                name: "Freitag",
                category: "Sustainable Bags",
                founded: 1993,
                specialty: "Upcycled truck tarp bags",
                priceRange: .midRange,
                sustainability: .high
            ),
            SwissBrand(
                name: "NIKIN",
                category: "Sustainable Streetwear",
                founded: 2016,
                specialty: "Eco-friendly casual wear",
                priceRange: .budget,
                sustainability: .high
            ),
            SwissBrand(
                name: "Mammut",
                category: "Outdoor Gear",
                founded: 1862,
                specialty: "Mountain sports equipment",
                priceRange: .premium,
                sustainability: .high
            )
        ]
    }

    // MARK: - Cultural Considerations

    func getCulturalGuidelines() -> SwissCulturalGuide {
        return SwissCulturalGuide(
            workAttire: WorkAttireGuide(
                banking: "Conservative, high-quality suits in dark colors",
                tech: "Smart casual, emphasis on quality over trends",
                hospitality: "Polished, international style with Swiss attention to detail",
                healthcare: "Professional, clean lines, comfortable"
            ),
            socialEvents: SocialEventGuide(
                businessDinner: "Elegant, understated luxury",
                casualMeeting: "Smart casual, quality basics",
                outdoorActivities: "Functional, weather-appropriate, stylish"
            ),
            seasonalConsiderations: SeasonalConsiderations(
                winter: "Heavy emphasis on quality outerwear, layering",
                spring: "Transitional pieces, weather unpredictability",
                summer: "Breathable fabrics, UV protection for altitude",
                autumn: "Preparation for winter, rich colors"
            ),
            regionalDifferences: RegionalDifferences(
                zurich: "International business style, understated luxury",
                geneva: "French-influenced elegance, diplomatic polish",
                basel: "Industrial chic, practical sophistication",
                mountains: "Functional outdoor luxury, performance meets style"
            )
        )
    }
}

// MARK: - Data Models

struct SwissTrend {
    let name: String
    let description: String
    let keywords: [String]
    let popularBrands: [String]
}

struct WeatherSource {
    let name: String
    let apiKey: String
    let regions: [String]
}

struct WeatherFactor {
    let name: String
    let description: String
    let adjustmentPerMeter: Double?
    let impactOnStyle: String?

    init(name: String, description: String, adjustmentPerMeter: Double? = nil, impactOnStyle: String? = nil) {
        self.name = name
        self.description = description
        self.adjustmentPerMeter = adjustmentPerMeter
        self.impactOnStyle = impactOnStyle
    }
}

struct PriceRange {
    let category: String
    let min: Double
    let max: Double
    let currency: String
}

struct SwissBrand {
    let name: String
    let category: String
    let founded: Int
    let specialty: String
    let priceRange: PriceCategory
    let sustainability: SustainabilityRating
}

enum PriceCategory {
    case budget, midRange, premium, luxury
}

enum SustainabilityRating {
    case low, medium, high
}

struct SwissCulturalGuide {
    let workAttire: WorkAttireGuide
    let socialEvents: SocialEventGuide
    let seasonalConsiderations: SeasonalConsiderations
    let regionalDifferences: RegionalDifferences
}

struct WorkAttireGuide {
    let banking: String
    let tech: String
    let hospitality: String
    let healthcare: String
}

struct SocialEventGuide {
    let businessDinner: String
    let casualMeeting: String
    let outdoorActivities: String
}

struct SeasonalConsiderations {
    let winter: String
    let spring: String
    let summer: String
    let autumn: String
}

struct RegionalDifferences {
    let zurich: String
    let geneva: String
    let basel: String
    let mountains: String
}

// MARK: - Swiss Size Conversion

class SwissSizeConverter {
    static let shared = SwissSizeConverter()

    private init() {}

    func convertToSwissSize(category: ClothingCategory, size: String, fromCountry: String) -> String? {
        switch category {
        case .womensClothing:
            return convertWomensSize(size: size, from: fromCountry)
        case .mensClothing:
            return convertMensSize(size: size, from: fromCountry)
        case .shoes:
            return convertShoeSize(size: size, from: fromCountry)
        }
    }

    private func convertWomensSize(size: String, from country: String) -> String? {
        let sizeConversions: [String: [String: String]] = [
            "US": [
                "XS": "32", "S": "34", "M": "36", "L": "38", "XL": "40",
                "2": "32", "4": "34", "6": "36", "8": "38", "10": "40", "12": "42"
            ],
            "UK": [
                "6": "32", "8": "34", "10": "36", "12": "38", "14": "40", "16": "42"
            ],
            "FR": [
                "34": "32", "36": "34", "38": "36", "40": "38", "42": "40", "44": "42"
            ]
        ]

        return sizeConversions[country]?[size]
    }

    private func convertMensSize(size: String, from country: String) -> String? {
        let sizeConversions: [String: [String: String]] = [
            "US": [
                "XS": "44", "S": "46", "M": "48", "L": "50", "XL": "52", "XXL": "54"
            ],
            "UK": [
                "32": "42", "34": "44", "36": "46", "38": "48", "40": "50", "42": "52"
            ]
        ]

        return sizeConversions[country]?[size]
    }

    private func convertShoeSize(size: String, from country: String) -> String? {
        let sizeConversions: [String: [String: String]] = [
            "US": [
                "7": "39", "7.5": "40", "8": "40.5", "8.5": "41", "9": "42",
                "9.5": "42.5", "10": "43", "10.5": "44", "11": "44.5", "12": "45"
            ],
            "UK": [
                "6": "39", "6.5": "40", "7": "40.5", "7.5": "41", "8": "42",
                "8.5": "42.5", "9": "43", "9.5": "44", "10": "44.5", "11": "45"
            ]
        ]

        return sizeConversions[country]?[size]
    }
}

enum ClothingCategory {
    case womensClothing
    case mensClothing
    case shoes
}