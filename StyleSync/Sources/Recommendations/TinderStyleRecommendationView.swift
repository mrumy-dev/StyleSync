import SwiftUI
import Combine

struct TinderStyleRecommendationView: View {
    @StateObject private var viewModel = TinderRecommendationViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var currentMode: RecommendationMode = .smart
    @State private var showModeSelector = false
    @State private var showFilters = false
    @State private var show3DPreview = false
    @State private var currentExplanation: DetailedExplanation?
    @State private var showExplanation = false

    enum RecommendationMode: String, CaseIterable {
        case smart = "Smart"
        case inspiration = "Inspiration"
        case similar = "Similar"
        case random = "Random"
        case trending = "Trending"
        case mixAndMatch = "Mix & Match"
        case manual = "Manual"
        case voice = "Voice"

        var icon: String {
            switch self {
            case .smart: return "brain.head.profile"
            case .inspiration: return "lightbulb.fill"
            case .similar: return "rectangle.stack.badge.magnifyingglass"
            case .random: return "shuffle"
            case .trending: return "chart.line.uptrend.xyaxis"
            case .mixAndMatch: return "rectangle.2.swap"
            case .manual: return "hand.tap.fill"
            case .voice: return "mic.fill"
            }
        }

        var description: String {
            switch self {
            case .smart: return "AI-powered personalized recommendations"
            case .inspiration: return "Discover new styles and trends"
            case .similar: return "Find items similar to your favorites"
            case .random: return "Surprise me with random picks"
            case .trending: return "What's popular right now"
            case .mixAndMatch: return "Create complete outfits"
            case .manual: return "Browse with manual controls"
            case .voice: return "Voice-controlled browsing"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerSection

                    mainContentArea(geometry: geometry)

                    bottomControls
                }
            }
        }
        .onAppear {
            viewModel.loadRecommendations(mode: currentMode)
        }
        .sheet(isPresented: $showModeSelector) {
            ModeSelectionView(
                selectedMode: $currentMode,
                onModeChanged: { mode in
                    currentMode = mode
                    viewModel.loadRecommendations(mode: mode)
                }
            )
        }
        .sheet(isPresented: $showFilters) {
            RecommendationFiltersView(filters: $viewModel.filters)
        }
        .sheet(isPresented: $show3DPreview) {
            if let currentProduct = viewModel.currentProduct {
                Product3DPreviewView(product: currentProduct)
            }
        }
        .sheet(isPresented: $showExplanation) {
            if let explanation = currentExplanation {
                ExplanationView(explanation: explanation)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                themeManager.currentTheme.colors.background,
                themeManager.currentTheme.colors.background.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        HStack {
            Button(action: { showModeSelector = true }) {
                HStack(spacing: 8) {
                    Image(systemName: currentMode.icon)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentMode.rawValue)
                            .typography(.body2, theme: .modern)
                            .fontWeight(.semibold)

                        Text(currentMode.description)
                            .typography(.caption2, theme: .minimal)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .backdrop(BlurView(style: .systemThinMaterial))
                )
            }
            .tapWithHaptic(.medium)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { showFilters = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .backdrop(BlurView(style: .systemThinMaterial))
                        )
                }
                .tapWithHaptic(.light)

                Button(action: { show3DPreview = true }) {
                    Image(systemName: "cube.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .backdrop(BlurView(style: .systemThinMaterial))
                        )
                }
                .tapWithHaptic(.light)
                .disabled(viewModel.currentProduct == nil)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func mainContentArea(geometry: GeometryProxy) -> some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.recommendations.isEmpty {
                emptyStateView
            } else {
                swipeableCardsView(geometry: geometry)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ShimmerView()
                .frame(width: 280, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text("Finding perfect matches...")
                .typography(.body1, theme: .modern)
                .foregroundColor(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No recommendations found")
                    .typography(.title3, theme: .modern)
                    .fontWeight(.semibold)

                Text("Try adjusting your filters or switching modes")
                    .typography(.body2, theme: .minimal)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh Recommendations") {
                viewModel.loadRecommendations(mode: currentMode)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(40)
    }

    private func swipeableCardsView(geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(Array(viewModel.recommendations.enumerated().reversed()), id: \.element.id) { index, recommendation in
                SwipeableProductCard(
                    recommendation: recommendation,
                    geometry: geometry,
                    isTopCard: index == viewModel.recommendations.count - 1,
                    onSwipe: { direction in
                        handleSwipe(direction: direction, for: recommendation)
                    },
                    onTap: {
                        viewModel.currentProduct = recommendation.product
                    },
                    onExplainTap: {
                        currentExplanation = recommendation.explanation
                        showExplanation = true
                    }
                )
                .zIndex(Double(index))
                .offset(
                    x: CGFloat(index) * 4,
                    y: CGFloat(index) * -8
                )
                .scaleEffect(1.0 - CGFloat(index) * 0.02)
                .opacity(index < 3 ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var bottomControls: some View {
        HStack(spacing: 20) {
            swipeButton(
                icon: "xmark",
                color: .red,
                action: { handleSwipe(direction: .left, for: viewModel.currentRecommendation) }
            )

            swipeButton(
                icon: "info.circle",
                color: .blue,
                action: {
                    if let current = viewModel.currentRecommendation {
                        currentExplanation = current.explanation
                        showExplanation = true
                    }
                }
            )

            swipeButton(
                icon: "star",
                color: .yellow,
                action: { handleSwipe(direction: .up, for: viewModel.currentRecommendation) }
            )

            swipeButton(
                icon: "heart",
                color: .pink,
                action: { handleSwipe(direction: .right, for: viewModel.currentRecommendation) }
            )
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 34)
    }

    private func swipeButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .tapWithHaptic(.medium)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: true)
    }

    private func handleSwipe(direction: SwipeDirection, for recommendation: RecommendationResult?) {
        guard let recommendation = recommendation else { return }

        viewModel.handleSwipe(direction: direction, for: recommendation)

        // Haptic feedback based on direction
        switch direction {
        case .left:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .right:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .up:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .down:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

struct SwipeableProductCard: View {
    let recommendation: RecommendationResult
    let geometry: GeometryProxy
    let isTopCard: Bool
    let onSwipe: (SwipeDirection) -> Void
    let onTap: () -> Void
    let onExplainTap: () -> Void

    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    @State private var isDragging = false
    @State private var showConfidenceScore = false

    private let swipeThreshold: CGFloat = 120
    private let rotationFactor: Double = 0.1

    var body: some View {
        VStack(spacing: 0) {
            productImageSection
            productInfoSection
        }
        .frame(width: 300, height: 450)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0)
        )
        .offset(offset)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: offset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isTopCard else { return }

                    offset = value.translation
                    rotation = Double(value.translation.x) * rotationFactor

                    if !isDragging {
                        isDragging = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { value in
                    guard isTopCard else { return }

                    isDragging = false

                    let direction = getSwipeDirection(from: value.translation)

                    if let direction = direction {
                        // Animate card off screen
                        animateOffScreen(direction: direction)

                        // Delay the onSwipe call to allow animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipe(direction)
                        }
                    } else {
                        // Return to center
                        offset = .zero
                        rotation = 0
                    }
                }
        )
        .onTapGesture {
            onTap()
        }
        .overlay(
            swipeIndicators,
            alignment: .center
        )
        .overlay(
            confidenceIndicator,
            alignment: .topTrailing
        )
    }

    private var productImageSection: some View {
        ZStack(alignment: .topLeading) {
            AsyncImage(url: URL(string: recommendation.product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 300)
            .clipShape(
                RoundedRectangle(cornerRadius: 20)
            )

            VStack {
                HStack {
                    confidenceBadge
                    Spacer()
                    explainButton
                }
                .padding(16)

                Spacer()

                if recommendation.product.onSale {
                    HStack {
                        salesBadge
                        Spacer()
                    }
                    .padding(16)
                }
            }
        }
    }

    private var confidenceBadge: some View {
        VStack(spacing: 4) {
            Text("\(Int(recommendation.score.confidence * 100))%")
                .typography(.caption1, theme: .modern)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("match")
                .typography(.caption2, theme: .minimal)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .backdrop(BlurView(style: .systemThinMaterial))
        )
    }

    private var explainButton: some View {
        Button(action: onExplainTap) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .backdrop(BlurView(style: .systemThinMaterial))
                )
        }
        .tapWithHaptic(.light)
    }

    private var salesBadge: some View {
        Text("\(recommendation.product.salePercentage ?? 0)% OFF")
            .typography(.caption1, theme: .modern)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
            )
    }

    private var productInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.product.brand)
                    .typography(.caption1, theme: .minimal)
                    .foregroundColor(.secondary)

                Text(recommendation.product.name)
                    .typography(.body1, theme: .modern)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                priceSection
                Spacer()
                categoryBadge
            }

            if !recommendation.reasoning.whyRecommended.isEmpty {
                Text(recommendation.reasoning.whyRecommended.first ?? "")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priceSection: some View {
        HStack(spacing: 6) {
            Text("$\(recommendation.product.currentPrice, specifier: "%.2f")")
                .typography(.title3, theme: .modern)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if let originalPrice = recommendation.product.originalPrice,
               originalPrice > recommendation.product.currentPrice {
                Text("$\(originalPrice, specifier: "%.2f")")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.secondary)
                    .strikethrough()
            }
        }
    }

    private var categoryBadge: some View {
        Text(recommendation.category.rawValue.capitalized)
            .typography(.caption2, theme: .minimal)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(recommendation.category.color)
            )
    }

    private var swipeIndicators: some View {
        Group {
            if abs(offset.x) > 50 || abs(offset.y) > 50 {
                VStack {
                    if offset.y < -50 {
                        swipeIndicator(text: "SAVE", color: .yellow, icon: "star.fill")
                    } else if offset.x > 50 {
                        swipeIndicator(text: "LIKE", color: .green, icon: "heart.fill")
                    } else if offset.x < -50 {
                        swipeIndicator(text: "PASS", color: .red, icon: "xmark")
                    } else if offset.y > 50 {
                        swipeIndicator(text: "INFO", color: .blue, icon: "info.circle.fill")
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
    }

    private func swipeIndicator(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)

            Text(text)
                .typography(.title3, theme: .modern)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color)
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(min(1.2, 1.0 + abs(offset.x + offset.y) / 200))
    }

    private var confidenceIndicator: some View {
        Button(action: { showConfidenceScore.toggle() }) {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.6))
                )
                .overlay(
                    Text("\(Int(recommendation.score.confidence * 100))")
                        .typography(.caption2, theme: .modern)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .frame(width: 32, height: 32)
        }
        .padding(16)
        .opacity(showConfidenceScore ? 1.0 : 0.7)
    }

    private func getSwipeDirection(from translation: CGSize) -> SwipeDirection? {
        if abs(translation.x) > swipeThreshold {
            return translation.x > 0 ? .right : .left
        } else if abs(translation.y) > swipeThreshold {
            return translation.y > 0 ? .down : .up
        }
        return nil
    }

    private func animateOffScreen(direction: SwipeDirection) {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height

        switch direction {
        case .left:
            offset = CGSize(width: -screenWidth, height: offset.y)
            rotation = -30
        case .right:
            offset = CGSize(width: screenWidth, height: offset.y)
            rotation = 30
        case .up:
            offset = CGSize(width: offset.x, height: -screenHeight)
        case .down:
            offset = CGSize(width: offset.x, height: screenHeight)
        }
    }
}

enum SwipeDirection {
    case left, right, up, down
}

extension RecommendationResult.Category {
    var color: Color {
        switch self {
        case .trending: return .orange
        case .personalized: return .blue
        case .similar: return .green
        case .contextual: return .purple
        case .discovery: return .pink
        }
    }
}

// Supporting Views
struct ModeSelectionView: View {
    @Binding var selectedMode: TinderStyleRecommendationView.RecommendationMode
    let onModeChanged: (TinderStyleRecommendationView.RecommendationMode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(TinderStyleRecommendationView.RecommendationMode.allCases, id: \.self) { mode in
                        ModeCard(
                            mode: mode,
                            isSelected: selectedMode == mode
                        ) {
                            selectedMode = mode
                            onModeChanged(mode)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Recommendation Mode")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ModeCard: View {
    let mode: TinderStyleRecommendationView.RecommendationMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.largeTitle)
                    .foregroundColor(isSelected ? .white : .primary)

                VStack(spacing: 4) {
                    Text(mode.rawValue)
                        .typography(.body1, theme: .modern)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(mode.description)
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .tapWithHaptic(.medium)
    }
}

struct ShimmerView: View {
    @State private var animating = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.3),
                                .init(color: .black, location: 0.7),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: animating ? 300 : -300)
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    animating = true
                }
            }
    }
}

#Preview {
    TinderStyleRecommendationView()
        .environmentObject(ThemeManager())
}