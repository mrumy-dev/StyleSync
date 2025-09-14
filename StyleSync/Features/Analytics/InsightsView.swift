import SwiftUI
import Charts
import Foundation

@MainActor
class AnalyticsManager: ObservableObject {
    @Published var wardrobeData: WardrobeAnalytics?
    @Published var insights: [AIInsight] = []
    @Published var yearlyReview: YearlyReview?
    @Published var isLoading = false

    private let aiInsightEngine = AIInsightEngine()

    func loadAnalytics() async {
        isLoading = true

        // Simulate loading real data - in production, this would fetch from Core Data
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.generateWardrobeAnalytics()
            }

            group.addTask {
                await self.generateAIInsights()
            }

            group.addTask {
                await self.generateYearlyReview()
            }
        }

        isLoading = false
    }

    private func generateWardrobeAnalytics() async {
        await Task.sleep(nanoseconds: 1_000_000_000)

        wardrobeData = WardrobeAnalytics(
            totalItems: 124,
            totalValue: 8450.0,
            averageCostPerWear: 12.34,
            mostWornItem: "Black Leather Jacket",
            leastWornItems: ["Red Dress", "White Sneakers", "Blue Scarf"],
            colorDistribution: generateColorDistribution(),
            categoryBreakdown: generateCategoryBreakdown(),
            wearingPatterns: generateWearingPatterns(),
            seasonalTrends: generateSeasonalTrends(),
            costPerWearData: generateCostPerWearData(),
            monthlyReports: generateMonthlyReports()
        )
    }

    private func generateAIInsights() async {
        insights = await aiInsightEngine.generateInsights()
    }

    private func generateYearlyReview() async {
        yearlyReview = YearlyReview(
            year: 2024,
            totalOutfits: 342,
            favoriteColor: "Navy Blue",
            stylePersonality: "Classic Minimalist",
            topAchievements: [
                "Reached 50 cost-per-wear on designer jacket",
                "Discovered new style with earth tones",
                "Built perfect capsule wardrobe"
            ],
            monthlyHighlights: generateMonthlyHighlights(),
            styleEvolution: generateStyleEvolution(),
            sustainabilityScore: 8.4
        )
    }

    // MARK: - Data Generation Methods
    private func generateColorDistribution() -> [ColorData] {
        [
            ColorData(color: "Black", percentage: 28, count: 35),
            ColorData(color: "Navy", percentage: 22, count: 27),
            ColorData(color: "White", percentage: 18, count: 22),
            ColorData(color: "Gray", percentage: 15, count: 19),
            ColorData(color: "Blue", percentage: 10, count: 12),
            ColorData(color: "Other", percentage: 7, count: 9)
        ]
    }

    private func generateCategoryBreakdown() -> [CategoryData] {
        [
            CategoryData(category: "Tops", count: 45, value: 2250),
            CategoryData(category: "Bottoms", count: 28, value: 1680),
            CategoryData(category: "Outerwear", count: 15, value: 2400),
            CategoryData(category: "Shoes", count: 20, value: 1600),
            CategoryData(category: "Accessories", count: 16, value: 520)
        ]
    }

    private func generateWearingPatterns() -> [WearingPattern] {
        let calendar = Calendar.current
        var patterns: [WearingPattern] = []

        // Generate last 365 days of data
        for i in 0..<365 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let weekday = calendar.component(.weekday, from: date)
            let intensity = weekday == 1 || weekday == 7 ?
                Double.random(in: 0...0.3) : Double.random(in: 0.2...1.0)

            patterns.append(WearingPattern(date: date, intensity: intensity))
        }

        return patterns.reversed()
    }

    private func generateSeasonalTrends() -> [SeasonalTrend] {
        [
            SeasonalTrend(season: "Spring", dominantColors: ["Pastel Pink", "Light Blue"], style: "Casual"),
            SeasonalTrend(season: "Summer", dominantColors: ["White", "Navy"], style: "Minimalist"),
            SeasonalTrend(season: "Fall", dominantColors: ["Earth Tones", "Burgundy"], style: "Sophisticated"),
            SeasonalTrend(season: "Winter", dominantColors: ["Black", "Charcoal"], style: "Classic")
        ]
    }

    private func generateCostPerWearData() -> [CostPerWearItem] {
        [
            CostPerWearItem(name: "Black Leather Jacket", cost: 450, wears: 89, costPerWear: 5.06),
            CostPerWearItem(name: "Levi's Jeans", cost: 120, wears: 45, costPerWear: 2.67),
            CostPerWearItem(name: "White T-Shirt", cost: 25, wears: 67, costPerWear: 0.37),
            CostPerWearItem(name: "Designer Heels", cost: 680, wears: 12, costPerWear: 56.67),
            CostPerWearItem(name: "Cashmere Sweater", cost: 280, wears: 24, costPerWear: 11.67)
        ]
    }

    private func generateMonthlyReports() -> [MonthlyReport] {
        var reports: [MonthlyReport] = []
        let calendar = Calendar.current

        for i in 0..<12 {
            let date = calendar.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            reports.append(MonthlyReport(
                month: DateFormatter.monthName.string(from: date),
                outfitsWorn: Int.random(in: 25...35),
                newPurchases: Int.random(in: 2...8),
                totalSpent: Double.random(in: 200...800),
                topCategory: ["Tops", "Shoes", "Accessories"].randomElement() ?? "Tops",
                styleScore: Double.random(in: 7.5...9.5)
            ))
        }

        return reports.reversed()
    }

    private func generateMonthlyHighlights() -> [MonthlyHighlight] {
        [
            MonthlyHighlight(month: "January", highlight: "Mastered monochromatic styling"),
            MonthlyHighlight(month: "February", highlight: "Found perfect date night look"),
            MonthlyHighlight(month: "March", highlight: "Spring wardrobe refresh complete"),
            MonthlyHighlight(month: "April", highlight: "Nailed business casual aesthetic"),
            MonthlyHighlight(month: "May", highlight: "Discovered vintage finds"),
            MonthlyHighlight(month: "June", highlight: "Summer minimalist phase"),
            MonthlyHighlight(month: "July", highlight: "Vacation wardrobe perfected"),
            MonthlyHighlight(month: "August", highlight: "Earth tone exploration"),
            MonthlyHighlight(month: "September", highlight: "Back-to-school style evolution"),
            MonthlyHighlight(month: "October", highlight: "Fall layering mastery"),
            MonthlyHighlight(month: "November", highlight: "Holiday party looks"),
            MonthlyHighlight(month: "December", highlight: "Cozy winter wardrobe")
        ]
    }

    private func generateStyleEvolution() -> [StyleEvolutionPoint] {
        [
            StyleEvolutionPoint(period: "Q1", style: "Classic", confidence: 7.2),
            StyleEvolutionPoint(period: "Q2", style: "Minimalist", confidence: 8.1),
            StyleEvolutionPoint(period: "Q3", style: "Eclectic", confidence: 8.7),
            StyleEvolutionPoint(period: "Q4", style: "Sophisticated", confidence: 9.2)
        ]
    }
}

struct InsightsView: View {
    @StateObject private var analyticsManager = AnalyticsManager()
    @StateObject private var premiumManager = PremiumManager()
    @State private var selectedTimeframe: AnalyticsTimeframe = .year
    @State private var showingYearlyReview = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if premiumManager.hasFeatureAccess(.advancedAnalytics) {
                    if analyticsManager.isLoading {
                        loadingView
                    } else {
                        analyticsContent
                    }
                } else {
                    premiumPromptView
                }
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if premiumManager.hasFeatureAccess(.advancedAnalytics) {
                        Button("Yearly Review") {
                            showingYearlyReview = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingYearlyReview) {
                if let yearlyReview = analyticsManager.yearlyReview {
                    YearlyReviewView(review: yearlyReview)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(feature: .advancedAnalytics)
            }
            .task {
                if premiumManager.hasFeatureAccess(.advancedAnalytics) {
                    await analyticsManager.loadAnalytics()
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing your wardrobe...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analyticsContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Timeframe selector
                timeframeSelector

                // Overview cards
                if let data = analyticsManager.wardrobeData {
                    overviewCards(data)
                }

                // AI Insights section
                aiInsightsSection

                // Charts section
                if let data = analyticsManager.wardrobeData {
                    chartsSection(data)
                }

                // Cost analysis
                if let data = analyticsManager.wardrobeData {
                    costAnalysisSection(data)
                }

                // Recent reports
                if let data = analyticsManager.wardrobeData {
                    monthlyReportsSection(data)
                }
            }
            .padding()
        }
    }

    private var premiumPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            VStack(spacing: 16) {
                Text("Unlock Style Analytics")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Get AI-powered insights into your wardrobe with interactive charts, cost-per-wear tracking, and personalized recommendations.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Interactive Charts", description: "Visualize your style patterns")
                FeatureRow(icon: "brain.head.profile", title: "AI Insights", description: "Smart wardrobe recommendations")
                FeatureRow(icon: "dollarsign.circle", title: "Cost Per Wear", description: "Track your fashion investments")
                FeatureRow(icon: "sparkles", title: "Yearly Review", description: "Spotify-style fashion recap")
            }
            .padding(.horizontal)

            Button("Upgrade to Premium") {
                showingPaywall = true
            }
            .buttonStyle(PremiumButtonStyle())
        }
        .padding()
    }

    private var timeframeSelector: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            ForEach(AnalyticsTimeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }

    private func overviewCards(_ data: WardrobeAnalytics) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            OverviewCard(
                title: "Total Items",
                value: "\(data.totalItems)",
                icon: "tshirt.fill",
                color: .blue
            )

            OverviewCard(
                title: "Wardrobe Value",
                value: "$\(Int(data.totalValue))",
                icon: "dollarsign.circle.fill",
                color: .green
            )

            OverviewCard(
                title: "Avg Cost/Wear",
                value: "$\(String(format: "%.2f", data.averageCostPerWear))",
                icon: "chart.bar.fill",
                color: .orange
            )

            OverviewCard(
                title: "Most Worn",
                value: data.mostWornItem,
                icon: "star.fill",
                color: .purple
            )
        }
        .padding(.horizontal)
    }

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(analyticsManager.insights) { insight in
                        AIInsightCard(insight: insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func chartsSection(_ data: WardrobeAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Style Analytics")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            // Color distribution chart
            ColorDistributionChart(data: data.colorDistribution)
                .padding(.horizontal)

            // Wearing patterns heatmap
            WearingPatternsHeatmap(patterns: data.wearingPatterns)
                .padding(.horizontal)

            // Category breakdown
            CategoryBreakdownChart(data: data.categoryBreakdown)
                .padding(.horizontal)
        }
    }

    private func costAnalysisSection(_ data: WardrobeAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Analysis")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            CostPerWearChart(items: data.costPerWearData)
                .padding(.horizontal)

            InvestmentRecommendationsView(items: data.costPerWearData)
                .padding(.horizontal)
        }
    }

    private func monthlyReportsSection(_ data: WardrobeAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Reports")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ForEach(data.monthlyReports.prefix(3), id: \.month) { report in
                MonthlyReportCard(report: report)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Supporting Views
struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct AIInsightCard: View {
    let insight: AIInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.type.icon)
                    .foregroundColor(insight.type.color)

                Text(insight.type.title)
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()
            }

            Text(insight.message)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let actionTitle = insight.actionTitle {
                Button(actionTitle) {
                    // Handle insight action
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        }
        .frame(width: 280)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct ColorDistributionChart: View {
    let data: [ColorData]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Distribution")
                .font(.headline)
                .fontWeight(.medium)

            Chart(data, id: \.color) { colorData in
                SectorMark(
                    angle: .value("Percentage", colorData.percentage),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(colorForName(colorData.color))
                .opacity(0.8)
            }
            .frame(height: 200)

            // Legend
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(data, id: \.color) { colorData in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForName(colorData.color))
                            .frame(width: 12, height: 12)

                        Text("\(colorData.color) (\(colorData.percentage)%)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "black": return .black
        case "navy": return .blue
        case "white": return .gray.opacity(0.3)
        case "gray", "grey": return .gray
        case "blue": return .blue
        default: return .purple
        }
    }
}

struct WearingPatternsHeatmap: View {
    let patterns: [WearingPattern]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wearing Patterns")
                .font(.headline)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                // Weekday labels
                HStack {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }

                // Heatmap grid
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(patterns.suffix(350), id: \.date) { pattern in
                        Rectangle()
                            .fill(heatmapColor(for: pattern.intensity))
                            .frame(height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }

            // Legend
            HStack {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 2) {
                    ForEach(0..<5) { intensity in
                        Rectangle()
                            .fill(heatmapColor(for: Double(intensity) / 4.0))
                            .frame(width: 12, height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }

                Text("More")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func heatmapColor(for intensity: Double) -> Color {
        let opacity = max(0.1, intensity)
        return Color.blue.opacity(opacity)
    }
}

struct CategoryBreakdownChart: View {
    let data: [CategoryData]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Breakdown")
                .font(.headline)
                .fontWeight(.medium)

            Chart(data, id: \.category) { categoryData in
                BarMark(
                    x: .value("Count", categoryData.count),
                    y: .value("Category", categoryData.category)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct CostPerWearChart: View {
    let items: [CostPerWearItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Per Wear Analysis")
                .font(.headline)
                .fontWeight(.medium)

            Chart(items, id: \.name) { item in
                BarMark(
                    x: .value("Cost per Wear", item.costPerWear),
                    y: .value("Item", item.name)
                )
                .foregroundStyle(costPerWearColor(item.costPerWear))
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func costPerWearColor(_ cost: Double) -> Color {
        if cost <= 5 { return .green }
        if cost <= 15 { return .orange }
        return .red
    }
}

struct InvestmentRecommendationsView: View {
    let items: [CostPerWearItem]

    private var recommendations: [String] {
        var recs: [String] = []

        // Find high cost-per-wear items
        let expensiveItems = items.filter { $0.costPerWear > 20 }
        if !expensiveItems.isEmpty {
            recs.append("Consider wearing your \(expensiveItems.first?.name.lowercased() ?? "expensive items") more often")
        }

        // Find great value items
        let valueItems = items.filter { $0.costPerWear < 5 && $0.cost > 100 }
        if !valueItems.isEmpty {
            recs.append("Great investment: Your \(valueItems.first?.name ?? "quality basics") have excellent cost-per-wear")
        }

        return recs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Investment Insights")
                .font(.headline)
                .fontWeight(.medium)

            ForEach(recommendations, id: \.self) { recommendation in
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)

                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct MonthlyReportCard: View {
    let report: MonthlyReport

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(report.month)
                    .font(.headline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(report.outfitsWorn) outfits worn")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(report.newPurchases) new purchases")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("$\(Int(report.totalSpent)) spent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.1f", report.styleScore))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Text("Style Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Data Models
struct WardrobeAnalytics {
    let totalItems: Int
    let totalValue: Double
    let averageCostPerWear: Double
    let mostWornItem: String
    let leastWornItems: [String]
    let colorDistribution: [ColorData]
    let categoryBreakdown: [CategoryData]
    let wearingPatterns: [WearingPattern]
    let seasonalTrends: [SeasonalTrend]
    let costPerWearData: [CostPerWearItem]
    let monthlyReports: [MonthlyReport]
}

struct ColorData {
    let color: String
    let percentage: Double
    let count: Int
}

struct CategoryData {
    let category: String
    let count: Int
    let value: Double
}

struct WearingPattern {
    let date: Date
    let intensity: Double // 0.0 to 1.0
}

struct SeasonalTrend {
    let season: String
    let dominantColors: [String]
    let style: String
}

struct CostPerWearItem {
    let name: String
    let cost: Double
    let wears: Int
    let costPerWear: Double
}

struct MonthlyReport {
    let month: String
    let outfitsWorn: Int
    let newPurchases: Int
    let totalSpent: Double
    let topCategory: String
    let styleScore: Double
}

enum AnalyticsTimeframe: String, CaseIterable {
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
}

extension DateFormatter {
    static let monthName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
}

#Preview {
    InsightsView()
}