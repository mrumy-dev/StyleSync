import Foundation
import AppIntents
import SwiftUI

struct RateMyOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Rate My Outfit"
    static var description = IntentDescription("Rate your current outfit and get feedback from AI")

    static var parameterSummary: some ParameterSummary {
        Summary("Rate my outfit \(\.$rating) stars") {
            \.$includePhoto
            \.$category
            \.$notes
        }
    }

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Rating", description: "Rate your outfit from 1 to 5 stars", default: 5)
    var rating: Int

    @Parameter(title: "Include Photo", description: "Take a photo of your outfit", default: true)
    var includePhoto: Bool

    @Parameter(title: "Category", description: "Outfit category or occasion")
    var category: OutfitCategory?

    @Parameter(title: "Notes", description: "Any additional notes about your outfit")
    var notes: String?

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {

        let outfitRating = OutfitRating(
            rating: max(1, min(5, rating)),
            includePhoto: includePhoto,
            category: category ?? .casual,
            notes: notes,
            timestamp: Date()
        )

        let analysisResult = await OutfitAnalysisService.shared.analyzeOutfit(outfitRating)

        let dialog: IntentDialog
        let snippet: RateOutfitResultView

        switch analysisResult.feedback.sentiment {
        case .positive:
            dialog = IntentDialog("Great choice! Your outfit scored \(rating) stars. \(analysisResult.feedback.message)")
        case .neutral:
            dialog = IntentDialog("Nice outfit! You rated it \(rating) stars. \(analysisResult.feedback.message)")
        case .needsImprovement:
            dialog = IntentDialog("You rated your outfit \(rating) stars. \(analysisResult.feedback.message)")
        }

        snippet = RateOutfitResultView(result: analysisResult)

        return .result(
            dialog: dialog,
            view: snippet
        )
    }
}

enum OutfitCategory: String, CaseIterable, AppEnum {
    case casual = "casual"
    case business = "business"
    case formal = "formal"
    case workout = "workout"
    case evening = "evening"
    case weekend = "weekend"
    case date = "date"
    case travel = "travel"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Outfit Category")

    static var caseDisplayRepresentations: [OutfitCategory: DisplayRepresentation] = [
        .casual: DisplayRepresentation(title: "Casual", subtitle: "Everyday wear"),
        .business: DisplayRepresentation(title: "Business", subtitle: "Work or professional"),
        .formal: DisplayRepresentation(title: "Formal", subtitle: "Special events"),
        .workout: DisplayRepresentation(title: "Workout", subtitle: "Exercise or gym"),
        .evening: DisplayRepresentation(title: "Evening", subtitle: "Night out"),
        .weekend: DisplayRepresentation(title: "Weekend", subtitle: "Relaxed weekend style"),
        .date: DisplayRepresentation(title: "Date", subtitle: "Date night"),
        .travel: DisplayRepresentation(title: "Travel", subtitle: "Travel comfort")
    ]

    var icon: String {
        switch self {
        case .casual: return "tshirt.fill"
        case .business: return "briefcase.fill"
        case .formal: return "suit.fill"
        case .workout: return "figure.run"
        case .evening: return "moon.stars.fill"
        case .weekend: return "sun.max.fill"
        case .date: return "heart.fill"
        case .travel: return "airplane"
        }
    }

    var color: Color {
        switch self {
        case .casual: return .blue
        case .business: return .gray
        case .formal: return .black
        case .workout: return .green
        case .evening: return .purple
        case .weekend: return .orange
        case .date: return .pink
        case .travel: return .cyan
        }
    }
}

struct OutfitRating {
    let rating: Int
    let includePhoto: Bool
    let category: OutfitCategory
    let notes: String?
    let timestamp: Date
}

struct OutfitAnalysisResult {
    let rating: Int
    let feedback: OutfitFeedback
    let suggestions: [StyleSuggestion]
    let colorAnalysis: ColorAnalysis
    let fitAnalysis: FitAnalysis
    let styleScore: StyleScore
}

struct OutfitFeedback {
    let message: String
    let sentiment: FeedbackSentiment
    let tips: [String]
}

enum FeedbackSentiment {
    case positive
    case neutral
    case needsImprovement
}

struct StyleSuggestion {
    let title: String
    let description: String
    let priority: SuggestionPriority
    let category: String
}

enum SuggestionPriority {
    case high
    case medium
    case low
}

struct ColorAnalysis {
    let dominantColors: [String]
    let harmony: ColorHarmony
    let seasonalFit: String
}

enum ColorHarmony {
    case complementary
    case analogous
    case monochromatic
    case triadic
    case mixed
}

struct FitAnalysis {
    let overall: String
    let silhouette: String
    let proportions: String
}

struct StyleScore {
    let overall: Double
    let creativity: Double
    let appropriateness: Double
    let coordination: Double
}

class OutfitAnalysisService {
    static let shared = OutfitAnalysisService()

    func analyzeOutfit(_ rating: OutfitRating) async -> OutfitAnalysisResult {

        await Task.sleep(nanoseconds: 1_000_000_000)

        let feedback: OutfitFeedback
        let suggestions: [StyleSuggestion]

        switch rating.rating {
        case 5:
            feedback = OutfitFeedback(
                message: "You're absolutely glowing in this outfit! The color coordination and fit are on point.",
                sentiment: .positive,
                tips: ["Save this combination as a favorite", "Consider similar color palettes for future outfits"]
            )
            suggestions = [
                StyleSuggestion(title: "Document this win", description: "Save this outfit for future reference", priority: .high, category: "Organization"),
                StyleSuggestion(title: "Try variations", description: "Experiment with similar styles in different colors", priority: .medium, category: "Exploration")
            ]

        case 4:
            feedback = OutfitFeedback(
                message: "Looking great! This outfit works well for the occasion and shows your personal style.",
                sentiment: .positive,
                tips: ["One small accessory could elevate this look", "The proportions are working well for you"]
            )
            suggestions = [
                StyleSuggestion(title: "Add a statement piece", description: "Try a bold necklace or watch", priority: .medium, category: "Accessories"),
                StyleSuggestion(title: "Experiment with textures", description: "Mix in different fabric textures", priority: .low, category: "Styling")
            ]

        case 3:
            feedback = OutfitFeedback(
                message: "A solid choice! There's room to enhance this look with some small adjustments.",
                sentiment: .neutral,
                tips: ["Consider the color balance", "Check if accessories match the formality level"]
            )
            suggestions = [
                StyleSuggestion(title: "Color coordination", description: "Try adding a complementary accent color", priority: .high, category: "Colors"),
                StyleSuggestion(title: "Proportion check", description: "Ensure the top and bottom balance well", priority: .medium, category: "Fit")
            ]

        case 2:
            feedback = OutfitFeedback(
                message: "Let's work on elevating this look! Small changes can make a big difference.",
                sentiment: .needsImprovement,
                tips: ["Focus on fit first, then accessories", "Consider the occasion and dress appropriately"]
            )
            suggestions = [
                StyleSuggestion(title: "Fit adjustment", description: "Check if pieces need tailoring", priority: .high, category: "Fit"),
                StyleSuggestion(title: "Style consultation", description: "Try the AI stylist for personalized advice", priority: .high, category: "Guidance")
            ]

        default: // 1
            feedback = OutfitFeedback(
                message: "Everyone has off days! Let's find what works better for you.",
                sentiment: .needsImprovement,
                tips: ["Start with basics that fit well", "Build from pieces you feel confident in"]
            )
            suggestions = [
                StyleSuggestion(title: "Back to basics", description: "Try a simple, well-fitting combination", priority: .high, category: "Foundation"),
                StyleSuggestion(title: "Personal style quiz", description: "Rediscover your style preferences", priority: .medium, category: "Discovery")
            ]
        }

        return OutfitAnalysisResult(
            rating: rating.rating,
            feedback: feedback,
            suggestions: suggestions,
            colorAnalysis: ColorAnalysis(
                dominantColors: ["Navy", "White", "Brown"],
                harmony: .complementary,
                seasonalFit: "Autumn"
            ),
            fitAnalysis: FitAnalysis(
                overall: "Well-fitted",
                silhouette: "Balanced",
                proportions: "Flattering"
            ),
            styleScore: StyleScore(
                overall: Double(rating.rating) / 5.0,
                creativity: 0.8,
                appropriateness: 0.9,
                coordination: 0.7
            )
        )
    }
}

struct RateOutfitResultView: View {
    let result: OutfitAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outfit Rating")
                        .font(.headline)
                        .fontWeight(.bold)

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= result.rating ? "star.fill" : "star")
                                .foregroundColor(star <= result.rating ? .yellow : .gray)
                                .font(.title2)
                        }

                        Text("(\(result.rating)/5)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Style Score")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(result.styleScore.overall * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }


            VStack(alignment: .leading, spacing: 8) {
                Text("AI Feedback")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(result.feedback.message)
                    .font(.body)
                    .foregroundColor(.primary)
            }


            if !result.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(result.suggestions.prefix(2), id: \.title) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(suggestion.priority == .high ? Color.red : (suggestion.priority == .medium ? Color.orange : Color.green))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text(suggestion.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}