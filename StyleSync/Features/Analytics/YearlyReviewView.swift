import SwiftUI
import Charts

struct YearlyReviewView: View {
    let review: YearlyReview
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showingShareSheet = false
    @State private var animateStats = false

    private let gradientColors = [
        Color.purple, Color.pink, Color.blue, Color.cyan,
        Color.mint, Color.green, Color.yellow, Color.orange
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground(colors: gradientColors)
                    .ignoresSafeArea()

                TabView(selection: $currentPage) {
                    // Welcome slide
                    welcomeSlide
                        .tag(0)

                    // Total outfits slide
                    totalOutfitsSlide
                        .tag(1)

                    // Top color slide
                    topColorSlide
                        .tag(2)

                    // Style personality slide
                    stylePersonalitySlide
                        .tag(3)

                    // Monthly highlights
                    monthlyHighlightsSlide
                        .tag(4)

                    // Style evolution slide
                    styleEvolutionSlide
                        .tag(5)

                    // Achievements slide
                    achievementsSlide
                        .tag(6)

                    // Sustainability slide
                    sustainabilitySlide
                        .tag(7)

                    // Share slide
                    shareSlide
                        .tag(8)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Navigation controls
                VStack {
                    HStack {
                        Button("Skip") {
                            dismiss()
                        }
                        .foregroundColor(.white.opacity(0.8))

                        Spacer()

                        Button("Share") {
                            showingShareSheet = true
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    Spacer()

                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<9, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5)) {
                animateStats = true
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareYearlyReviewView(review: review)
        }
    }

    private var welcomeSlide: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 20) {
                Text("\(review.year)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(animateStats ? 1.0 : 0.8)
                    .opacity(animateStats ? 1.0 : 0.0)

                Text("Your Style Year")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(animateStats ? 1.0 : 0.0)

                Text("A year of fashion discoveries,\nperfect outfits, and style evolution")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .opacity(animateStats ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animateStats)

            Spacer()

            Text("Swipe to explore your journey")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .opacity(animateStats ? 1.0 : 0.0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.0), value: animateStats)
        }
        .padding()
    }

    private var totalOutfitsSlide: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Text("\(review.totalOutfits)")
                    .font(.system(size: 90, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(currentPage == 1 ? 1.0 : 0.8)
                    .opacity(currentPage == 1 ? 1.0 : 0.0)

                Text("Outfits Created")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("That's almost one new look every day!")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: currentPage)

            // Outfit visualization
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.3))
                                .frame(width: 40, height: 12)
                        }
                    }
                    .opacity(currentPage == 1 ? 1.0 : 0.0)
                    .scaleEffect(currentPage == 1 ? 1.0 : 0.8)
                }
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: currentPage)

            Spacer()
        }
        .padding()
    }

    private var topColorSlide: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Text("Your Color")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Color circle
                Circle()
                    .fill(colorForName(review.favoriteColor))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 4)
                    )
                    .scaleEffect(currentPage == 2 ? 1.0 : 0.5)
                    .opacity(currentPage == 2 ? 1.0 : 0.0)

                Text(review.favoriteColor)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("appeared in 68% of your\nhighest-rated outfits")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: currentPage)

            Spacer()
        }
        .padding()
    }

    private var stylePersonalitySlide: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Text("You Are A")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))

                Text(review.stylePersonality)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(currentPage == 3 ? 1.0 : 0.8)
                    .opacity(currentPage == 3 ? 1.0 : 0.0)

                VStack(spacing: 12) {
                    Text("Your style is defined by:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    VStack(alignment: .leading, spacing: 8) {
                        StyleTraitRow(icon: "checkmark.circle.fill", text: "Timeless pieces over trends")
                        StyleTraitRow(icon: "checkmark.circle.fill", text: "Quality over quantity")
                        StyleTraitRow(icon: "checkmark.circle.fill", text: "Neutral color palette")
                        StyleTraitRow(icon: "checkmark.circle.fill", text: "Effortless elegance")
                    }
                }
                .opacity(currentPage == 3 ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: currentPage)

            Spacer()
        }
        .padding()
    }

    private var monthlyHighlightsSlide: some View {
        VStack(spacing: 30) {
            Text("Monthly Highlights")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 20)

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(review.monthlyHighlights.enumerated()), id: \.offset) { index, highlight in
                        MonthlyHighlightCard(
                            highlight: highlight,
                            delay: Double(index) * 0.1,
                            isVisible: currentPage == 4
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 60)
        }
    }

    private var styleEvolutionSlide: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text("Style Evolution")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Your confidence grew throughout the year")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 20)

            // Evolution chart
            Chart(review.styleEvolution, id: \.period) { point in
                LineMark(
                    x: .value("Period", point.period),
                    y: .value("Confidence", point.confidence)
                )
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                PointMark(
                    x: .value("Period", point.period),
                    y: .value("Confidence", point.confidence)
                )
                .foregroundStyle(.white)
                .symbolSize(60)
            }
            .frame(height: 200)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .opacity(currentPage == 5 ? 1.0 : 0.0)
            .scaleEffect(currentPage == 5 ? 1.0 : 0.8)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: currentPage)

            VStack(spacing: 12) {
                ForEach(review.styleEvolution, id: \.period) { point in
                    HStack {
                        Text(point.period)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Spacer()

                        Text(point.style)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
            .opacity(currentPage == 5 ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: currentPage)

            Spacer()
        }
        .padding()
    }

    private var achievementsSlide: some View {
        VStack(spacing: 30) {
            Text("Achievements Unlocked")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 20)

            VStack(spacing: 20) {
                ForEach(Array(review.topAchievements.enumerated()), id: \.offset) { index, achievement in
                    AchievementRow(
                        achievement: achievement,
                        delay: Double(index) * 0.2,
                        isVisible: currentPage == 6
                    )
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var sustainabilitySlide: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(currentPage == 7 ? 1.0 : 0.5)
                    .opacity(currentPage == 7 ? 1.0 : 0.0)

                Text("Sustainability Score")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("\(String(format: "%.1f", review.sustainabilityScore))/10")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .scaleEffect(currentPage == 7 ? 1.0 : 0.8)
                    .opacity(currentPage == 7 ? 1.0 : 0.0)

                Text("You made the most of your wardrobe\nwith smart, sustainable choices")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: currentPage)

            Spacer()
        }
        .padding()
    }

    private var shareSlide: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("That's a wrap!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Share your style journey with friends")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button("Share My Year") {
                    showingShareSheet = true
                }
                .font(.headline)
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 25))

                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "navy blue", "navy": return .blue
        case "black": return .black
        case "white": return .white.opacity(0.8)
        case "red": return .red
        case "pink": return .pink
        case "green": return .green
        case "yellow": return .yellow
        default: return .purple
        }
    }
}

struct StyleTraitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
    }
}

struct MonthlyHighlightCard: View {
    let highlight: MonthlyHighlight
    let delay: Double
    let isVisible: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.month)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(highlight.highlight)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .offset(x: isVisible ? 0 : 100)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: isVisible)
    }
}

struct AchievementRow: View {
    let achievement: String
    let delay: Double
    let isVisible: Bool

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundColor(.yellow)

            Text(achievement)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: isVisible)
    }
}

struct AnimatedGradientBackground: View {
    let colors: [Color]
    @State private var startPoint = UnitPoint.topLeading
    @State private var endPoint = UnitPoint.bottomTrailing

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                startPoint = UnitPoint.topTrailing
                endPoint = UnitPoint.bottomLeading
            }
        }
    }
}

struct ShareYearlyReviewView: View {
    let review: YearlyReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Share Your Style Year")
                    .font(.title)
                    .fontWeight(.bold)

                // Preview card
                VStack(spacing: 16) {
                    Text("\(review.year) Style Wrapped")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(review.totalOutfits) Outfits")
                                .font(.headline)
                            Text(review.favoriteColor)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(review.stylePersonality)
                                .font(.headline)
                            Text("\(String(format: "%.1f", review.sustainabilityScore))/10 Eco Score")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Share options
                VStack(spacing: 16) {
                    Button("Share to Instagram Stories") {
                        shareToInstagram()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Share Summary") {
                        shareText()
                    }
                    .buttonStyle(.bordered)

                    Button("Save Image") {
                        saveImage()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareToInstagram() {
        // Implementation for Instagram sharing
    }

    private func shareText() {
        // Implementation for text sharing
    }

    private func saveImage() {
        // Implementation for saving image
    }
}

// MARK: - Supporting Models
struct YearlyReview {
    let year: Int
    let totalOutfits: Int
    let favoriteColor: String
    let stylePersonality: String
    let topAchievements: [String]
    let monthlyHighlights: [MonthlyHighlight]
    let styleEvolution: [StyleEvolutionPoint]
    let sustainabilityScore: Double
}

struct MonthlyHighlight {
    let month: String
    let highlight: String
}

#Preview {
    YearlyReviewView(review: YearlyReview(
        year: 2024,
        totalOutfits: 342,
        favoriteColor: "Navy Blue",
        stylePersonality: "Classic Minimalist",
        topAchievements: [
            "Reached 50 cost-per-wear on designer jacket",
            "Discovered new style with earth tones",
            "Built perfect capsule wardrobe"
        ],
        monthlyHighlights: [
            MonthlyHighlight(month: "January", highlight: "Mastered monochromatic styling"),
            MonthlyHighlight(month: "February", highlight: "Found perfect date night look"),
            MonthlyHighlight(month: "March", highlight: "Spring wardrobe refresh complete")
        ],
        styleEvolution: [
            StyleEvolutionPoint(period: "Q1", style: "Classic", confidence: 7.2),
            StyleEvolutionPoint(period: "Q2", style: "Minimalist", confidence: 8.1),
            StyleEvolutionPoint(period: "Q3", style: "Eclectic", confidence: 8.7),
            StyleEvolutionPoint(period: "Q4", style: "Sophisticated", confidence: 9.2)
        ],
        sustainabilityScore: 8.4
    ))
}