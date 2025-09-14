import Foundation
import AppIntents
import SwiftUI
import CoreLocation

struct WhatShouldIWearIntent: AppIntent {
    static var title: LocalizedStringResource = "What Should I Wear"
    static var description = IntentDescription("Get personalized outfit recommendations based on weather, occasion, and your style")

    static var parameterSummary: some ParameterSummary {
        Summary("What should I wear for \(\.$occasion)") {
            \.$timeOfDay
            \.$weatherOverride
            \.$stylePreference
            \.$includeAccessories
        }
    }

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Occasion", description: "What's the occasion or event?")
    var occasion: OutfitOccasion?

    @Parameter(title: "Time of Day", description: "When will you be wearing this?", default: .now)
    var timeOfDay: TimeOfDay

    @Parameter(title: "Weather Override", description: "Override current weather conditions")
    var weatherOverride: WeatherCondition?

    @Parameter(title: "Style Preference", description: "Any specific style preference for today?")
    var stylePreference: StylePreference?

    @Parameter(title: "Include Accessories", description: "Include accessory suggestions", default: true)
    var includeAccessories: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {

        let context = OutfitRecommendationContext(
            occasion: occasion ?? .casual,
            timeOfDay: timeOfDay,
            weatherOverride: weatherOverride,
            stylePreference: stylePreference,
            includeAccessories: includeAccessories,
            timestamp: Date()
        )

        let recommendation = await OutfitRecommendationService.shared.getRecommendation(for: context)

        let dialog = generateDialog(for: recommendation, context: context)
        let snippet = OutfitRecommendationView(recommendation: recommendation, context: context)

        return .result(
            dialog: dialog,
            view: snippet
        )
    }

    private func generateDialog(for recommendation: OutfitRecommendation, context: OutfitRecommendationContext) -> IntentDialog {
        let occasionText = context.occasion.displayName
        let weatherText = recommendation.weatherInfo.map { "\(Int($0.temperature))° and \($0.condition.lowercased())" } ?? "current conditions"

        var message = "For your \(occasionText.lowercased()) occasion with \(weatherText), I recommend "

        if let mainPieces = recommendation.mainPieces, !mainPieces.isEmpty {
            let pieceNames = mainPieces.prefix(2).map { $0.name }.joined(separator: " and ")
            message += pieceNames
        }

        if let colorScheme = recommendation.colorScheme {
            message += " in \(colorScheme.primary.lowercased())"
            if let accent = colorScheme.accent {
                message += " with \(accent.lowercased()) accents"
            }
        }

        if context.includeAccessories, let accessories = recommendation.accessories, !accessories.isEmpty {
            message += ". Don't forget your \(accessories.first!.name.lowercased())"
        }

        message += "!"

        return IntentDialog(message)
    }
}

enum OutfitOccasion: String, CaseIterable, AppEnum {
    case casual = "casual"
    case work = "work"
    case meeting = "meeting"
    case date = "date"
    case party = "party"
    case workout = "workout"
    case travel = "travel"
    case formal = "formal"
    case brunch = "brunch"
    case shopping = "shopping"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Occasion")

    static var caseDisplayRepresentations: [OutfitOccasion: DisplayRepresentation] = [
        .casual: DisplayRepresentation(title: "Casual", subtitle: "Relaxed everyday wear"),
        .work: DisplayRepresentation(title: "Work", subtitle: "Professional office attire"),
        .meeting: DisplayRepresentation(title: "Meeting", subtitle: "Business meeting"),
        .date: DisplayRepresentation(title: "Date", subtitle: "Romantic date night"),
        .party: DisplayRepresentation(title: "Party", subtitle: "Social gathering"),
        .workout: DisplayRepresentation(title: "Workout", subtitle: "Exercise or gym"),
        .travel: DisplayRepresentation(title: "Travel", subtitle: "Comfortable travel outfit"),
        .formal: DisplayRepresentation(title: "Formal", subtitle: "Black tie or formal event"),
        .brunch: DisplayRepresentation(title: "Brunch", subtitle: "Weekend brunch"),
        .shopping: DisplayRepresentation(title: "Shopping", subtitle: "Shopping trip")
    ]

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .work: return "Work"
        case .meeting: return "Meeting"
        case .date: return "Date"
        case .party: return "Party"
        case .workout: return "Workout"
        case .travel: return "Travel"
        case .formal: return "Formal"
        case .brunch: return "Brunch"
        case .shopping: return "Shopping"
        }
    }

    var dressCode: DressCode {
        switch self {
        case .casual, .brunch, .shopping: return .casual
        case .work, .meeting: return .business
        case .date, .party: return .smart_casual
        case .workout: return .athletic
        case .travel: return .comfortable
        case .formal: return .formal
        }
    }
}

enum TimeOfDay: String, CaseIterable, AppEnum {
    case now = "now"
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Time of Day")

    static var caseDisplayRepresentations: [TimeOfDay: DisplayRepresentation] = [
        .now: DisplayRepresentation(title: "Right Now"),
        .morning: DisplayRepresentation(title: "Morning"),
        .afternoon: DisplayRepresentation(title: "Afternoon"),
        .evening: DisplayRepresentation(title: "Evening"),
        .night: DisplayRepresentation(title: "Night")
    ]
}

enum WeatherCondition: String, CaseIterable, AppEnum {
    case sunny = "sunny"
    case cloudy = "cloudy"
    case rainy = "rainy"
    case cold = "cold"
    case hot = "hot"
    case windy = "windy"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Weather")

    static var caseDisplayRepresentations: [WeatherCondition: DisplayRepresentation] = [
        .sunny: DisplayRepresentation(title: "Sunny"),
        .cloudy: DisplayRepresentation(title: "Cloudy"),
        .rainy: DisplayRepresentation(title: "Rainy"),
        .cold: DisplayRepresentation(title: "Cold"),
        .hot: DisplayRepresentation(title: "Hot"),
        .windy: DisplayRepresentation(title: "Windy")
    ]

    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .cold: return "snowflake"
        case .hot: return "thermometer.sun.fill"
        case .windy: return "wind"
        }
    }
}

enum StylePreference: String, CaseIterable, AppEnum {
    case minimalist = "minimalist"
    case bold = "bold"
    case romantic = "romantic"
    case edgy = "edgy"
    case bohemian = "bohemian"
    case classic = "classic"
    case trendy = "trendy"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Style")

    static var caseDisplayRepresentations: [StylePreference: DisplayRepresentation] = [
        .minimalist: DisplayRepresentation(title: "Minimalist", subtitle: "Clean and simple"),
        .bold: DisplayRepresentation(title: "Bold", subtitle: "Statement pieces"),
        .romantic: DisplayRepresentation(title: "Romantic", subtitle: "Soft and feminine"),
        .edgy: DisplayRepresentation(title: "Edgy", subtitle: "Modern and sharp"),
        .bohemian: DisplayRepresentation(title: "Bohemian", subtitle: "Free-spirited"),
        .classic: DisplayRepresentation(title: "Classic", subtitle: "Timeless elegance"),
        .trendy: DisplayRepresentation(title: "Trendy", subtitle: "Fashion-forward")
    ]
}

enum DressCode {
    case casual
    case business
    case smart_casual
    case athletic
    case comfortable
    case formal
}

struct OutfitRecommendationContext {
    let occasion: OutfitOccasion
    let timeOfDay: TimeOfDay
    let weatherOverride: WeatherCondition?
    let stylePreference: StylePreference?
    let includeAccessories: Bool
    let timestamp: Date
}

struct OutfitRecommendation {
    let mainPieces: [ClothingItem]?
    let accessories: [AccessoryItem]?
    let colorScheme: ColorScheme?
    let weatherInfo: WeatherInfo?
    let styleNotes: [String]
    let confidenceScore: Double
    let alternatives: [OutfitAlternative]
}

struct ClothingItem {
    let id: String
    let name: String
    let category: String
    let color: String
    let description: String
    let icon: String
}

struct AccessoryItem {
    let id: String
    let name: String
    let category: String
    let color: String
    let icon: String
}

struct ColorScheme {
    let primary: String
    let secondary: String?
    let accent: String?
    let neutral: String?
}

struct WeatherInfo {
    let temperature: Double
    let condition: String
    let icon: String
    let humidity: Int?
    let windSpeed: Double?
}

struct OutfitAlternative {
    let title: String
    let description: String
    let mainDifference: String
}

class OutfitRecommendationService {
    static let shared = OutfitRecommendationService()

    func getRecommendation(for context: OutfitRecommendationContext) async -> OutfitRecommendation {

        await Task.sleep(nanoseconds: 1_500_000_000)

        let weatherInfo = await getWeatherInfo(override: context.weatherOverride)
        let colorScheme = generateColorScheme(for: context, weather: weatherInfo)
        let mainPieces = generateMainPieces(for: context, weather: weatherInfo, colorScheme: colorScheme)
        let accessories = context.includeAccessories ? generateAccessories(for: context, colorScheme: colorScheme) : nil

        return OutfitRecommendation(
            mainPieces: mainPieces,
            accessories: accessories,
            colorScheme: colorScheme,
            weatherInfo: weatherInfo,
            styleNotes: generateStyleNotes(for: context),
            confidenceScore: 0.89,
            alternatives: generateAlternatives(for: context)
        )
    }

    private func getWeatherInfo(override: WeatherCondition?) async -> WeatherInfo {
        if let override = override {
            let temp: Double
            let condition: String
            let icon: String

            switch override {
            case .sunny:
                temp = 75; condition = "Sunny"; icon = "sun.max.fill"
            case .cloudy:
                temp = 65; condition = "Cloudy"; icon = "cloud.fill"
            case .rainy:
                temp = 55; condition = "Rainy"; icon = "cloud.rain.fill"
            case .cold:
                temp = 35; condition = "Cold"; icon = "snowflake"
            case .hot:
                temp = 95; condition = "Hot"; icon = "thermometer.sun.fill"
            case .windy:
                temp = 60; condition = "Windy"; icon = "wind"
            }

            return WeatherInfo(temperature: temp, condition: condition, icon: icon, humidity: 65, windSpeed: 10)
        }


        return WeatherInfo(temperature: 72, condition: "Partly Cloudy", icon: "cloud.sun.fill", humidity: 60, windSpeed: 8)
    }

    private func generateColorScheme(for context: OutfitRecommendationContext, weather: WeatherInfo) -> ColorScheme {
        let style = context.stylePreference ?? .classic

        switch style {
        case .minimalist:
            return ColorScheme(primary: "White", secondary: "Gray", accent: "Black", neutral: "Beige")
        case .bold:
            return ColorScheme(primary: "Royal Blue", secondary: "White", accent: "Gold", neutral: "Navy")
        case .romantic:
            return ColorScheme(primary: "Blush Pink", secondary: "Cream", accent: "Rose Gold", neutral: "Taupe")
        case .edgy:
            return ColorScheme(primary: "Black", secondary: "White", accent: "Silver", neutral: "Charcoal")
        case .bohemian:
            return ColorScheme(primary: "Terracotta", secondary: "Cream", accent: "Turquoise", neutral: "Brown")
        case .classic:
            return ColorScheme(primary: "Navy", secondary: "White", accent: "Brown", neutral: "Camel")
        case .trendy:
            return ColorScheme(primary: "Sage Green", secondary: "Cream", accent: "Gold", neutral: "Tan")
        }
    }

    private func generateMainPieces(for context: OutfitRecommendationContext, weather: WeatherInfo, colorScheme: ColorScheme) -> [ClothingItem] {
        let occasion = context.occasion

        switch occasion.dressCode {
        case .casual:
            return [
                ClothingItem(id: "1", name: "Cotton T-Shirt", category: "Top", color: colorScheme.primary, description: "Comfortable everyday tee", icon: "tshirt.fill"),
                ClothingItem(id: "2", name: "Denim Jeans", category: "Bottom", color: colorScheme.neutral ?? "Blue", description: "Classic straight-leg jeans", icon: "rectangle.fill"),
                ClothingItem(id: "3", name: "Canvas Sneakers", category: "Shoes", color: "White", description: "Comfortable casual sneakers", icon: "shoe.2.fill")
            ]

        case .business:
            return [
                ClothingItem(id: "1", name: "Button-Down Shirt", category: "Top", color: colorScheme.secondary ?? "White", description: "Crisp professional shirt", icon: "shirt.fill"),
                ClothingItem(id: "2", name: "Tailored Trousers", category: "Bottom", color: colorScheme.primary, description: "Well-fitted dress pants", icon: "rectangle.fill"),
                ClothingItem(id: "3", name: "Oxford Shoes", category: "Shoes", color: colorScheme.accent ?? "Brown", description: "Classic leather oxfords", icon: "shoe.fill"),
                ClothingItem(id: "4", name: "Blazer", category: "Outer", color: colorScheme.neutral ?? "Charcoal", description: "Structured blazer", icon: "jacket.fill")
            ]

        case .smart_casual:
            return [
                ClothingItem(id: "1", name: "Cashmere Sweater", category: "Top", color: colorScheme.primary, description: "Soft luxury sweater", icon: "tshirt.fill"),
                ClothingItem(id: "2", name: "Dark Jeans", category: "Bottom", color: "Dark Denim", description: "Elevated denim", icon: "rectangle.fill"),
                ClothingItem(id: "3", name: "Loafers", category: "Shoes", color: colorScheme.accent ?? "Brown", description: "Comfortable dress shoes", icon: "shoe.fill")
            ]

        case .athletic:
            return [
                ClothingItem(id: "1", name: "Performance Top", category: "Top", color: colorScheme.primary, description: "Moisture-wicking athletic top", icon: "tshirt.fill"),
                ClothingItem(id: "2", name: "Athletic Leggings", category: "Bottom", color: "Black", description: "High-performance leggings", icon: "rectangle.fill"),
                ClothingItem(id: "3", name: "Running Shoes", category: "Shoes", color: colorScheme.accent ?? "White", description: "Supportive athletic shoes", icon: "shoe.2.fill")
            ]

        case .comfortable:
            return [
                ClothingItem(id: "1", name: "Cozy Hoodie", category: "Top", color: colorScheme.primary, description: "Soft comfortable hoodie", icon: "tshirt.fill"),
                ClothingItem(id: "2", name: "Stretch Pants", category: "Bottom", color: colorScheme.neutral ?? "Gray", description: "Flexible comfort pants", icon: "rectangle.fill"),
                ClothingItem(id: "3", name: "Slip-on Sneakers", category: "Shoes", color: "White", description: "Easy slip-on shoes", icon: "shoe.2.fill")
            ]

        case .formal:
            return [
                ClothingItem(id: "1", name: "Silk Blouse", category: "Top", color: colorScheme.secondary ?? "Ivory", description: "Elegant silk blouse", icon: "shirt.fill"),
                ClothingItem(id: "2", name: "Dress Pants", category: "Bottom", color: colorScheme.primary, description: "Formal tailored pants", icon: "rectangle.fill"),
                ClothingItem(id: "3", name: "Dress Shoes", category: "Shoes", color: "Black", description: "Formal leather shoes", icon: "shoe.fill"),
                ClothingItem(id: "4", name: "Statement Blazer", category: "Outer", color: colorScheme.accent ?? "Navy", description: "Sophisticated blazer", icon: "jacket.fill")
            ]
        }
    }

    private func generateAccessories(for context: OutfitRecommendationContext, colorScheme: ColorScheme) -> [AccessoryItem] {
        var accessories: [AccessoryItem] = []

        accessories.append(AccessoryItem(id: "1", name: "Classic Watch", category: "Jewelry", color: colorScheme.accent ?? "Silver", icon: "applewatch"))
        accessories.append(AccessoryItem(id: "2", name: "Leather Belt", category: "Belt", color: colorScheme.accent ?? "Brown", icon: "oval.fill"))

        if context.occasion == .formal || context.occasion == .date {
            accessories.append(AccessoryItem(id: "3", name: "Statement Necklace", category: "Jewelry", color: "Gold", icon: "circle.fill"))
        }

        if context.occasion == .casual || context.occasion == .shopping {
            accessories.append(AccessoryItem(id: "4", name: "Canvas Tote", category: "Bag", color: colorScheme.neutral ?? "Tan", icon: "bag.fill"))
        }

        return accessories
    }

    private func generateStyleNotes(for context: OutfitRecommendationContext) -> [String] {
        var notes: [String] = []

        notes.append("Perfect for \(context.occasion.displayName.lowercased()) occasions")

        if let style = context.stylePreference {
            switch style {
            case .minimalist:
                notes.append("Clean lines and neutral tones create a sophisticated look")
            case .bold:
                notes.append("Statement pieces add confidence and personality")
            case .romantic:
                notes.append("Soft colors and flowing fabrics create feminine elegance")
            case .edgy:
                notes.append("Sharp silhouettes and contrasts make a modern statement")
            case .bohemian:
                notes.append("Earthy tones and textures reflect free-spirited style")
            case .classic:
                notes.append("Timeless pieces ensure you'll always look put-together")
            case .trendy:
                notes.append("Current fashion elements keep your look fresh")
            }
        }

        notes.append("Consider the weather and adjust layers as needed")
        return notes
    }

    private func generateAlternatives(for context: OutfitRecommendationContext) -> [OutfitAlternative] {
        return [
            OutfitAlternative(
                title: "Casual Alternative",
                description: "Swap formal pieces for more relaxed options",
                mainDifference: "More comfortable and laid-back"
            ),
            OutfitAlternative(
                title: "Color Pop Version",
                description: "Add a bright accent piece to energize the look",
                mainDifference: "Brighter and more playful"
            ),
            OutfitAlternative(
                title: "Elevated Option",
                description: "Upgrade with premium fabrics and refined accessories",
                mainDifference: "More sophisticated and polished"
            )
        ]
    }
}

struct OutfitRecommendationView: View {
    let recommendation: OutfitRecommendation
    let context: OutfitRecommendationContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outfit Recommendation")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("For \(context.occasion.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let weather = recommendation.weatherInfo {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: weather.icon)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(Int(weather.temperature))°")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        Text(weather.condition)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }


            if let mainPieces = recommendation.mainPieces, !mainPieces.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Main Pieces")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(mainPieces.prefix(4), id: \.id) { piece in
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: piece.icon)
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(piece.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)

                                    Text(piece.color)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }


            if let colorScheme = recommendation.colorScheme {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color Palette")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack(spacing: 8) {
                        ColorSwatch(color: colorScheme.primary, label: "Primary")

                        if let secondary = colorScheme.secondary {
                            ColorSwatch(color: secondary, label: "Secondary")
                        }

                        if let accent = colorScheme.accent {
                            ColorSwatch(color: accent, label: "Accent")
                        }

                        Spacer()
                    }
                }
            }


            if !recommendation.styleNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Style Notes")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(recommendation.styleNotes.prefix(2), id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)

                            Text(note)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ColorSwatch: View {
    let color: String
    let label: String

    private var swatchColor: Color {
        switch color.lowercased() {
        case "white", "ivory", "cream": return .white
        case "black", "charcoal": return .black
        case "navy", "royal blue": return .blue
        case "gray", "grey": return .gray
        case "brown", "tan", "camel": return .brown
        case "red": return .red
        case "pink", "blush pink": return .pink
        case "green", "sage green": return .green
        case "yellow", "gold": return .yellow
        case "purple": return .purple
        case "orange", "terracotta": return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(swatchColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}