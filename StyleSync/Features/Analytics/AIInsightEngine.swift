import Foundation
import SwiftUI

@MainActor
class AIInsightEngine: ObservableObject {
    @Published var isAnalyzing = false

    func generateInsights() async -> [AIInsight] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Simulate AI analysis
        await Task.sleep(nanoseconds: 2_000_000_000)

        return [
            generateUnderutilizedItemsInsight(),
            generateMissingPiecesInsight(),
            generateInvestmentRecommendation(),
            generateDonationSuggestion(),
            generateStylePersonalityInsight(),
            generateSeasonalInsight(),
            generateColorAnalysisInsight(),
            generateSustainabilityInsight()
        ].compactMap { $0 }
    }

    private func generateUnderutilizedItemsInsight() -> AIInsight {
        let underutilizedItems = ["Red silk dress", "White sneakers", "Patterned scarf"]

        return AIInsight(
            id: UUID(),
            type: .underutilizedItems,
            title: "Underutilized Items",
            message: "You have \(underutilizedItems.count) items worn less than 3 times this year. Try styling them with your go-to pieces!",
            confidence: 0.89,
            actionTitle: "Show Items",
            actionData: underutilizedItems,
            priority: .high
        )
    }

    private func generateMissingPiecesInsight() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .missingPieces,
            title: "Wardrobe Gaps",
            message: "A versatile blazer would complete 12 different outfits in your wardrobe. Consider investing in navy or charcoal.",
            confidence: 0.92,
            actionTitle: "Shop Blazers",
            actionData: ["navy blazer", "charcoal blazer"],
            priority: .medium
        )
    }

    private func generateInvestmentRecommendation() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .investmentRecommendation,
            title: "Smart Investment",
            message: "Quality leather boots could replace 3 current shoes and improve 18 outfits. Estimated cost-per-wear: $2.30",
            confidence: 0.87,
            actionTitle: "Find Boots",
            actionData: nil,
            priority: .medium
        )
    }

    private func generateDonationSuggestion() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .donationSuggestion,
            title: "Donation Opportunity",
            message: "5 items haven't been worn in 18 months and don't fit your current style. Consider donating to make space.",
            confidence: 0.84,
            actionTitle: "Review Items",
            actionData: nil,
            priority: .low
        )
    }

    private func generateStylePersonalityInsight() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .stylePersonality,
            title: "Style Evolution",
            message: "Your style has evolved toward 'Classic Minimalist' - 78% of recent outfits feature neutral colors and clean lines.",
            confidence: 0.91,
            actionTitle: "View Analysis",
            actionData: nil,
            priority: .high
        )
    }

    private func generateSeasonalInsight() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .seasonalTrend,
            title: "Seasonal Trend",
            message: "You gravitate toward earth tones in fall. Your brown leather jacket had the highest style scores this season.",
            confidence: 0.88,
            actionTitle: "See Trends",
            actionData: nil,
            priority: .low
        )
    }

    private func generateColorAnalysisInsight() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .colorAnalysis,
            title: "Color Palette",
            message: "Navy blue appears in 68% of your highest-rated outfits. Consider exploring complementary colors like blush pink.",
            confidence: 0.85,
            actionTitle: "Explore Colors",
            actionData: nil,
            priority: .medium
        )
    }

    private func generateSustainabilityInsight() -> AIInsight {
        return AIInsight(
            id: UUID(),
            type: .sustainability,
            title: "Sustainability Score",
            message: "Your cost-per-wear average of $12.34 is excellent! You're maximizing the value of your purchases.",
            confidence: 0.95,
            actionTitle: "View Report",
            actionData: nil,
            priority: .high
        )
    }

    func generateDetailedStyleAnalysis() async -> StylePersonalityReport {
        await Task.sleep(nanoseconds: 1_500_000_000)

        return StylePersonalityReport(
            primaryStyle: "Classic Minimalist",
            confidence: 0.87,
            characteristics: [
                "Prefers neutral color palettes",
                "Values quality over quantity",
                "Gravitates toward timeless pieces",
                "Comfortable with repeated outfits"
            ],
            styleEvolution: [
                StyleEvolutionPoint(period: "Jan-Mar", style: "Experimental", confidence: 0.6),
                StyleEvolutionPoint(period: "Apr-Jun", style: "Casual Chic", confidence: 0.7),
                StyleEvolutionPoint(period: "Jul-Sep", style: "Minimalist", confidence: 0.8),
                StyleEvolutionPoint(period: "Oct-Dec", style: "Classic Minimalist", confidence: 0.87)
            ],
            colorPreferences: generateColorPreferences(),
            categoryPreferences: generateCategoryPreferences(),
            recommendations: [
                "Continue building your capsule wardrobe",
                "Invest in quality basics in your core colors",
                "Consider adding one statement piece per season"
            ]
        )
    }

    private func generateColorPreferences() -> [ColorPreference] {
        [
            ColorPreference(color: "Navy Blue", frequency: 0.28, sentiment: 0.92),
            ColorPreference(color: "Black", frequency: 0.25, sentiment: 0.88),
            ColorPreference(color: "White", frequency: 0.22, sentiment: 0.85),
            ColorPreference(color: "Gray", frequency: 0.15, sentiment: 0.79),
            ColorPreference(color: "Camel", frequency: 0.10, sentiment: 0.91)
        ]
    }

    private func generateCategoryPreferences() -> [CategoryPreference] {
        [
            CategoryPreference(category: "Outerwear", satisfaction: 0.94, frequency: 0.35),
            CategoryPreference(category: "Bottoms", satisfaction: 0.88, frequency: 0.28),
            CategoryPreference(category: "Tops", satisfaction: 0.82, frequency: 0.25),
            CategoryPreference(category: "Shoes", satisfaction: 0.86, frequency: 0.12)
        ]
    }
}

// MARK: - AI Insight Types
struct AIInsight: Identifiable {
    let id: UUID
    let type: AIInsightType
    let title: String
    let message: String
    let confidence: Double
    let actionTitle: String?
    let actionData: Any?
    let priority: InsightPriority
}

enum AIInsightType: CaseIterable {
    case underutilizedItems
    case missingPieces
    case investmentRecommendation
    case donationSuggestion
    case stylePersonality
    case seasonalTrend
    case colorAnalysis
    case sustainability

    var title: String {
        switch self {
        case .underutilizedItems: return "Underutilized"
        case .missingPieces: return "Missing Pieces"
        case .investmentRecommendation: return "Investment"
        case .donationSuggestion: return "Declutter"
        case .stylePersonality: return "Style DNA"
        case .seasonalTrend: return "Seasonal"
        case .colorAnalysis: return "Color Palette"
        case .sustainability: return "Sustainability"
        }
    }

    var icon: String {
        switch self {
        case .underutilizedItems: return "exclamationmark.triangle.fill"
        case .missingPieces: return "plus.circle.fill"
        case .investmentRecommendation: return "dollarsign.circle.fill"
        case .donationSuggestion: return "heart.circle.fill"
        case .stylePersonality: return "person.crop.circle.fill"
        case .seasonalTrend: return "leaf.circle.fill"
        case .colorAnalysis: return "paintpalette.fill"
        case .sustainability: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .underutilizedItems: return .orange
        case .missingPieces: return .blue
        case .investmentRecommendation: return .green
        case .donationSuggestion: return .pink
        case .stylePersonality: return .purple
        case .seasonalTrend: return .brown
        case .colorAnalysis: return .indigo
        case .sustainability: return .mint
        }
    }
}

enum InsightPriority: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Style Analysis Models
struct StylePersonalityReport {
    let primaryStyle: String
    let confidence: Double
    let characteristics: [String]
    let styleEvolution: [StyleEvolutionPoint]
    let colorPreferences: [ColorPreference]
    let categoryPreferences: [CategoryPreference]
    let recommendations: [String]
}

struct StyleEvolutionPoint {
    let period: String
    let style: String
    let confidence: Double
}

struct ColorPreference {
    let color: String
    let frequency: Double // How often worn
    let sentiment: Double // How much liked (based on ratings)
}

struct CategoryPreference {
    let category: String
    let satisfaction: Double
    let frequency: Double
}

// MARK: - Wardrobe Analysis Engine
class WardrobeAnalysisEngine {
    static func analyzeWardrobeGaps(_ items: [WardrobeItem]) -> [WardrobeGap] {
        var gaps: [WardrobeGap] = []

        // Analyze missing versatile pieces
        if !items.contains(where: { $0.category == "Blazers" }) {
            gaps.append(WardrobeGap(
                type: .missingBasic,
                item: "Versatile Blazer",
                reason: "Would complete 12+ outfits",
                priority: .high,
                suggestedColors: ["Navy", "Charcoal", "Black"]
            ))
        }

        // Analyze seasonal gaps
        let currentSeason = getCurrentSeason()
        let seasonalItems = items.filter { isSeasonalItem($0, for: currentSeason) }

        if seasonalItems.count < 5 {
            gaps.append(WardrobeGap(
                type: .seasonalGap,
                item: "\(currentSeason) essentials",
                reason: "Limited options for current season",
                priority: .medium,
                suggestedColors: getSeasonalColors(for: currentSeason)
            ))
        }

        return gaps
    }

    static func identifyUnderutilizedItems(_ items: [WardrobeItem]) -> [UnderutilizedItem] {
        return items.compactMap { item in
            if item.wearCount < 3 && item.purchaseDate < Calendar.current.date(byAdding: .month, value: -6, to: Date()) {
                return UnderutilizedItem(
                    item: item,
                    lastWorn: item.lastWornDate,
                    suggestions: generateStylingSuggestions(for: item)
                )
            }
            return nil
        }
    }

    static func calculateROIAnalysis(_ items: [WardrobeItem]) -> ROIAnalysis {
        let totalValue = items.reduce(0) { $0 + $1.purchasePrice }
        let totalWears = items.reduce(0) { $0 + $1.wearCount }
        let averageCostPerWear = totalValue / Double(max(totalWears, 1))

        let bestInvestments = items
            .filter { $0.wearCount > 0 }
            .sorted { ($0.purchasePrice / Double($0.wearCount)) < ($1.purchasePrice / Double($1.wearCount)) }
            .prefix(5)

        let worstInvestments = items
            .filter { $0.wearCount > 0 }
            .sorted { ($0.purchasePrice / Double($0.wearCount)) > ($1.purchasePrice / Double($1.wearCount)) }
            .prefix(5)

        return ROIAnalysis(
            totalInvestment: totalValue,
            averageCostPerWear: averageCostPerWear,
            bestInvestments: Array(bestInvestments),
            worstInvestments: Array(worstInvestments),
            sustainabilityScore: calculateSustainabilityScore(items)
        )
    }

    // MARK: - Helper Methods
    private static func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return "Winter"
        case 3, 4, 5: return "Spring"
        case 6, 7, 8: return "Summer"
        case 9, 10, 11: return "Fall"
        default: return "Spring"
        }
    }

    private static func isSeasonalItem(_ item: WardrobeItem, for season: String) -> Bool {
        // Simple logic - in reality this would be more sophisticated
        switch season {
        case "Winter":
            return item.tags.contains(where: { ["coat", "sweater", "boots", "scarf"].contains($0.lowercased()) })
        case "Summer":
            return item.tags.contains(where: { ["shorts", "sandals", "sundress", "tank"].contains($0.lowercased()) })
        default:
            return true
        }
    }

    private static func getSeasonalColors(for season: String) -> [String] {
        switch season {
        case "Spring": return ["Pastels", "Light Blue", "Pink"]
        case "Summer": return ["White", "Navy", "Bright Colors"]
        case "Fall": return ["Earth Tones", "Burgundy", "Olive"]
        case "Winter": return ["Black", "Charcoal", "Deep Colors"]
        default: return ["Navy", "White", "Black"]
        }
    }

    private static func generateStylingSuggestions(for item: WardrobeItem) -> [String] {
        // AI-generated styling suggestions based on item properties
        var suggestions: [String] = []

        if item.category == "Dresses" {
            suggestions.append("Layer with a denim jacket for casual look")
            suggestions.append("Add ankle boots and a statement necklace")
        } else if item.category == "Blazers" {
            suggestions.append("Wear with jeans for smart-casual")
            suggestions.append("Layer over dresses for professional look")
        }

        return suggestions
    }

    private static func calculateSustainabilityScore(_ items: [WardrobeItem]) -> Double {
        let totalItems = items.count
        let highUsageItems = items.filter { $0.wearCount >= 10 }.count
        let recentPurchases = items.filter {
            $0.purchaseDate > Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        }.count

        // Score based on usage efficiency and buying patterns
        let usageScore = Double(highUsageItems) / Double(totalItems)
        let buyingScore = recentPurchases < 5 ? 1.0 : max(0.0, 1.0 - Double(recentPurchases) / 20.0)

        return (usageScore * 0.7 + buyingScore * 0.3) * 10.0
    }
}

// MARK: - Analysis Result Models
struct WardrobeGap {
    let type: GapType
    let item: String
    let reason: String
    let priority: InsightPriority
    let suggestedColors: [String]

    enum GapType {
        case missingBasic
        case seasonalGap
        case colorGap
        case occasionGap
    }
}

struct UnderutilizedItem {
    let item: WardrobeItem
    let lastWorn: Date?
    let suggestions: [String]
}

struct ROIAnalysis {
    let totalInvestment: Double
    let averageCostPerWear: Double
    let bestInvestments: [WardrobeItem]
    let worstInvestments: [WardrobeItem]
    let sustainabilityScore: Double
}

// MARK: - Sample Wardrobe Item Model
struct WardrobeItem {
    let id: UUID
    let name: String
    let category: String
    let brand: String
    let purchasePrice: Double
    let purchaseDate: Date
    let color: String
    let tags: [String]
    let wearCount: Int
    let lastWornDate: Date?
    let averageRating: Double
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var engine = AIInsightEngine()
        @State private var insights: [AIInsight] = []

        var body: some View {
            NavigationStack {
                List(insights) { insight in
                    AIInsightCard(insight: insight)
                }
                .navigationTitle("AI Insights")
                .task {
                    insights = await engine.generateInsights()
                }
            }
        }
    }

    return PreviewWrapper()
}