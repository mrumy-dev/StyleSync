import SwiftUI

// MARK: - Main Discovery View
struct DiscoveryView: View {
    @StateObject private var discoveryManager = DiscoveryManager.shared
    @Environment(\.theme) private var theme
    @State private var selectedDiscoveryType: DiscoveryType = .forYou
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                DiscoverySearchBar(searchText: $searchText)
                    .padding(.horizontal)

                // Discovery Type Selector
                DiscoveryTypeSelectorView(selectedType: $selectedDiscoveryType)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Main Discovery Content
                DiscoveryContentView(
                    discoveryType: selectedDiscoveryType,
                    searchText: searchText,
                    discoveryManager: discoveryManager
                )
            }
            .background(
                GradientMeshBackground(colors: theme.gradients.mesh)
                    .ignoresSafeArea()
            )
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: StyleDNAAnalysisView()) {
                        Image(systemName: "dna")
                            .font(.title2)
                            .foregroundColor(theme.colors.primary)
                    }
                }
            }
        }
        .onAppear {
            discoveryManager.loadDiscoveryContent(for: selectedDiscoveryType)
        }
        .onChange(of: selectedDiscoveryType) { newType in
            discoveryManager.loadDiscoveryContent(for: newType)
        }
        .onChange(of: searchText) { query in
            if !query.isEmpty {
                discoveryManager.performSearch(query: query)
            }
        }
    }
}

// MARK: - Discovery Types
enum DiscoveryType: String, CaseIterable {
    case forYou = "for_you"
    case trending = "trending"
    case similar = "similar"
    case styleMatch = "style_match"
    case nearby = "nearby"
    case events = "events"
    case brands = "brands"
    case influencers = "influencers"

    var displayName: String {
        switch self {
        case .forYou: return "For You"
        case .trending: return "Trending"
        case .similar: return "Similar Users"
        case .styleMatch: return "Style Match"
        case .nearby: return "Nearby"
        case .events: return "Events"
        case .brands: return "Brands"
        case .influencers: return "Influencers"
        }
    }

    var icon: String {
        switch self {
        case .forYou: return "person.crop.circle.badge.checkmark"
        case .trending: return "flame"
        case .similar: return "person.2"
        case .styleMatch: return "wand.and.stars"
        case .nearby: return "location"
        case .events: return "calendar"
        case .brands: return "building.2"
        case .influencers: return "crown"
        }
    }
}

// MARK: - Discovery Search Bar
struct DiscoverySearchBar: View {
    @Binding var searchText: String
    @Environment(\.theme) private var theme
    @State private var isSearching = false

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.colors.onSurfaceVariant)

            TextField("Search styles, users, trends...", text: $searchText)
                .typography(.body2, theme: .system)
                .foregroundColor(theme.colors.onSurface)
                .onTapGesture {
                    isSearching = true
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.colors.onSurfaceVariant)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surfaceVariant)
        )
    }
}

// MARK: - Discovery Type Selector
struct DiscoveryTypeSelectorView: View {
    @Binding var selectedType: DiscoveryType
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DiscoveryType.allCases, id: \.self) { type in
                    DiscoveryTypeButton(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.snappySpring) {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Discovery Type Button
struct DiscoveryTypeButton: View {
    let type: DiscoveryType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))

                Text(type.displayName)
                    .typography(.body2, theme: .system)
            }
            .foregroundColor(isSelected ? .white : theme.colors.onSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? theme.colors.primary : theme.colors.surfaceVariant)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .animation(.snappySpring, value: isSelected)
    }
}

// MARK: - Discovery Content View
struct DiscoveryContentView: View {
    let discoveryType: DiscoveryType
    let searchText: String
    let discoveryManager: DiscoveryManager
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if !searchText.isEmpty {
                    SearchResultsView(
                        searchText: searchText,
                        discoveryManager: discoveryManager
                    )
                } else {
                    switch discoveryType {
                    case .forYou:
                        ForYouContentView(discoveryManager: discoveryManager)
                    case .trending:
                        TrendingContentView(discoveryManager: discoveryManager)
                    case .similar:
                        SimilarUsersView(discoveryManager: discoveryManager)
                    case .styleMatch:
                        StyleMatchView(discoveryManager: discoveryManager)
                    case .nearby:
                        NearbyContentView(discoveryManager: discoveryManager)
                    case .events:
                        EventsView(discoveryManager: discoveryManager)
                    case .brands:
                        BrandsView(discoveryManager: discoveryManager)
                    case .influencers:
                        InfluencersView(discoveryManager: discoveryManager)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - For You Content View
struct ForYouContentView: View {
    let discoveryManager: DiscoveryManager
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 24) {
            // Personalized Recommendations Section
            DiscoverySectionView(
                title: "Recommended for You",
                subtitle: "Based on your style DNA",
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(discoveryManager.personalizedRecommendations.prefix(8), id: \.id) { recommendation in
                                PersonalizedRecommendationCard(recommendation: recommendation)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            )

            // Style DNA Matches
            DiscoverySectionView(
                title: "Style DNA Matches",
                subtitle: "Users with similar style preferences",
                content: {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(discoveryManager.styleDNAMatches.prefix(4), id: \.id) { user in
                            SimilarUserCard(user: user)
                        }
                    }
                }
            )

            // Trending in Your Style
            DiscoverySectionView(
                title: "Trending in Your Style",
                subtitle: "Popular among users with similar taste",
                content: {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(discoveryManager.personalizedTrending.prefix(6), id: \.id) { content in
                            TrendingContentCard(content: content)
                        }
                    }
                }
            )

            // New for You
            DiscoverySectionView(
                title: "New for You",
                subtitle: "Fresh content based on your interests",
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(discoveryManager.newContent.prefix(10), id: \.id) { post in
                                NewContentCard(post: post)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            )
        }
    }
}

// MARK: - Trending Content View
struct TrendingContentView: View {
    let discoveryManager: DiscoveryManager
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 24) {
            // Global Trending
            DiscoverySectionView(
                title: "Trending Now",
                subtitle: "What everyone is talking about",
                content: {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(discoveryManager.globalTrending.prefix(6), id: \.id) { content in
                            GlobalTrendingCard(content: content)
                        }
                    }
                }
            )

            // Trending Hashtags
            DiscoverySectionView(
                title: "Trending Hashtags",
                subtitle: "Popular tags right now",
                content: {
                    FlowLayout(spacing: 8) {
                        ForEach(discoveryManager.trendingHashtags.prefix(15), id: \.self) { hashtag in
                            TrendingHashtagChip(hashtag: hashtag)
                        }
                    }
                }
            )

            // Viral Challenges
            DiscoverySectionView(
                title: "Viral Challenges",
                subtitle: "Join the latest style challenges",
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(discoveryManager.viralChallenges.prefix(5), id: \.id) { challenge in
                                ViralChallengeCard(challenge: challenge)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            )
        }
    }
}

// MARK: - Similar Users View
struct SimilarUsersView: View {
    let discoveryManager: DiscoveryManager

    var body: some View {
        VStack(spacing: 24) {
            // Style Twin Section
            DiscoverySectionView(
                title: "Your Style Twins",
                subtitle: "Users with 90%+ style similarity",
                content: {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(discoveryManager.styleTwins.prefix(6), id: \.id) { user in
                            StyleTwinCard(user: user)
                        }
                    }
                }
            )

            // Color Palette Matches
            DiscoverySectionView(
                title: "Color Palette Matches",
                subtitle: "Users who love your colors",
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(discoveryManager.colorMatches.prefix(8), id: \.id) { user in
                                ColorMatchCard(user: user)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            )

            // Similar Body Type & Style
            DiscoverySectionView(
                title: "Similar Body Type & Style",
                subtitle: "Find inspiration from similar users",
                content: {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(discoveryManager.bodyTypeMatches.prefix(4), id: \.id) { user in
                            BodyTypeMatchCard(user: user)
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Style Match View
struct StyleMatchView: View {
    let discoveryManager: DiscoveryManager
    @State private var selectedStylePersonality: StylePersonality?

    var body: some View {
        VStack(spacing: 24) {
            // Style Personality Filter
            VStack(alignment: .leading, spacing: 12) {
                Text("Find Your Style Tribe")
                    .typography(.heading3, theme: .modern)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StylePersonality.allCases, id: \.self) { personality in
                            StylePersonalityChip(
                                personality: personality,
                                isSelected: selectedStylePersonality == personality
                            ) {
                                selectedStylePersonality = selectedStylePersonality == personality ? nil : personality
                                discoveryManager.filterByStylePersonality(personality)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Matching Results
            if let personality = selectedStylePersonality {
                DiscoverySectionView(
                    title: "\(personality.rawValue.capitalized) Style Community",
                    subtitle: "Connect with your style tribe",
                    content: {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach(discoveryManager.stylePersonalityMatches, id: \.id) { user in
                                StylePersonalityMatchCard(user: user)
                            }
                        }
                    }
                )
            } else {
                // Show all style matches
                DiscoverySectionView(
                    title: "Discover Your Style Matches",
                    subtitle: "Find users who share your aesthetic",
                    content: {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach(discoveryManager.allStyleMatches.prefix(8), id: \.id) { user in
                                GeneralStyleMatchCard(user: user)
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Nearby Content View
struct NearbyContentView: View {
    let discoveryManager: DiscoveryManager

    var body: some View {
        VStack(spacing: 24) {
            // Local Fashion Events
            DiscoverySectionView(
                title: "Fashion Events Near You",
                subtitle: "Discover local style events",
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(discoveryManager.localEvents.prefix(5), id: \.id) { event in
                                LocalEventCard(event: event)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            )

            // Local Stylists
            DiscoverySectionView(
                title: "Local Stylists",
                subtitle: "Professional stylists in your area",
                content: {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(discoveryManager.localStylists.prefix(4), id: \.id) { stylist in
                            LocalStylistCard(stylist: stylist)
                        }
                    }
                }
            )

            // Nearby Stores
            DiscoverySectionView(
                title: "Fashion Stores Nearby",
                subtitle: "Shop local fashion",
                content: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(discoveryManager.nearbyStores.prefix(8), id: \.id) { store in
                                NearbyStoreCard(store: store)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            )
        }
    }
}

// MARK: - Discovery Section View
struct DiscoverySectionView<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    @Environment(\.theme) private var theme

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Text(subtitle)
                    .typography(.body2, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }

            content
        }
    }
}

// MARK: - Card Views
struct PersonalizedRecommendationCard: View {
    let recommendation: PersonalizedRecommendation
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            // Content preview
            Rectangle()
                .fill(theme.colors.surfaceVariant)
                .aspectRatio(3/4, contentMode: .fit)
                .overlay(
                    VStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundColor(theme.colors.primary)

                        Text("\(Int(recommendation.matchScore * 100))% match")
                            .typography(.caption1, theme: .system)
                            .foregroundColor(theme.colors.primary)
                    }
                )
                .cornerRadius(12)

            Text(recommendation.reason)
                .typography(.caption1, theme: .system)
                .foregroundColor(theme.colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 120)
    }
}

struct SimilarUserCard: View {
    let user: SimilarUser
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            // Profile picture placeholder
            Circle()
                .fill(theme.colors.surfaceVariant)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                )

            VStack(spacing: 4) {
                Text("@username") // Would use user.userID
                    .typography(.body2, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)

                Text("\(Int(user.similarityScore * 100))% similarity")
                    .typography(.caption1, theme: .system)
                    .foregroundColor(theme.colors.primary)

                // Shared interests
                FlowLayout(spacing: 4) {
                    ForEach(user.sharedInterests.prefix(3), id: \.self) { interest in
                        Text(interest)
                            .typography(.caption2, theme: .system)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.colors.surfaceVariant)
                            )
                    }
                }
            }

            Button("Follow") {
                // Handle follow
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.colors.primary)
            )
            .typography(.caption1, theme: .system)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.colors.surface)
                .glassmorphism(intensity: .light)
        )
    }
}

// MARK: - Additional Card Views (Simplified)
struct TrendingContentCard: View {
    let content: TrendingContent

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(8)
            .overlay(
                VStack {
                    Image(systemName: "flame")
                        .foregroundColor(.orange)
                    Text("Trending")
                        .font(.caption)
                }
            )
    }
}

struct NewContentCard: View {
    let post: SocialPost

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 100, height: 120)
            .cornerRadius(8)
    }
}

// Additional simplified cards...
struct GlobalTrendingCard: View {
    let content: TrendingContent
    var body: some View { Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(1, contentMode: .fit).cornerRadius(8) }
}

struct TrendingHashtagChip: View {
    let hashtag: String
    var body: some View {
        Text("#\(hashtag)")
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1))
    }
}

struct ViralChallengeCard: View {
    let challenge: ChallengePost
    var body: some View { Rectangle().fill(Color.purple.opacity(0.3)).frame(width: 150, height: 100).cornerRadius(8) }
}

struct StyleTwinCard: View {
    let user: SimilarUser
    var body: some View { Rectangle().fill(Color.pink.opacity(0.3)).aspectRatio(1, contentMode: .fit).cornerRadius(8) }
}

struct ColorMatchCard: View {
    let user: SimilarUser
    var body: some View { Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 80, height: 100).cornerRadius(8) }
}

struct BodyTypeMatchCard: View {
    let user: SimilarUser
    var body: some View { Rectangle().fill(Color.green.opacity(0.3)).aspectRatio(1, contentMode: .fit).cornerRadius(8) }
}

struct StylePersonalityChip: View {
    let personality: StylePersonality
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(personality.rawValue.capitalized, action: onTap)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
            )
            .foregroundColor(isSelected ? .white : .primary)
    }
}

// More simplified cards...
struct StylePersonalityMatchCard: View {
    let user: SimilarUser
    var body: some View { Rectangle().fill(Color.orange.opacity(0.3)).aspectRatio(1, contentMode: .fit).cornerRadius(8) }
}

struct GeneralStyleMatchCard: View {
    let user: SimilarUser
    var body: some View { Rectangle().fill(Color.teal.opacity(0.3)).aspectRatio(1, contentMode: .fit).cornerRadius(8) }
}

struct LocalEventCard: View {
    let event: FashionEvent
    var body: some View { Rectangle().fill(Color.red.opacity(0.3)).frame(width: 200, height: 120).cornerRadius(8) }
}

struct LocalStylistCard: View {
    let stylist: SimilarUser
    var body: some View { Rectangle().fill(Color.indigo.opacity(0.3)).aspectRatio(1, contentMode: .fit).cornerRadius(8) }
}

struct NearbyStoreCard: View {
    let store: FashionStore
    var body: some View { Rectangle().fill(Color.brown.opacity(0.3)).frame(width: 100, height: 80).cornerRadius(8) }
}

struct SearchResultsView: View {
    let searchText: String
    let discoveryManager: DiscoveryManager

    var body: some View {
        Text("Search results for: \(searchText)")
            .padding()
    }
}

// Placeholder views for other discovery types
struct EventsView: View {
    let discoveryManager: DiscoveryManager
    var body: some View { Text("Events View").padding() }
}

struct BrandsView: View {
    let discoveryManager: DiscoveryManager
    var body: some View { Text("Brands View").padding() }
}

struct InfluencersView: View {
    let discoveryManager: DiscoveryManager
    var body: some View { Text("Influencers View").padding() }
}

// MARK: - Style DNA Analysis View
struct StyleDNAAnalysisView: View {
    var body: some View {
        Text("Style DNA Analysis")
            .navigationTitle("Style DNA")
    }
}

// MARK: - Placeholder Types
struct PersonalizedRecommendation: Identifiable {
    let id = UUID()
    let contentID: UUID
    let matchScore: Float
    let reason: String
}

struct FashionEvent: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let date: Date
}

struct FashionStore: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let rating: Float
}