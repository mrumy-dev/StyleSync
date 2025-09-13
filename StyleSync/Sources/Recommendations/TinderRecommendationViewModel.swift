import SwiftUI
import Combine

// Data Models
struct RecommendationResult: Identifiable {
    let id = UUID()
    let product: Product
    let score: RecommendationScore
    let reasoning: RecommendationReasoning
    let rank: Int
    let category: Category
    let explanation: DetailedExplanation

    enum Category: String {
        case trending
        case personalized
        case similar
        case contextual
        case discovery
    }
}

struct RecommendationScore {
    let overall: Double
    let breakdown: ScoreBreakdown
    let confidence: Double
    let explanation: ScoreExplanation

    struct ScoreBreakdown {
        let collaborative: Double
        let contentBased: Double
        let contextual: Double
        let deepLearning: Double
        let reinforcement: Double
    }

    struct ScoreExplanation {
        let primary: String
        let factors: [String]
        let confidence: Double
        let alternatives: [String]?
    }
}

struct RecommendationReasoning {
    let whyRecommended: [String]
    let styleRules: [String]
    let personalizationFactors: [String]
    let visualExplanation: String?
    let abTestGroup: String?
}

struct DetailedExplanation {
    let primary: String
    let secondary: [String]
    let confidence: Double
    let factorBreakdown: [ExplanationFactor]
    let visualExplanation: VisualExplanation
    let feedbackQuestions: [FeedbackQuestion]

    struct ExplanationFactor {
        let factor: String
        let contribution: Double
        let explanation: String
        let confidence: Double
    }

    struct VisualExplanation {
        let type: String
        let data: [String: Any]
        let imageUrl: String?
    }

    struct FeedbackQuestion {
        let question: String
        let type: QuestionType
        let options: [String]?
        let importance: Importance

        enum QuestionType {
            case rating, binary, multipleChoice, text
        }

        enum Importance {
            case high, medium, low
        }
    }
}

struct RecommendationFilters {
    var priceRange: ClosedRange<Double> = 0...1000
    var brands: Set<String> = []
    var categories: Set<String> = []
    var colors: Set<String> = []
    var sizes: Set<String> = []
    var sustainabilityScore: Double = 0
    var onlyInStock: Bool = true
    var includeOnSale: Bool = false
    var excludeRecent: Bool = true
}

@MainActor
class TinderRecommendationViewModel: ObservableObject {
    @Published var recommendations: [RecommendationResult] = []
    @Published var currentProduct: Product?
    @Published var isLoading = false
    @Published var filters = RecommendationFilters()

    private var cancellables = Set<AnyCancellable>()
    private var currentMode: TinderStyleRecommendationView.RecommendationMode = .smart

    // Mock data - in real app would connect to AI recommendation service
    private let mockProducts: [Product] = [
        Product(
            id: "1",
            name: "Elegant Summer Dress with Floral Pattern",
            brand: "Zara",
            currentPrice: 79.99,
            originalPrice: 99.99,
            imageUrl: "https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=800",
            store: "Zara",
            inStock: true,
            colors: ["#FFB6C1", "#98FB98", "#87CEEB"],
            onSale: true,
            salePercentage: 20,
            sustainabilityScore: 8,
            rating: 4.5
        ),
        Product(
            id: "2",
            name: "Classic White Button-Down Shirt",
            brand: "Uniqlo",
            currentPrice: 39.99,
            originalPrice: nil,
            imageUrl: "https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800",
            store: "Uniqlo",
            inStock: true,
            colors: ["#FFFFFF", "#F0F0F0"],
            onSale: false,
            salePercentage: nil,
            sustainabilityScore: 6,
            rating: 4.2
        ),
        Product(
            id: "3",
            name: "Trendy High-Waisted Jeans",
            brand: "Levi's",
            currentPrice: 89.99,
            originalPrice: nil,
            imageUrl: "https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=800",
            store: "Levi's",
            inStock: true,
            colors: ["#4169E1", "#000080"],
            onSale: false,
            salePercentage: nil,
            sustainabilityScore: 7,
            rating: 4.7
        ),
        Product(
            id: "4",
            name: "Luxury Cashmere Sweater",
            brand: "COS",
            currentPrice: 159.99,
            originalPrice: 199.99,
            imageUrl: "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800",
            store: "COS",
            inStock: true,
            colors: ["#F5DEB3", "#D2B48C", "#BC8F8F"],
            onSale: true,
            salePercentage: 20,
            sustainabilityScore: 9,
            rating: 4.8
        ),
        Product(
            id: "5",
            name: "Bohemian Maxi Skirt",
            brand: "Free People",
            currentPrice: 98.00,
            originalPrice: nil,
            imageUrl: "https://images.unsplash.com/photo-1583744946564-b52ac1c389c8?w=800",
            store: "Free People",
            inStock: false,
            colors: ["#DDA0DD", "#F0E68C", "#FFA07A"],
            onSale: false,
            salePercentage: nil,
            sustainabilityScore: 5,
            rating: 4.3
        ),
        Product(
            id: "6",
            name: "Athletic Running Shoes",
            brand: "Nike",
            currentPrice: 129.99,
            originalPrice: 149.99,
            imageUrl: "https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800",
            store: "Nike",
            inStock: true,
            colors: ["#000000", "#FFFFFF", "#FF6347"],
            onSale: true,
            salePercentage: 13,
            sustainabilityScore: 4,
            rating: 4.6
        )
    ]

    var currentRecommendation: RecommendationResult? {
        recommendations.last
    }

    init() {
        setupFilterObserver()
    }

    func loadRecommendations(mode: TinderStyleRecommendationView.RecommendationMode) {
        currentMode = mode
        isLoading = true

        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.generateMockRecommendations(for: mode)
            self.isLoading = false
        }
    }

    private func generateMockRecommendations(for mode: TinderStyleRecommendationView.RecommendationMode) {
        var filteredProducts = mockProducts

        // Apply filters
        if filters.onlyInStock {
            filteredProducts = filteredProducts.filter { $0.inStock }
        }

        if filters.includeOnSale {
            filteredProducts = filteredProducts.filter { $0.onSale }
        }

        filteredProducts = filteredProducts.filter {
            $0.currentPrice >= filters.priceRange.lowerBound &&
            $0.currentPrice <= filters.priceRange.upperBound
        }

        if !filters.brands.isEmpty {
            filteredProducts = filteredProducts.filter { filters.brands.contains($0.brand) }
        }

        if filters.sustainabilityScore > 0 {
            filteredProducts = filteredProducts.filter { $0.sustainabilityScore >= Int(filters.sustainabilityScore) }
        }

        // Generate recommendations based on mode
        recommendations = filteredProducts.shuffled().prefix(10).enumerated().map { index, product in
            generateRecommendationResult(for: product, mode: mode, rank: index + 1)
        }

        if let first = recommendations.first {
            currentProduct = first.product
        }
    }

    private func generateRecommendationResult(
        for product: Product,
        mode: TinderStyleRecommendationView.RecommendationMode,
        rank: Int
    ) -> RecommendationResult {
        let category: RecommendationResult.Category
        let baseScore: Double
        let confidence: Double

        switch mode {
        case .smart:
            category = .personalized
            baseScore = Double.random(in: 0.7...0.95)
            confidence = Double.random(in: 0.75...0.9)
        case .inspiration:
            category = .discovery
            baseScore = Double.random(in: 0.6...0.85)
            confidence = Double.random(in: 0.6...0.8)
        case .similar:
            category = .similar
            baseScore = Double.random(in: 0.8...0.95)
            confidence = Double.random(in: 0.8...0.95)
        case .trending:
            category = .trending
            baseScore = Double.random(in: 0.65...0.85)
            confidence = Double.random(in: 0.7...0.85)
        case .random:
            category = .discovery
            baseScore = Double.random(in: 0.4...0.8)
            confidence = Double.random(in: 0.5...0.7)
        default:
            category = .contextual
            baseScore = Double.random(in: 0.6...0.9)
            confidence = Double.random(in: 0.65...0.85)
        }

        let score = RecommendationScore(
            overall: baseScore,
            breakdown: RecommendationScore.ScoreBreakdown(
                collaborative: Double.random(in: 0...1),
                contentBased: Double.random(in: 0...1),
                contextual: Double.random(in: 0...1),
                deepLearning: Double.random(in: 0...1),
                reinforcement: Double.random(in: 0...1)
            ),
            confidence: confidence,
            explanation: RecommendationScore.ScoreExplanation(
                primary: generatePrimaryExplanation(for: product, mode: mode),
                factors: generateFactors(for: product, mode: mode),
                confidence: confidence,
                alternatives: nil
            )
        )

        let reasoning = RecommendationReasoning(
            whyRecommended: generateWhyRecommended(for: product, mode: mode),
            styleRules: generateStyleRules(for: product),
            personalizationFactors: generatePersonalizationFactors(for: product),
            visualExplanation: "This item complements your style preferences",
            abTestGroup: "explanation_detailed_v2"
        )

        let explanation = generateDetailedExplanation(for: product, score: score, mode: mode)

        return RecommendationResult(
            product: product,
            score: score,
            reasoning: reasoning,
            rank: rank,
            category: category,
            explanation: explanation
        )
    }

    private func generatePrimaryExplanation(
        for product: Product,
        mode: TinderStyleRecommendationView.RecommendationMode
    ) -> String {
        switch mode {
        case .smart:
            return "AI analysis shows this is a perfect match for your style"
        case .inspiration:
            return "Discover something new that matches your aesthetic"
        case .similar:
            return "Similar to items you've liked before"
        case .trending:
            return "Currently trending among users with your style"
        case .random:
            return "A surprise pick that might become your new favorite"
        default:
            return "Great choice based on your current context"
        }
    }

    private func generateFactors(
        for product: Product,
        mode: TinderStyleRecommendationView.RecommendationMode
    ) -> [String] {
        var factors = ["Price match", "Style preference", "Brand compatibility"]

        if product.sustainabilityScore > 7 {
            factors.append("Eco-friendly")
        }

        if product.onSale {
            factors.append("On sale")
        }

        if product.rating > 4.5 {
            factors.append("Highly rated")
        }

        return factors.shuffled().prefix(3).map { String($0) }
    }

    private func generateWhyRecommended(
        for product: Product,
        mode: TinderStyleRecommendationView.RecommendationMode
    ) -> [String] {
        var reasons: [String] = []

        switch mode {
        case .smart:
            reasons.append("Perfect match based on your shopping history")
            if product.sustainabilityScore > 7 {
                reasons.append("Meets your sustainability preferences")
            }
        case .inspiration:
            reasons.append("Expands your style horizons")
            reasons.append("Trending in your demographic")
        case .similar:
            reasons.append("Similar to your favorite items")
            reasons.append("From a brand you trust")
        case .trending:
            reasons.append("Popular among style-conscious users")
            reasons.append("Featured in recent fashion content")
        default:
            reasons.append("Fits your current needs")
        }

        if product.onSale {
            reasons.append("Great value at current price")
        }

        return reasons
    }

    private func generateStyleRules(for product: Product) -> [String] {
        let rules = [
            "Versatile piece for multiple occasions",
            "Classic design with modern touches",
            "Premium quality construction",
            "Timeless style that won't go out of fashion",
            "Perfect for layering and mixing",
            "Statement piece that elevates any outfit"
        ]
        return Array(rules.shuffled().prefix(2))
    }

    private func generatePersonalizationFactors(for product: Product) -> [String] {
        let factors = [
            "Matches your color preferences",
            "Within your preferred price range",
            "From a brand you've shown interest in",
            "Fits your lifestyle and activities",
            "Aligns with your sustainability values",
            "Complements your existing wardrobe"
        ]
        return Array(factors.shuffled().prefix(3))
    }

    private func generateDetailedExplanation(
        for product: Product,
        score: RecommendationScore,
        mode: TinderStyleRecommendationView.RecommendationMode
    ) -> DetailedExplanation {
        DetailedExplanation(
            primary: score.explanation.primary,
            secondary: [
                "High-quality materials and construction",
                "Versatile styling options",
                "Positive user reviews and ratings"
            ],
            confidence: score.confidence,
            factorBreakdown: [
                DetailedExplanation.ExplanationFactor(
                    factor: "Style Match",
                    contribution: 0.35,
                    explanation: "Aligns perfectly with your aesthetic preferences",
                    confidence: 0.9
                ),
                DetailedExplanation.ExplanationFactor(
                    factor: "Price Value",
                    contribution: 0.25,
                    explanation: "Great value within your budget range",
                    confidence: 0.85
                ),
                DetailedExplanation.ExplanationFactor(
                    factor: "Quality Score",
                    contribution: 0.2,
                    explanation: "High-quality construction and materials",
                    confidence: 0.8
                ),
                DetailedExplanation.ExplanationFactor(
                    factor: "Context Fit",
                    contribution: 0.2,
                    explanation: "Perfect for your current needs and occasions",
                    confidence: 0.75
                )
            ],
            visualExplanation: DetailedExplanation.VisualExplanation(
                type: "style_match",
                data: ["style_score": 0.9, "color_harmony": 0.85],
                imageUrl: nil
            ),
            feedbackQuestions: [
                DetailedExplanation.FeedbackQuestion(
                    question: "How helpful was this explanation?",
                    type: .rating,
                    options: nil,
                    importance: .high
                ),
                DetailedExplanation.FeedbackQuestion(
                    question: "Does this match your style?",
                    type: .binary,
                    options: ["Yes", "No"],
                    importance: .high
                ),
                DetailedExplanation.FeedbackQuestion(
                    question: "What factors matter most to you?",
                    type: .multipleChoice,
                    options: ["Price", "Style", "Brand", "Quality", "Sustainability"],
                    importance: .medium
                )
            ]
        )
    }

    func handleSwipe(direction: SwipeDirection, for recommendation: RecommendationResult) {
        // Record user feedback
        recordSwipeFeedback(direction: direction, recommendation: recommendation)

        // Remove the swiped recommendation
        recommendations.removeAll { $0.id == recommendation.id }

        // Update current product
        currentProduct = recommendations.last?.product

        // Load more recommendations if running low
        if recommendations.count < 3 {
            loadMoreRecommendations()
        }
    }

    private func recordSwipeFeedback(direction: SwipeDirection, recommendation: RecommendationResult) {
        let feedback: String
        switch direction {
        case .left:
            feedback = "dislike"
        case .right:
            feedback = "like"
        case .up:
            feedback = "save"
        case .down:
            feedback = "info_requested"
        }

        // In real app, this would send feedback to the AI system
        print("Recorded feedback: \(feedback) for product: \(recommendation.product.name)")

        // Simulate learning from feedback
        Task {
            await simulatePersonalizationUpdate(feedback: feedback, product: recommendation.product)
        }
    }

    private func simulatePersonalizationUpdate(feedback: String, product: Product) async {
        // Simulate AI learning delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // In real app, this would update user preferences and retrain models
        print("Updated personalization model based on \(feedback) feedback")
    }

    private func loadMoreRecommendations() {
        // In real app, this would fetch more recommendations from the server
        let newProducts = mockProducts.shuffled().prefix(5)

        let newRecommendations = newProducts.enumerated().map { index, product in
            generateRecommendationResult(
                for: product,
                mode: currentMode,
                rank: recommendations.count + index + 1
            )
        }

        recommendations.append(contentsOf: newRecommendations)
    }

    private func setupFilterObserver() {
        // Observe filter changes and reload recommendations
        $filters
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadRecommendations(mode: self?.currentMode ?? .smart)
            }
            .store(in: &cancellables)
    }

    func refreshRecommendations() {
        loadRecommendations(mode: currentMode)
    }

    func markAsFavorite(_ product: Product) {
        // In real app, would save to user favorites
        print("Added to favorites: \(product.name)")
    }

    func reportProduct(_ product: Product, reason: String) {
        // In real app, would report inappropriate content
        print("Reported product: \(product.name) - Reason: \(reason)")
    }
}