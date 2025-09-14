import Foundation
import SwiftUI

@MainActor
class SmartOutfitPlanner: ObservableObject {
    @Published var outfitHistory: [OutfitHistory] = []

    private let wardrobeAnalyzer = WardrobeAnalyzer()
    private let colorMatcher = ColorMatcher()
    private let fitAnalyzer = FitAnalyzer()

    func suggestOutfit(
        for event: CalendarEvent,
        weather: WeatherForecast?,
        previousOutfits: [PlannedOutfit]
    ) async -> PlannedOutfit {

        // Analyze requirements based on event
        let requirements = analyzeEventRequirements(event, weather: weather)

        // Get available wardrobe items
        let availableItems = await getAvailableWardrobeItems()

        // Filter items based on requirements
        let suitableItems = filterSuitableItems(availableItems, requirements: requirements)

        // Avoid repetition
        let uniqueItems = avoidRepetition(suitableItems, previousOutfits: previousOutfits, event: event)

        // Generate outfit combinations
        let outfitOptions = generateOutfitCombinations(uniqueItems, requirements: requirements)

        // Rank outfits
        let rankedOutfits = rankOutfits(outfitOptions, event: event, weather: weather)

        // Return best outfit
        return rankedOutfits.first ?? createFallbackOutfit(event: event)
    }

    private func analyzeEventRequirements(
        _ event: CalendarEvent,
        weather: WeatherForecast?
    ) -> OutfitRequirements {

        var requirements = OutfitRequirements()

        // Base requirements from dress code
        requirements.dressCode = event.dressCode
        requirements.formality = formalityLevel(for: event.dressCode)

        // Event-specific adjustments
        switch event.eventType {
        case .videoCall:
            requirements.videoCallOptimized = true
            requirements.focusArea = .upperBody
            requirements.avoidPatterns = ["stripes", "small patterns", "busy prints"]
            requirements.preferredColors = ["navy", "blue", "burgundy", "forest green"]
            requirements.avoidColors = ["white", "bright colors", "neon"]

        case .jobInterview:
            requirements.conservativeStyle = true
            requirements.confidence = .high
            requirements.preferredColors = ["navy", "charcoal", "black", "white"]
            requirements.mustHaveItems = ["blazer", "dress shoes"]
            requirements.avoidItems = ["casual shoes", "jeans", "t-shirts"]

        case .dateNight:
            requirements.attractiveness = .high
            requirements.comfort = .medium
            requirements.style = .romantic
            requirements.preferredColors = ["black", "burgundy", "emerald", "navy"]
            requirements.suggestedItems = ["dress", "heels", "statement jewelry"]

        case .workMeeting:
            requirements.professional = true
            requirements.comfort = .high
            requirements.versatility = .high
            if event.importance == .critical {
                requirements.formality = .business
                requirements.mustHaveItems = ["blazer"]
            }

        case .specialEvent:
            requirements.specialOccasion = true
            requirements.memorability = .high
            requirements.photoReady = true

        case .fitness:
            requirements.activewear = true
            requirements.comfort = .maximum
            requirements.functionality = .high
            requirements.mustHaveItems = ["athletic wear", "sneakers"]

        case .travel:
            requirements.comfort = .maximum
            requirements.versatility = .high
            requirements.wrinkleResistant = true
            requirements.layerable = true

        case .casual:
            requirements.comfort = .high
            requirements.relaxed = true
        }

        // Weather adjustments
        if let weather = weather {
            requirements.weatherConsiderations = analyzeWeatherRequirements(weather)
        }

        // Time-based adjustments
        let hour = Calendar.current.component(.hour, from: event.startDate)
        if hour >= 18 {
            requirements.eveningAppropriate = true
        }

        return requirements
    }

    private func analyzeWeatherRequirements(_ weather: WeatherForecast) -> WeatherRequirements {
        var requirements = WeatherRequirements()

        // Temperature-based
        if weather.temperature < 10 {
            requirements.warmth = .high
            requirements.layers = ["coat", "sweater", "scarf"]
            requirements.mustHaveItems = ["warm coat", "boots"]
        } else if weather.temperature < 20 {
            requirements.warmth = .medium
            requirements.layers = ["jacket", "cardigan"]
            requirements.suggestedItems = ["light jacket", "closed shoes"]
        } else {
            requirements.warmth = .low
            requirements.breathable = true
            requirements.lightColors = true
        }

        // Precipitation
        if weather.precipitationChance > 60 {
            requirements.waterproof = true
            requirements.mustHaveItems.append(contentsOf: ["umbrella", "rain coat"])
            requirements.avoidItems.append(contentsOf: ["suede", "light colors"])
        }

        // Wind
        if weather.windSpeed > 20 {
            requirements.windResistant = true
            requirements.avoidItems.append(contentsOf: ["loose scarves", "flowing dresses"])
        }

        return requirements
    }

    private func getAvailableWardrobeItems() async -> [WardrobeItem] {
        // Simulate fetching from Core Data
        await Task.sleep(nanoseconds: 100_000_000)

        return [
            // Sample wardrobe items - in production, this would come from the database
            WardrobeItem(
                id: UUID(),
                name: "Navy Blazer",
                category: "Outerwear",
                subcategory: "Blazer",
                color: "Navy",
                brand: "Theory",
                size: "M",
                purchasePrice: 400,
                purchaseDate: Date(),
                tags: ["professional", "versatile", "wrinkle-resistant"],
                style: .business,
                season: [.spring, .summer, .fall],
                occasions: [.work, .formal],
                bodyFit: .tailored,
                comfort: .medium,
                versatility: .high,
                condition: .excellent,
                lastWorn: Date(),
                timesWorn: 25,
                averageRating: 4.8,
                imageURL: nil
            ),
            // Add more sample items...
        ]
    }

    private func filterSuitableItems(
        _ items: [WardrobeItem],
        requirements: OutfitRequirements
    ) -> [WardrobeItem] {

        return items.filter { item in
            // Check dress code compatibility
            guard isCompatibleWithDressCode(item, dressCode: requirements.dressCode) else {
                return false
            }

            // Check must-have items
            if !requirements.mustHaveItems.isEmpty {
                let itemMatches = requirements.mustHaveItems.contains { mustHave in
                    item.name.lowercased().contains(mustHave.lowercased()) ||
                    item.category.lowercased().contains(mustHave.lowercased()) ||
                    item.subcategory.lowercased().contains(mustHave.lowercased())
                }
                if !itemMatches && requirements.mustHaveItems.contains(where: { item.category.lowercased().contains($0.lowercased()) }) {
                    return false
                }
            }

            // Check avoid items
            for avoidItem in requirements.avoidItems {
                if item.name.lowercased().contains(avoidItem.lowercased()) ||
                   item.category.lowercased().contains(avoidItem.lowercased()) {
                    return false
                }
            }

            // Check color preferences
            if !requirements.avoidColors.isEmpty && requirements.avoidColors.contains(item.color.lowercased()) {
                return false
            }

            // Check video call optimization
            if requirements.videoCallOptimized {
                // Avoid busy patterns and very bright colors
                if item.tags.contains(where: { ["striped", "patterned", "busy", "bright"].contains($0) }) {
                    return false
                }

                // Prefer solid colors in upper body items
                if ["tops", "blazers", "shirts"].contains(item.category.lowercased()) {
                    return item.tags.contains("solid") || !item.tags.contains("patterned")
                }
            }

            // Check weather compatibility
            if let weatherReqs = requirements.weatherConsiderations {
                if weatherReqs.warmth == .high && !item.tags.contains(where: { ["warm", "thick", "insulated"].contains($0) }) {
                    return false
                }

                if weatherReqs.waterproof && item.tags.contains(where: { ["suede", "delicate"].contains($0) }) {
                    return false
                }
            }

            return true
        }
    }

    private func avoidRepetition(
        _ items: [WardrobeItem],
        previousOutfits: [PlannedOutfit],
        event: CalendarEvent
    ) -> [WardrobeItem] {

        // Get recent outfits from similar events
        let recentSimilarOutfits = previousOutfits.filter { outfit in
            // Check if event was within the last 2 weeks
            guard let outfitDate = outfit.eventDate,
                  abs(outfitDate.timeIntervalSince(event.startDate)) < 14 * 24 * 3600 else {
                return false
            }

            // Check if event type is similar
            return outfit.eventType == event.eventType ||
                   outfit.dressCode == event.dressCode
        }

        // Get items that were worn recently
        let recentlyWornItemIds = Set(recentSimilarOutfits.flatMap { $0.items.map { $0.id } })

        // Filter out recently worn items, but allow if no alternatives
        let filteredItems = items.filter { !recentlyWornItemIds.contains($0.id) }

        // If filtering removed too many options, gradually add back items
        if filteredItems.count < items.count * 0.3 {
            return items // Return all items if we filtered too aggressively
        }

        return filteredItems
    }

    private func generateOutfitCombinations(
        _ items: [WardrobeItem],
        requirements: OutfitRequirements
    ) -> [OutfitCombination] {

        var combinations: [OutfitCombination] = []

        // Group items by category
        let itemsByCategory = Dictionary(grouping: items, by: { $0.category })

        let tops = itemsByCategory["Tops"] ?? []
        let bottoms = itemsByCategory["Bottoms"] ?? []
        let outerwear = itemsByCategory["Outerwear"] ?? []
        let shoes = itemsByCategory["Shoes"] ?? []
        let accessories = itemsByCategory["Accessories"] ?? []

        // Generate base combinations (top + bottom + shoes)
        for top in tops {
            for bottom in bottoms {
                for shoe in shoes {
                    // Check if combination works
                    if isValidCombination([top, bottom, shoe], requirements: requirements) {
                        var combination = OutfitCombination(
                            items: [top, bottom, shoe],
                            score: 0,
                            reasoning: []
                        )

                        // Add outerwear if needed
                        if let bestOuterwear = selectBestOuterwear(outerwear, for: combination, requirements: requirements) {
                            combination.items.append(bestOuterwear)
                        }

                        // Add accessories
                        let selectedAccessories = selectAccessories(accessories, for: combination, requirements: requirements)
                        combination.items.append(contentsOf: selectedAccessories)

                        combinations.append(combination)
                    }
                }
            }
        }

        // Generate dress-based combinations
        let dresses = itemsByCategory["Dresses"] ?? []
        for dress in dresses {
            for shoe in shoes {
                if isValidCombination([dress, shoe], requirements: requirements) {
                    var combination = OutfitCombination(
                        items: [dress, shoe],
                        score: 0,
                        reasoning: []
                    )

                    // Add outerwear if needed
                    if let bestOuterwear = selectBestOuterwear(outerwear, for: combination, requirements: requirements) {
                        combination.items.append(bestOuterwear)
                    }

                    // Add accessories
                    let selectedAccessories = selectAccessories(accessories, for: combination, requirements: requirements)
                    combination.items.append(contentsOf: selectedAccessories)

                    combinations.append(combination)
                }
            }
        }

        return combinations
    }

    private func rankOutfits(
        _ combinations: [OutfitCombination],
        event: CalendarEvent,
        weather: WeatherForecast?
    ) -> [PlannedOutfit] {

        let scoredCombinations = combinations.map { combination -> ScoredOutfitCombination in
            let score = calculateOutfitScore(combination, event: event, weather: weather)
            let reasoning = generateOutfitReasoning(combination, event: event, score: score)

            return ScoredOutfitCombination(
                combination: combination,
                score: score,
                reasoning: reasoning
            )
        }

        // Sort by score (highest first)
        let rankedCombinations = scoredCombinations.sorted { $0.score > $1.score }

        // Convert to PlannedOutfit
        return rankedCombinations.map { scoredCombo in
            PlannedOutfit(
                id: UUID(),
                eventId: event.id,
                eventType: event.eventType,
                dressCode: event.dressCode,
                items: scoredCombo.combination.items,
                confidence: min(scoredCombo.score / 100, 1.0),
                reasoning: scoredCombo.reasoning,
                weatherConsiderations: weather != nil ? generateWeatherNotes(weather!) : [],
                alternatives: [], // Could be populated with other high-scoring combinations
                createdAt: Date(),
                eventDate: event.startDate
            )
        }
    }

    private func calculateOutfitScore(
        _ combination: OutfitCombination,
        event: CalendarEvent,
        weather: WeatherForecast?
    ) -> Double {

        var score: Double = 50 // Base score

        // Appropriateness for event type (30 points)
        score += calculateEventAppropriatenessScore(combination, event: event)

        // Weather suitability (20 points)
        if let weather = weather {
            score += calculateWeatherSuitabilityScore(combination, weather: weather)
        }

        // Color harmony (15 points)
        score += calculateColorHarmonyScore(combination)

        // Style coherence (15 points)
        score += calculateStyleCoherenceScore(combination)

        // Comfort and practicality (10 points)
        score += calculateComfortScore(combination, event: event)

        // Versatility and investment value (5 points)
        score += calculateVersatilityScore(combination)

        // Condition and care (5 points)
        score += calculateConditionScore(combination)

        return max(0, min(100, score))
    }

    // MARK: - Scoring Helpers
    private func calculateEventAppropriatenessScore(_ combination: OutfitCombination, event: CalendarEvent) -> Double {
        let items = combination.items
        var score: Double = 0

        switch event.eventType {
        case .workMeeting:
            // Professional items get higher scores
            for item in items {
                if item.occasions.contains(.work) {
                    score += 5
                }
                if item.style == .business || item.style == .businessCasual {
                    score += 3
                }
            }

        case .videoCall:
            // Upper body items are more important
            for item in items {
                if ["Tops", "Blazers", "Shirts"].contains(item.category) {
                    score += 8 // Higher weight for visible items

                    // Solid colors score higher
                    if !item.tags.contains("patterned") {
                        score += 2
                    }
                }
            }

        case .dateNight:
            // Attractive and flattering items
            for item in items {
                if item.occasions.contains(.social) {
                    score += 5
                }
                if item.tags.contains(where: { ["elegant", "flattering", "attractive"].contains($0) }) {
                    score += 3
                }
            }

        case .jobInterview:
            // Conservative, professional
            for item in items {
                if item.style == .business {
                    score += 6
                }
                if item.tags.contains(where: { ["conservative", "professional", "classic"].contains($0) }) {
                    score += 2
                }
            }

        default:
            // General appropriateness
            score += 15
        }

        return min(30, score)
    }

    private func calculateWeatherSuitabilityScore(_ combination: OutfitCombination, weather: WeatherForecast) -> Double {
        var score: Double = 0
        let items = combination.items

        // Temperature appropriateness
        if weather.temperature < 10 {
            // Cold weather - need warm items
            let warmItems = items.filter { item in
                item.tags.contains(where: { ["warm", "insulated", "thick", "wool", "cashmere"].contains($0) })
            }
            score += Double(warmItems.count * 3)

            // Deduct for inappropriate items
            let coldInappropriate = items.filter { item in
                item.tags.contains(where: { ["light", "thin", "sleeveless"].contains($0) })
            }
            score -= Double(coldInappropriate.count * 2)

        } else if weather.temperature > 25 {
            // Hot weather - need breathable items
            let coolItems = items.filter { item in
                item.tags.contains(where: { ["breathable", "light", "cotton", "linen"].contains($0) })
            }
            score += Double(coolItems.count * 3)
        }

        // Rain protection
        if weather.precipitationChance > 50 {
            let rainProtection = items.filter { item in
                item.tags.contains(where: { ["waterproof", "water-resistant"].contains($0) })
            }
            if !rainProtection.isEmpty {
                score += 5
            }

            // Deduct for rain-sensitive materials
            let rainSensitive = items.filter { item in
                item.tags.contains(where: { ["suede", "silk", "delicate"].contains($0) })
            }
            score -= Double(rainSensitive.count * 3)
        }

        return min(20, score)
    }

    private func calculateColorHarmonyScore(_ combination: OutfitCombination) -> Double {
        let colors = combination.items.map { $0.color.lowercased() }

        // Use color matching logic
        let harmony = colorMatcher.calculateHarmony(colors: colors)

        return harmony * 15 // Scale to 15 points max
    }

    private func calculateStyleCoherenceScore(_ combination: OutfitCombination) -> Double {
        let styles = combination.items.compactMap { $0.style }

        guard !styles.isEmpty else { return 0 }

        // Check if styles are coherent
        let uniqueStyles = Set(styles)

        if uniqueStyles.count == 1 {
            return 15 // Perfect coherence
        } else if uniqueStyles.count == 2 {
            // Check if styles are compatible
            let compatiblePairs: [(OutfitStyle, OutfitStyle)] = [
                (.business, .businessCasual),
                (.casual, .bohemian),
                (.minimalist, .modern),
                (.classic, .business)
            ]

            for (style1, style2) in compatiblePairs {
                if uniqueStyles.contains(style1) && uniqueStyles.contains(style2) {
                    return 10
                }
            }
            return 5 // Somewhat compatible
        } else {
            return 0 // Too many different styles
        }
    }

    private func calculateComfortScore(_ combination: OutfitCombination, event: CalendarEvent) -> Double {
        let avgComfort = combination.items.map { Double($0.comfort.rawValue) }.reduce(0, +) / Double(combination.items.count)

        // Adjust based on event duration
        let eventDuration = event.endDate.timeIntervalSince(event.startDate) / 3600 // hours

        var score = avgComfort * 2 // Base comfort score

        // Longer events need more comfortable clothes
        if eventDuration > 4 {
            score = avgComfort * 3
        }

        return min(10, score)
    }

    private func calculateVersatilityScore(_ combination: OutfitCombination) -> Double {
        let avgVersatility = combination.items.map { Double($0.versatility.rawValue) }.reduce(0, +) / Double(combination.items.count)
        return min(5, avgVersatility)
    }

    private func calculateConditionScore(_ combination: OutfitCombination) -> Double {
        let avgCondition = combination.items.map { Double($0.condition.rawValue) }.reduce(0, +) / Double(combination.items.count)
        return min(5, avgCondition)
    }

    // MARK: - Helper Methods
    private func formalityLevel(for dressCode: DressCode) -> FormalityLevel {
        switch dressCode {
        case .formal: return .formal
        case .business: return .business
        case .businessCasual, .cocktail: return .businessCasual
        case .casual, .comfortable: return .casual
        case .activewear: return .activewear
        case .videocallOptimized: return .businessCasual
        }
    }

    private func isCompatibleWithDressCode(_ item: WardrobeItem, dressCode: DressCode) -> Bool {
        switch dressCode {
        case .formal:
            return item.occasions.contains(.formal) || item.style == .business
        case .business:
            return item.occasions.contains(.work) || item.style == .business
        case .businessCasual:
            return item.occasions.contains(.work) || [.business, .businessCasual, .smart].contains(item.style)
        case .cocktail:
            return item.occasions.contains(.social) || item.occasions.contains(.formal)
        case .casual, .comfortable:
            return item.occasions.contains(.casual) || [.casual, .bohemian, .minimalist].contains(item.style)
        case .activewear:
            return item.category.lowercased().contains("athletic") || item.tags.contains("athletic")
        case .videocallOptimized:
            return item.occasions.contains(.work) && !item.tags.contains("patterned")
        }
    }

    private func isValidCombination(_ items: [WardrobeItem], requirements: OutfitRequirements) -> Bool {
        // Basic validation logic
        return items.count >= 2 // At minimum, need 2 pieces
    }

    private func selectBestOuterwear(
        _ outerwear: [WardrobeItem],
        for combination: OutfitCombination,
        requirements: OutfitRequirements
    ) -> WardrobeItem? {

        guard !outerwear.isEmpty else { return nil }

        // Filter based on requirements
        let suitable = outerwear.filter { item in
            if let weatherReqs = requirements.weatherConsiderations {
                if weatherReqs.warmth == .high && !item.tags.contains(where: { ["warm", "thick"].contains($0) }) {
                    return false
                }
                if weatherReqs.waterproof && !item.tags.contains("water-resistant") {
                    return false
                }
            }
            return true
        }

        // Return the best match (simplified - could use scoring)
        return suitable.first ?? outerwear.first
    }

    private func selectAccessories(
        _ accessories: [WardrobeItem],
        for combination: OutfitCombination,
        requirements: OutfitRequirements
    ) -> [WardrobeItem] {

        // Simple accessory selection - could be much more sophisticated
        return Array(accessories.prefix(2))
    }

    private func createFallbackOutfit(event: CalendarEvent) -> PlannedOutfit {
        // Create a basic fallback when no good combinations are found
        return PlannedOutfit(
            id: UUID(),
            eventId: event.id,
            eventType: event.eventType,
            dressCode: event.dressCode,
            items: [], // Would need basic items
            confidence: 0.3,
            reasoning: ["No suitable combinations found - consider adding more wardrobe pieces"],
            weatherConsiderations: [],
            alternatives: [],
            createdAt: Date(),
            eventDate: event.startDate
        )
    }

    private func generateOutfitReasoning(_ combination: OutfitCombination, event: CalendarEvent, score: Double) -> [String] {
        var reasoning: [String] = []

        if score > 80 {
            reasoning.append("Excellent match for \(event.eventType.rawValue)")
        } else if score > 60 {
            reasoning.append("Good fit for the occasion")
        } else {
            reasoning.append("Acceptable choice with room for improvement")
        }

        // Add specific reasoning based on event type
        switch event.eventType {
        case .videoCall:
            reasoning.append("Optimized for video calls with solid colors and professional upper body focus")
        case .jobInterview:
            reasoning.append("Professional and conservative styling for the best first impression")
        case .dateNight:
            reasoning.append("Elegant and flattering combination for a memorable evening")
        default:
            break
        }

        return reasoning
    }

    private func generateWeatherNotes(_ weather: WeatherForecast) -> [String] {
        var notes: [String] = []

        if weather.temperature < 10 {
            notes.append("Bundle up - it's cold outside!")
        } else if weather.temperature > 25 {
            notes.append("Stay cool with breathable fabrics")
        }

        if weather.precipitationChance > 60 {
            notes.append("Don't forget an umbrella - high chance of rain")
        }

        return notes
    }
}

// MARK: - Supporting Classes
class ColorMatcher {
    func calculateHarmony(colors: [String]) -> Double {
        // Simplified color harmony calculation
        // In a real implementation, this would use color theory

        let harmonicCombinations = [
            ["black", "white"],
            ["navy", "white"],
            ["gray", "black"],
            ["brown", "cream"],
            ["blue", "gray"]
        ]

        for combination in harmonicCombinations {
            if Set(colors.prefix(2)).isSubset(of: Set(combination)) {
                return 1.0
            }
        }

        return 0.7 // Neutral score
    }
}

class FitAnalyzer {
    func analyzeFit(_ items: [WardrobeItem]) -> FitAnalysis {
        return FitAnalysis(
            overallFit: .good,
            recommendations: [],
            concerns: []
        )
    }
}

class WardrobeAnalyzer {
    func analyzeWardrobeGaps(_ items: [WardrobeItem]) -> [WardrobeGap] {
        return []
    }
}

// MARK: - Supporting Models
struct OutfitRequirements {
    var dressCode: DressCode = .casual
    var formality: FormalityLevel = .casual
    var videoCallOptimized: Bool = false
    var focusArea: FocusArea = .fullBody
    var conservativeStyle: Bool = false
    var professional: Bool = false
    var specialOccasion: Bool = false
    var activewear: Bool = false
    var comfort: ComfortLevel = .medium
    var confidence: ConfidenceLevel = .medium
    var attractiveness: AttractivenessLevel = .medium
    var memorability: MemorabilityLevel = .medium
    var versatility: VersatilityLevel = .medium
    var photoReady: Bool = false
    var wrinkleResistant: Bool = false
    var layerable: Bool = false
    var eveningAppropriate: Bool = false
    var relaxed: Bool = false
    var functionality: FunctionalityLevel = .medium
    var breathable: Bool = false
    var lightColors: Bool = false
    var windResistant: Bool = false

    var style: StylePreference = .any
    var preferredColors: [String] = []
    var avoidColors: [String] = []
    var avoidPatterns: [String] = []
    var mustHaveItems: [String] = []
    var suggestedItems: [String] = []
    var avoidItems: [String] = []

    var weatherConsiderations: WeatherRequirements?
}

struct WeatherRequirements {
    var warmth: WarmthLevel = .medium
    var waterproof: Bool = false
    var windResistant: Bool = false
    var breathable: Bool = false
    var lightColors: Bool = false
    var layers: [String] = []
    var mustHaveItems: [String] = []
    var suggestedItems: [String] = []
    var avoidItems: [String] = []
}

struct OutfitCombination {
    var items: [WardrobeItem]
    var score: Double
    var reasoning: [String]
}

struct ScoredOutfitCombination {
    let combination: OutfitCombination
    let score: Double
    let reasoning: [String]
}

struct PlannedOutfit: Identifiable {
    let id: UUID
    let eventId: String
    let eventType: EventType
    let dressCode: DressCode
    let items: [WardrobeItem]
    let confidence: Double
    let reasoning: [String]
    let weatherConsiderations: [String]
    let alternatives: [WardrobeItem]
    let createdAt: Date
    let eventDate: Date?
}

struct OutfitHistory {
    let outfit: PlannedOutfit
    let eventId: String
    let wornDate: Date
    let rating: Double?
    let feedback: String?
}

struct FitAnalysis {
    let overallFit: FitQuality
    let recommendations: [String]
    let concerns: [String]
}

// MARK: - Enums
enum FormalityLevel: Int, CaseIterable {
    case activewear = 1
    case casual = 2
    case businessCasual = 3
    case business = 4
    case formal = 5
}

enum FocusArea {
    case upperBody
    case lowerBody
    case fullBody
}

enum ComfortLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case maximum = 4
}

enum ConfidenceLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum AttractivenessLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum MemorabilityLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum VersatilityLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum FunctionalityLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum WarmthLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum StylePreference {
    case any
    case romantic
    case professional
    case casual
    case edgy
    case bohemian
    case minimalist
    case classic
}

enum FitQuality: Int, CaseIterable {
    case poor = 1
    case acceptable = 2
    case good = 3
    case excellent = 4
}

// MARK: - Wardrobe Item Model
struct WardrobeItem: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let subcategory: String
    let color: String
    let brand: String
    let size: String
    let purchasePrice: Double
    let purchaseDate: Date
    let tags: [String]
    let style: OutfitStyle
    let season: [Season]
    let occasions: [Occasion]
    let bodyFit: BodyFit
    let comfort: ComfortLevel
    let versatility: VersatilityLevel
    let condition: ItemCondition
    let lastWorn: Date?
    let timesWorn: Int
    let averageRating: Double
    let imageURL: String?
}

enum OutfitStyle: CaseIterable {
    case casual
    case business
    case businessCasual
    case formal
    case bohemian
    case minimalist
    case modern
    case classic
    case smart
}

enum Season: CaseIterable {
    case spring
    case summer
    case fall
    case winter
}

enum Occasion: CaseIterable {
    case work
    case casual
    case formal
    case social
    case athletic
}

enum BodyFit: CaseIterable {
    case loose
    case relaxed
    case fitted
    case tailored
}

enum ItemCondition: Int, CaseIterable {
    case poor = 1
    case fair = 2
    case good = 3
    case excellent = 4
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var planner = SmartOutfitPlanner()

        var body: some View {
            Text("Smart Outfit Planner")
                .task {
                    let sampleEvent = CalendarEvent(
                        id: "preview",
                        title: "Important Meeting",
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(3600),
                        location: "Office",
                        isAllDay: false,
                        eventType: .workMeeting,
                        dressCode: .businessCasual,
                        importance: .high,
                        isVideoCall: false,
                        attendeeCount: 5,
                        notes: nil
                    )

                    let _ = await planner.suggestOutfit(
                        for: sampleEvent,
                        weather: nil,
                        previousOutfits: []
                    )
                }
        }
    }

    return PreviewWrapper()
}