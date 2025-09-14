import SwiftUI

struct EmptyStateView: View {
    let type: EmptyStateType
    let title: String?
    let message: String?
    let primaryAction: EmptyStateAction?
    let secondaryAction: EmptyStateAction?

    init(
        type: EmptyStateType,
        title: String? = nil,
        message: String? = nil,
        primaryAction: EmptyStateAction? = nil,
        secondaryAction: EmptyStateAction? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: 32) {
            EmptyStateIllustration(type: type)
                .frame(width: 240, height: 180)

            VStack(spacing: 16) {
                Text(title ?? type.defaultTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text(message ?? type.defaultMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .lineLimit(3)
            }

            VStack(spacing: 12) {
                if let primary = primaryAction {
                    Button(action: primary.action) {
                        HStack(spacing: 8) {
                            if let icon = primary.icon {
                                Image(systemName: icon)
                                    .font(.body.weight(.medium))
                            }
                            Text(primary.title)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(type.primaryColor.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                if let secondary = secondaryAction {
                    Button(action: secondary.action) {
                        HStack(spacing: 8) {
                            if let icon = secondary.icon {
                                Image(systemName: icon)
                                    .font(.body.weight(.medium))
                            }
                            Text(secondary.title)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

enum EmptyStateType {
    case emptyWardrobe
    case noOutfits
    case noFavorites
    case noSearchResults
    case noNotifications
    case noActivity
    case noPhotos
    case noStyles
    case noRecommendations
    case noAnalytics
    case firstTime

    var defaultTitle: String {
        switch self {
        case .emptyWardrobe:
            return "Your Wardrobe Awaits"
        case .noOutfits:
            return "No Outfits Yet"
        case .noFavorites:
            return "No Favorites Saved"
        case .noSearchResults:
            return "No Results Found"
        case .noNotifications:
            return "All Caught Up!"
        case .noActivity:
            return "No Activity Yet"
        case .noPhotos:
            return "No Photos Added"
        case .noStyles:
            return "Discover Your Style"
        case .noRecommendations:
            return "Building Your Profile"
        case .noAnalytics:
            return "Insights Coming Soon"
        case .firstTime:
            return "Welcome to StyleSync!"
        }
    }

    var defaultMessage: String {
        switch self {
        case .emptyWardrobe:
            return "Start building your digital wardrobe by adding your favorite pieces. The more you add, the better your outfit recommendations become!"
        case .noOutfits:
            return "Create your first outfit combination and let our AI help you discover amazing new looks."
        case .noFavorites:
            return "Heart the outfits you love to save them here. Build your collection of go-to looks!"
        case .noSearchResults:
            return "Try adjusting your search terms or explore our trending styles for inspiration."
        case .noNotifications:
            return "You're all up to date! We'll notify you about new style tips and outfit suggestions."
        case .noActivity:
            return "Your style journey starts here. Rate outfits, save favorites, and track your fashion evolution!"
        case .noPhotos:
            return "Capture your outfits to get AI-powered style insights and build your visual wardrobe."
        case .noStyles:
            return "Take our style quiz to get personalized recommendations that match your unique taste."
        case .noRecommendations:
            return "Help us learn your style preferences to create personalized outfit recommendations just for you."
        case .noAnalytics:
            return "Start rating outfits and tracking your style choices to unlock detailed insights about your fashion preferences."
        case .firstTime:
            return "Your personal AI stylist is ready to help you discover amazing outfits and elevate your style game."
        }
    }

    var primaryColor: Color {
        switch self {
        case .emptyWardrobe:
            return .blue
        case .noOutfits:
            return .purple
        case .noFavorites:
            return .pink
        case .noSearchResults:
            return .orange
        case .noNotifications:
            return .green
        case .noActivity:
            return .blue
        case .noPhotos:
            return .teal
        case .noStyles:
            return .indigo
        case .noRecommendations:
            return .purple
        case .noAnalytics:
            return .mint
        case .firstTime:
            return .blue
        }
    }

    var illustration: String {
        switch self {
        case .emptyWardrobe:
            return "tshirt"
        case .noOutfits:
            return "sparkles"
        case .noFavorites:
            return "heart"
        case .noSearchResults:
            return "magnifyingglass"
        case .noNotifications:
            return "bell"
        case .noActivity:
            return "chart.line.uptrend.xyaxis"
        case .noPhotos:
            return "camera"
        case .noStyles:
            return "paintbrush"
        case .noRecommendations:
            return "wand.and.rays"
        case .noAnalytics:
            return "chart.bar"
        case .firstTime:
            return "star"
        }
    }
}

struct EmptyStateAction {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

struct EmptyStateIllustration: View {
    let type: EmptyStateType

    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            backgroundGradient

            mainIllustration

            decorativeElements
        }
        .onAppear {
            startAnimations()
        }
    }

    @ViewBuilder
    private var backgroundGradient: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        type.primaryColor.opacity(0.1),
                        type.primaryColor.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(pulseScale)
    }

    @ViewBuilder
    private var mainIllustration: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(type.primaryColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)

                Image(systemName: type.illustration)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(type.primaryColor)
                    .offset(y: floatOffset)
                    .rotationEffect(.degrees(rotation))
            }

            illustrationTitle
        }
    }

    @ViewBuilder
    private var illustrationTitle: some View {
        switch type {
        case .emptyWardrobe:
            HStack(spacing: 8) {
                Image(systemName: "tshirt")
                    .foregroundColor(type.primaryColor.opacity(0.6))
                Image(systemName: "rectangle")
                    .foregroundColor(type.primaryColor.opacity(0.4))
                Image(systemName: "shoe")
                    .foregroundColor(type.primaryColor.opacity(0.6))
            }
            .font(.title3)

        case .noOutfits:
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "star")
                        .font(.caption)
                        .foregroundColor(type.primaryColor.opacity(0.3))
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: pulseScale
                        )
                }
            }

        case .noFavorites:
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "heart")
                        .font(.title3)
                        .foregroundColor(type.primaryColor.opacity(0.3 + Double(index) * 0.2))
                        .scaleEffect(1.0 + (pulseScale - 1.0) * Double(index + 1) * 0.3)
                }
            }

        default:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(type.primaryColor.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseScale)
                }
            }
        }
    }

    @ViewBuilder
    private var decorativeElements: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(type.primaryColor.opacity(0.1))
                            .frame(width: 20, height: 4)
                            .offset(x: animationOffset * Double(index + 1) * 0.3)
                    }
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
        }

        VStack {
            HStack {
                VStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(type.primaryColor.opacity(0.1))
                            .frame(width: 8, height: 8)
                            .offset(y: floatOffset * Double(index + 1) * 0.5)
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 20)
                Spacer()
            }
            Spacer()
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            animationOffset = 10
        }

        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }

        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            floatOffset = -8
        }

        if type == .noStyles {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct WardrobeEmptyState: View {
    let onAddFirstItem: () -> Void
    let onTakePhoto: () -> Void

    var body: some View {
        EmptyStateView(
            type: .emptyWardrobe,
            primaryAction: EmptyStateAction(
                title: "Add Your First Item",
                icon: "plus.circle",
                action: onAddFirstItem
            ),
            secondaryAction: EmptyStateAction(
                title: "Take a Photo",
                icon: "camera",
                action: onTakePhoto
            )
        )
    }
}

struct SearchEmptyState: View {
    let searchQuery: String
    let onClearSearch: () -> Void
    let onExploreStyles: () -> Void

    var body: some View {
        EmptyStateView(
            type: .noSearchResults,
            title: "No results for '\(searchQuery)'",
            primaryAction: EmptyStateAction(
                title: "Clear Search",
                icon: "xmark.circle",
                action: onClearSearch
            ),
            secondaryAction: EmptyStateAction(
                title: "Explore Trending",
                icon: "flame",
                action: onExploreStyles
            )
        )
    }
}

struct OnboardingEmptyState: View {
    let onGetStarted: () -> Void
    let onTakeStyleQuiz: () -> Void

    var body: some View {
        EmptyStateView(
            type: .firstTime,
            primaryAction: EmptyStateAction(
                title: "Get Started",
                icon: "arrow.right.circle",
                action: onGetStarted
            ),
            secondaryAction: EmptyStateAction(
                title: "Take Style Quiz",
                icon: "questionmark.circle",
                action: onTakeStyleQuiz
            )
        )
    }
}

struct NotificationsEmptyState: View {
    var body: some View {
        EmptyStateView(
            type: .noNotifications,
            message: "You're all up to date! We'll notify you about new style tips, outfit suggestions, and trend updates.",
            secondaryAction: EmptyStateAction(
                title: "Notification Settings",
                icon: "gear",
                action: {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            )
        )
    }
}

struct RecommendationsEmptyState: View {
    let onAddPreferences: () -> Void
    let onRateOutfits: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            EmptyStateView(
                type: .noRecommendations,
                primaryAction: EmptyStateAction(
                    title: "Set Style Preferences",
                    icon: "slider.horizontal.3",
                    action: onAddPreferences
                ),
                secondaryAction: EmptyStateAction(
                    title: "Rate Some Outfits",
                    icon: "star",
                    action: onRateOutfits
                )
            )

            QuickActionCards(
                actions: [
                    QuickAction(
                        title: "Style Quiz",
                        icon: "questionmark.diamond",
                        color: .blue,
                        action: onAddPreferences
                    ),
                    QuickAction(
                        title: "Upload Photos",
                        icon: "photo.on.rectangle",
                        color: .green,
                        action: {}
                    ),
                    QuickAction(
                        title: "Browse Trends",
                        icon: "flame",
                        color: .orange,
                        action: {}
                    )
                ]
            )
        }
    }
}

struct QuickActionCards: View {
    let actions: [QuickAction]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(actions, id: \.title) { action in
                Button(action: action.action) {
                    VStack(spacing: 8) {
                        Image(systemName: action.icon)
                            .font(.title2)
                            .foregroundColor(action.color)

                        Text(action.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

struct QuickAction {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Getting Started")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(currentStep)/\(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            if currentStep < stepTitles.count {
                Text("Next: \(stepTitles[currentStep])")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyStateShowcase: View {
    @State private var selectedState = 0

    private let emptyStates: [EmptyStateType] = [
        .emptyWardrobe,
        .noOutfits,
        .noFavorites,
        .noSearchResults,
        .noNotifications,
        .noPhotos,
        .firstTime
    ]

    var body: some View {
        VStack(spacing: 20) {
            Picker("Empty State", selection: $selectedState) {
                ForEach(0..<emptyStates.count, id: \.self) { index in
                    Text(emptyStates[index].defaultTitle).tag(index)
                }
            }
            .pickerStyle(MenuPickerStyle())

            ScrollView {
                Group {
                    switch emptyStates[selectedState] {
                    case .emptyWardrobe:
                        WardrobeEmptyState(onAddFirstItem: {}, onTakePhoto: {})

                    case .noSearchResults:
                        SearchEmptyState(searchQuery: "summer dress", onClearSearch: {}, onExploreStyles: {})

                    case .firstTime:
                        OnboardingEmptyState(onGetStarted: {}, onTakeStyleQuiz: {})

                    case .noNotifications:
                        NotificationsEmptyState()

                    case .noRecommendations:
                        RecommendationsEmptyState(onAddPreferences: {}, onRateOutfits: {})

                    default:
                        EmptyStateView(
                            type: emptyStates[selectedState],
                            primaryAction: EmptyStateAction(title: "Get Started", action: {}),
                            secondaryAction: EmptyStateAction(title: "Learn More", action: {})
                        )
                    }
                }
            }
        }
        .padding()
    }
}