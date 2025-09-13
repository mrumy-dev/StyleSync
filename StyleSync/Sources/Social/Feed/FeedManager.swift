import Foundation
import SwiftUI
import Combine

// MARK: - Feed Manager
@MainActor
final class FeedManager: ObservableObject {
    static let shared = FeedManager()

    // MARK: - Published Properties
    @Published var currentPosts: [SocialPost] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var feedError: FeedError?
    @Published var hasMorePosts = true

    // MARK: - Private Properties
    private let privacyManager = PrivacyControlsManager.shared
    private let cryptoEngine = CryptoEngine.shared
    private let storageManager = SandboxedStorageManager.shared
    private var currentFeedType: FeedType = .following
    private var currentPage = 0
    private let postsPerPage = 20
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants
    private enum Constants {
        static let feedCachePrefix = "feed_cache"
        static let feedRefreshInterval: TimeInterval = 300 // 5 minutes
        static let maxCacheSize = 1000
    }

    private init() {
        setupFeedMonitoring()
        loadCachedFeed()
    }

    // MARK: - Public Methods
    func loadFeed(type: FeedType) {
        currentFeedType = type
        currentPage = 0
        hasMorePosts = true
        currentPosts.removeAll()

        Task {
            await loadFeedData()
        }
    }

    func refreshFeed(type: FeedType) async {
        currentFeedType = type
        currentPage = 0
        hasMorePosts = true

        await loadFeedData(refresh: true)
    }

    func loadMorePosts() async {
        guard hasMorePosts && !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1

        await loadFeedData(append: true)

        isLoadingMore = false
    }

    // MARK: - Private Methods
    private func loadFeedData(refresh: Bool = false, append: Bool = false) async {
        if !append {
            isLoading = true
        }
        feedError = nil

        do {
            let posts = try await fetchPosts(
                type: currentFeedType,
                page: currentPage,
                limit: postsPerPage,
                refresh: refresh
            )

            if append {
                currentPosts.append(contentsOf: posts)
            } else {
                currentPosts = posts
            }

            hasMorePosts = posts.count == postsPerPage

            // Cache the feed
            if !append {
                await cacheFeed(posts, type: currentFeedType)
            }

            isLoading = false

        } catch {
            feedError = FeedError.loadingFailed(error)
            isLoading = false

            // Try to load cached data if network fails
            if !append && !refresh {
                await loadCachedFeed(type: currentFeedType)
            }
        }
    }

    private func fetchPosts(
        type: FeedType,
        page: Int,
        limit: Int,
        refresh: Bool = false
    ) async throws -> [SocialPost] {

        // Check privacy permissions
        guard await hasPermissionForFeedType(type) else {
            throw FeedError.permissionDenied
        }

        // Simulate network delay for development
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Generate mock posts based on feed type
        return generateMockPosts(for: type, page: page, limit: limit)
    }

    private func generateMockPosts(for type: FeedType, page: Int, limit: Int) -> [SocialPost] {
        var posts: [SocialPost] = []

        for i in 0..<limit {
            let postIndex = page * limit + i

            let post = SocialPost(
                authorID: "user_\(postIndex % 10)",
                content: generateMockContent(index: postIndex),
                caption: generateMockCaption(for: type, index: postIndex),
                hashtags: generateMockHashtags(for: type),
                mentions: [],
                location: generateMockLocation(for: type),
                visibility: .public,
                likeCount: Int.random(in: 10...1000),
                commentCount: Int.random(in: 5...100),
                shareCount: Int.random(in: 0...50),
                saveCount: Int.random(in: 5...200),
                viewCount: Int.random(in: 100...5000),
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...86400 * 7)) // Last 7 days
            )

            posts.append(post)
        }

        return posts
    }

    private func generateMockContent(index: Int) -> PostContent {
        let contentTypes: [PostContent] = [
            .photo(PhotoPost(
                imageData: [generateMockImageData()],
                filters: [],
                layout: nil,
                aspectRatio: 1.0,
                editingData: nil
            )),
            .outfit(OutfitPost(
                items: generateMockOutfitItems(),
                style: StyleCategory.allCases.randomElement() ?? .casual,
                occasion: "Daily wear",
                season: Season.allCases.randomElement() ?? .spring,
                bodyType: BodyType.allCases.randomElement(),
                priceRange: PriceRange.allCases.randomElement(),
                shoppableLinks: generateMockShoppableLinks(),
                confidence: Float.random(in: 0.6...1.0)
            )),
            .beforeAfter(TransformationPost(
                beforeImages: [generateMockImageData()],
                afterImages: [generateMockImageData()],
                transformationType: TransformationType.allCases.randomElement() ?? .styleEvolution,
                timespan: "3 months",
                tips: ["Stay consistent", "Find your style"],
                productsUsed: []
            ))
        ]

        return contentTypes[index % contentTypes.count]
    }

    private func generateMockCaption(for type: FeedType, index: Int) -> String {
        let captions = [
            "Loving this new style! 💫",
            "Perfect outfit for today's weather ☀️",
            "Finally found my signature look ✨",
            "Experimenting with bold colors 🎨",
            "Confidence is the best accessory 💪",
            "Style evolution in progress 🦋",
            "Mixing patterns like a pro 🎭",
            "Comfort meets style 🌟",
            "Vintage vibes all day 📸",
            "Ready to conquer the day! 🚀"
        ]

        return captions[index % captions.count]
    }

    private func generateMockHashtags(for type: FeedType) -> [String] {
        let hashtagsMap: [FeedType: [String]] = [
            .following: ["ootd", "style", "fashion", "outfit", "trend"],
            .discover: ["explore", "fashion", "style", "discover", "newlook"],
            .trending: ["viral", "trending", "hot", "popular", "musthave"],
            .local: ["local", "community", "nearby", "city", "neighborhood"]
        ]

        let availableHashtags = hashtagsMap[type] ?? ["style", "fashion"]
        return Array(availableHashtags.shuffled().prefix(3))
    }

    private func generateMockLocation(for type: FeedType) -> PostLocation? {
        guard type == .local else { return nil }

        let locations = [
            PostLocation(name: "Downtown", coordinates: nil, city: "New York", country: "USA"),
            PostLocation(name: "Fashion District", coordinates: nil, city: "Los Angeles", country: "USA"),
            PostLocation(name: "SoHo", coordinates: nil, city: "London", country: "UK"),
            PostLocation(name: "Le Marais", coordinates: nil, city: "Paris", country: "France")
        ]

        return locations.randomElement()
    }

    private func generateMockImageData() -> Data {
        // Generate a simple colored rectangle as mock image data
        let image = UIImage(systemName: "photo") ?? UIImage()
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    private func generateMockOutfitItems() -> [OutfitItem] {
        let items = [
            OutfitItem(
                name: "Vintage Denim Jacket",
                category: "Outerwear",
                color: CodableColor(color: .blue),
                brand: "StyleSync",
                price: 89.99,
                imageURL: nil
            ),
            OutfitItem(
                name: "White Cotton Tee",
                category: "Tops",
                color: CodableColor(color: .white),
                brand: "Basic Co.",
                price: 24.99,
                imageURL: nil
            ),
            OutfitItem(
                name: "Black Skinny Jeans",
                category: "Bottoms",
                color: CodableColor(color: .black),
                brand: "Denim Works",
                price: 79.99,
                imageURL: nil
            )
        ]

        return Array(items.shuffled().prefix(Int.random(in: 2...4)))
    }

    private func generateMockShoppableLinks() -> [ShoppableLink] {
        return [
            ShoppableLink(
                productName: "Trendy Jacket",
                brand: "Fashion Brand",
                price: 129.99,
                currency: "USD",
                url: URL(string: "https://example.com/jacket")!,
                imageData: nil,
                category: "Outerwear"
            )
        ]
    }

    // MARK: - Caching
    private func cacheFeed(_ posts: [SocialPost], type: FeedType) async {
        do {
            let feedData = FeedCacheData(
                posts: posts,
                type: type,
                timestamp: Date(),
                page: currentPage
            )

            let encodedData = try JSONEncoder().encode(feedData)
            let encryptedData = try cryptoEngine.encrypt(data: encodedData)

            try await storageManager.storeSecurely(
                data: try JSONEncoder().encode(encryptedData),
                at: "\(Constants.feedCachePrefix)_\(type.rawValue)"
            )
        } catch {
            print("Failed to cache feed: \(error)")
        }
    }

    private func loadCachedFeed(type: FeedType? = nil) async {
        let feedType = type ?? currentFeedType

        do {
            let encryptedData = try await storageManager.loadSecurely(
                from: "\(Constants.feedCachePrefix)_\(feedType.rawValue)"
            )
            let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
            let feedData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
            let cacheData = try JSONDecoder().decode(FeedCacheData.self, from: feedData)

            // Check if cache is still fresh
            let cacheAge = Date().timeIntervalSince(cacheData.timestamp)
            guard cacheAge < Constants.feedRefreshInterval else {
                return
            }

            currentPosts = cacheData.posts

        } catch {
            // Cache doesn't exist or is corrupted
            print("Failed to load cached feed: \(error)")
        }
    }

    private func loadCachedFeed() {
        Task {
            await loadCachedFeed()
        }
    }

    // MARK: - Permission Checking
    private func hasPermissionForFeedType(_ type: FeedType) async -> Bool {
        switch type {
        case .following:
            return true // Basic functionality
        case .discover:
            return await privacyManager.permissionsGranted.contains(.analytics)
        case .trending:
            return await privacyManager.permissionsGranted.contains(.analytics)
        case .local:
            return await privacyManager.permissionsGranted.contains(.location)
        }
    }

    // MARK: - Feed Monitoring
    private func setupFeedMonitoring() {
        // Monitor for privacy changes that might affect feed access
        privacyManager.$permissionsGranted
            .sink { [weak self] permissions in
                Task {
                    await self?.handlePermissionChange()
                }
            }
            .store(in: &cancellables)

        // Auto-refresh timer
        Timer.publish(every: Constants.feedRefreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.autoRefreshIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func handlePermissionChange() async {
        // Reload current feed if permissions changed
        await loadFeedData(refresh: true)
    }

    private func autoRefreshIfNeeded() async {
        // Only auto-refresh if user is actively viewing feed
        guard !currentPosts.isEmpty else { return }

        // Check if last refresh was more than refresh interval ago
        // Implementation would track last refresh time
        await loadFeedData(refresh: true)
    }
}

// MARK: - Story Manager
@MainActor
final class StoryManager: ObservableObject {
    static let shared = StoryManager()

    // MARK: - Published Properties
    @Published var stories: [StoryPost] = []
    @Published var isLoading = false
    @Published var storyError: StoryError?

    // MARK: - Private Properties
    private let privacyManager = PrivacyControlsManager.shared
    private let cryptoEngine = CryptoEngine.shared
    private let storageManager = SandboxedStorageManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants
    private enum Constants {
        static let storyCacheKey = "stories_cache"
        static let storyExpirationHours = 24
    }

    private init() {
        setupStoryMonitoring()
        loadCachedStories()
    }

    // MARK: - Public Methods
    func loadStories() {
        Task {
            await fetchStories()
        }
    }

    func refreshStories() async {
        await fetchStories(refresh: true)
    }

    func viewStory(_ storyId: UUID) async {
        // Mark story as viewed
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            // Implementation would track story views
            print("Viewing story: \(storyId)")
        }
    }

    func createStory(content: StoryContent, duration: TimeInterval) async throws -> StoryPost {
        let story = StoryPost(
            content: content,
            duration: duration,
            backgroundColor: CodableColor(color: .black),
            stickers: [],
            music: nil,
            expiresAt: Date().addingTimeInterval(TimeInterval(Constants.storyExpirationHours * 3600))
        )

        stories.insert(story, at: 0)
        await cacheStories()

        return story
    }

    func deleteStory(_ storyId: UUID) async {
        stories.removeAll { $0.id == storyId }
        await cacheStories()
    }

    // MARK: - Private Methods
    private func fetchStories(refresh: Bool = false) async {
        isLoading = true
        storyError = nil

        do {
            // Check privacy permissions
            guard await privacyManager.permissionsGranted.contains(.socialFeatures) else {
                throw StoryError.permissionDenied
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let fetchedStories = generateMockStories()
            stories = fetchedStories

            await cacheStories()

            isLoading = false

        } catch {
            storyError = StoryError.loadingFailed(error)
            isLoading = false

            // Try to load cached data if network fails
            if !refresh {
                await loadCachedStories()
            }
        }
    }

    private func generateMockStories() -> [StoryPost] {
        var mockStories: [StoryPost] = []

        for i in 0..<8 {
            let story = StoryPost(
                content: generateMockStoryContent(index: i),
                duration: Double.random(in: 5...15),
                backgroundColor: CodableColor(color: Color.random),
                stickers: generateMockStickers(),
                music: generateMockMusic(),
                expiresAt: Date().addingTimeInterval(TimeInterval.random(in: 3600...86400))
            )

            mockStories.append(story)
        }

        return mockStories
    }

    private func generateMockStoryContent(index: Int) -> StoryContent {
        let contentTypes: [StoryContent] = [
            .photo(generateMockImageData()),
            .text(StoryText(
                text: "Today's outfit inspiration! ✨",
                font: "Helvetica",
                size: 24,
                color: CodableColor(color: .white),
                backgroundColor: CodableColor(color: .clear),
                alignment: .center,
                animation: .bounce
            )),
            .outfit(OutfitStory(
                items: generateMockOutfitItems(),
                transitionEffect: .dissolve,
                music: generateMockMusic(),
                shoppableLinks: []
            ))
        ]

        return contentTypes[index % contentTypes.count]
    }

    private func generateMockStickers() -> [StorySticker] {
        let mockStickers = [
            StorySticker(
                type: .emoji,
                position: CGPoint(x: 100, y: 100),
                rotation: 0,
                scale: 1.0,
                data: .text("✨")
            ),
            StorySticker(
                type: .location,
                position: CGPoint(x: 50, y: 200),
                rotation: 0,
                scale: 1.0,
                data: .text("New York")
            )
        ]

        return Array(mockStickers.shuffled().prefix(Int.random(in: 0...2)))
    }

    private func generateMockMusic() -> MusicTrack? {
        let tracks = [
            MusicTrack(
                id: "track_1",
                title: "Stylish Vibes",
                artist: "Fashion Beats",
                duration: 180,
                startTime: 30,
                endTime: 60,
                genre: "Pop"
            ),
            MusicTrack(
                id: "track_2",
                title: "Runway Dreams",
                artist: "Style Sounds",
                duration: 200,
                startTime: 45,
                endTime: 75,
                genre: "Electronic"
            )
        ]

        return tracks.randomElement()
    }

    private func generateMockImageData() -> Data {
        let image = UIImage(systemName: "photo") ?? UIImage()
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    private func generateMockOutfitItems() -> [OutfitItem] {
        return [
            OutfitItem(
                name: "Stylish Top",
                category: "Tops",
                color: CodableColor(color: .blue),
                brand: "Fashion Co.",
                price: 59.99,
                imageURL: nil
            )
        ]
    }

    // MARK: - Caching
    private func cacheStories() async {
        do {
            let storiesData = StoryCacheData(
                stories: stories,
                timestamp: Date()
            )

            let encodedData = try JSONEncoder().encode(storiesData)
            let encryptedData = try cryptoEngine.encrypt(data: encodedData)

            try await storageManager.storeSecurely(
                data: try JSONEncoder().encode(encryptedData),
                at: Constants.storyCacheKey
            )
        } catch {
            print("Failed to cache stories: \(error)")
        }
    }

    private func loadCachedStories() async {
        do {
            let encryptedData = try await storageManager.loadSecurely(from: Constants.storyCacheKey)
            let decryptedEncryptedData = try JSONDecoder().decode(EncryptedData.self, from: encryptedData)
            let storiesData = try cryptoEngine.decrypt(encryptedData: decryptedEncryptedData)
            let cacheData = try JSONDecoder().decode(StoryCacheData.self, from: storiesData)

            // Filter out expired stories
            let validStories = cacheData.stories.filter { $0.expiresAt > Date() }
            stories = validStories

        } catch {
            print("Failed to load cached stories: \(error)")
        }
    }

    private func loadCachedStories() {
        Task {
            await loadCachedStories()
        }
    }

    // MARK: - Story Monitoring
    private func setupStoryMonitoring() {
        // Auto-cleanup expired stories
        Timer.publish(every: 3600, on: .main, in: .common) // Check every hour
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.cleanupExpiredStories()
                }
            }
            .store(in: &cancellables)
    }

    private func cleanupExpiredStories() async {
        let now = Date()
        let activeStories = stories.filter { $0.expiresAt > now }

        if activeStories.count != stories.count {
            stories = activeStories
            await cacheStories()
        }
    }
}

// MARK: - Supporting Types
struct FeedCacheData: Codable {
    let posts: [SocialPost]
    let type: FeedType
    let timestamp: Date
    let page: Int
}

struct StoryCacheData: Codable {
    let stories: [StoryPost]
    let timestamp: Date
}

// MARK: - Error Types
enum FeedError: LocalizedError {
    case loadingFailed(Error)
    case permissionDenied
    case networkError
    case invalidData

    var errorDescription: String? {
        switch self {
        case .loadingFailed(let error):
            return "Failed to load feed: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied for this feed type"
        case .networkError:
            return "Network error occurred"
        case .invalidData:
            return "Invalid feed data received"
        }
    }
}

enum StoryError: LocalizedError {
    case loadingFailed(Error)
    case permissionDenied
    case creationFailed
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .loadingFailed(let error):
            return "Failed to load stories: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied for stories"
        case .creationFailed:
            return "Failed to create story"
        case .invalidContent:
            return "Invalid story content"
        }
    }
}

// MARK: - Extensions
extension Color {
    static var random: Color {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow]
        return colors.randomElement() ?? .black
    }
}